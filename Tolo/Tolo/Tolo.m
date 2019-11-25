//
//  Tolo.m
//  Tolo
//
//  Created by Ephraim Tekle on 8/23/13.
//  Copyright (c) 2013 Ephraim Tekle. All rights reserved.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2013 Ephraim Tekle
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "Tolo.h"
#import <objc/runtime.h>

@interface TLSubscriber : NSObject

@property (nonatomic, assign) SEL selector;
@property (nonatomic, weak  ) id target;

+ (TLSubscriber *)subscriberWithObject:(id)subscriber selector:(SEL)selector;

@end

@implementation TLSubscriber

+ (TLSubscriber *)subscriberWithObject:(id)target selector:(SEL)selector {
    TLSubscriber *sub = [TLSubscriber new];
    sub.selector = selector;
    sub.target = target;
    
    return sub;
}

@end

@interface NSObject (PubSub)

- (NSDictionary *)tolo_selectorsWithPrefix:(NSString *)prefix
                                 withParam:(BOOL)hasParam
                   includesParentSelectors:(BOOL)includes;

@end

@implementation NSObject (PubSub)

- (NSDictionary *)tolo_selectorsWithPrefix:(NSString *)prefix
                                 withParam:(BOOL)hasParam
                   includesParentSelectors:(BOOL)includes {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    const NSUInteger kNumberOfParams = hasParam ? 1 : 0;
    const NSUInteger kINDEX_FIRST_PARAM = 2;
    
    u_int count = 0;
    
    Class objectClass = [self class];
    
    do {
        Method *methods = class_copyMethodList(objectClass, &count);
        for (NSUInteger i = 0; i < count ; ++i) {
            
            Method method = methods[i];
            
            const char *encoding = method_getTypeEncoding(method);
            NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:encoding];
            NSUInteger parameterCount = [signature numberOfArguments];
            
            if (parameterCount - kINDEX_FIRST_PARAM != kNumberOfParams) {
                continue;
            }
            
            SEL selector = method_getName(method);
            const char *methodName = sel_getName(selector);
            NSString *methodNameString = [NSString stringWithCString:methodName encoding:NSUTF8StringEncoding];
            
            if (![methodNameString hasPrefix:prefix]) {
                continue;
            }
            
            NSRange range = {prefix.length, methodNameString.length - prefix.length - (hasParam?1:0)};
            
            NSString *paramTypeNameString = [methodNameString substringWithRange:range];
            
            [result setObject:methodNameString forKey:paramTypeNameString];
            
        }
        free(methods);
        
        objectClass = [objectClass superclass];
    } while (includes &&
             [objectClass isSubclassOfClass:[NSObject class]] &&
             objectClass != [NSObject class]);
    
    return result;
}

@end

@interface Tolo ()

@property (atomic, strong) NSMutableDictionary <NSString *, NSMutableArray <TLSubscriber *>*> *observers;
@property (atomic, strong) NSMutableDictionary <NSString *, TLSubscriber *> *publishers;

@end

@implementation Tolo

+ (Tolo *)sharedInstance {
    static dispatch_once_t pred;
    static Tolo *shared = nil;
    dispatch_once(&pred, ^{
        shared = [[Tolo alloc] init];
    });
    
    return shared;
}


- (instancetype)init {
    self = [super init];
    
    self.forceMainThread = YES;
    self.publisherPrefix = @"get";
    self.observerPrefix = @"on";
    
    // establish any data sources first
    self.publishers = [NSMutableDictionary dictionary];
    
    // register subscriptions
    self.observers = [NSMutableDictionary dictionary];
    
    return self;
}

- (void)subscribe:(NSObject *)object {
    [self subscribe:object withParentsSubscriptions:NO];
}

- (void)subscribe:(NSObject *)object withParentsSubscriptions:(BOOL)parentsSubscriptions {
    // Unsubscribe the `object` to prevent multiple-subscriptions
    [self unsubscribe:object];
    
    NSDictionary *publishingObjects = [object tolo_selectorsWithPrefix:self.publisherPrefix
                                                             withParam:NO
                                               includesParentSelectors:parentsSubscriptions];
    
    if (publishingObjects.count) {
        for (NSString *type in publishingObjects) {
            SEL selector = NSSelectorFromString([publishingObjects objectForKey:type]);
            
            [self.publishers setObject:[TLSubscriber subscriberWithObject:object selector:selector]
                                forKey:type];
            // publish to existing subscribers
            [self publish:[object performSelector:selector]];
        }
    }
    
    NSDictionary *observedObjects = [object tolo_selectorsWithPrefix:self.observerPrefix
                                                           withParam:YES
                                             includesParentSelectors:parentsSubscriptions];
    
    if (observedObjects.count) {
        for (NSString *type in observedObjects) {
            NSMutableArray *observersForType = [self.observers objectForKey:type];
            if (!observersForType) {
                observersForType = [NSMutableArray array];
                [self.observers setObject:observersForType forKey:type];
            }
            
            SEL selector = NSSelectorFromString([observedObjects objectForKey:type]);
            [observersForType addObject:[TLSubscriber subscriberWithObject:object selector:selector]];
            
            // publish this type to the subscriber on subscribe
            TLSubscriber *publisher = [self.publishers objectForKey:type];
            if (publisher) {
                [object performSelector:selector withObject:[publisher.target performSelector:publisher.selector]];
            }
        }
    }
}

- (void)unsubscribe:(NSObject *)object {
    for (NSString *key in self.observers.allKeys) {
        NSMutableArray <TLSubscriber *> *subscribers = [self.observers objectForKey:key];
        [subscribers enumerateObjectsUsingBlock:^(TLSubscriber *subscriber, NSUInteger idx, BOOL *stop) {
            if (!subscriber.target || [subscriber.target isEqual:object]) {
                [subscribers removeObject:subscriber];
            }
        }];
        
        if (!subscribers.count) {
            [self.observers removeObjectForKey:key];
        }
    }
    
    for (NSString *key in self.publishers.allKeys) {
        TLSubscriber *subscriber = [self.publishers objectForKey:key];
        if (!subscriber.target || [subscriber.target isEqual:object]) {
            [self.publishers removeObjectForKey:key];
        }
    }
}

- (void)publish:(id<NSObject>)type {
    if (self.forceMainThread && ![[NSThread currentThread] isEqual:[NSThread mainThread]]) {
        [self performSelectorOnMainThread:@selector(publish:) withObject:type waitUntilDone:YES];
    }
    else {
        NSString *thisType = NSStringFromClass([type class]);
        NSMutableArray *observers = [self.observers objectForKey:thisType];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"target == nil"];
        NSArray *emptyTargets = [observers filteredArrayUsingPredicate:predicate];
        [observers removeObjectsInArray:emptyTargets];
        
        for (TLSubscriber *subscriber in [NSArray arrayWithArray:observers]) {
            [subscriber.target performSelector:subscriber.selector withObject:type];
        }
    }
}

@end
