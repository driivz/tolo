//
//  Tolo.h
//  Tolo
//
//  Created by Sungwoo on 5/18/15.
//  Copyright (c) 2015 Ephraim Tekle. All rights reserved.
//

/**
 * Tolo is an event publish/subscribe framework designed to decouple different parts
 * of your iOS application while still allowing them to communicate efficiently.
 *
 * Usage:
 *
 * First import Tolo.h (or <Tolo/Tolo.h> depending on how the library is added).
 *
 * Publishing:
 *    PUBLISH(instance_of_event_class);
 *
 *    Note: an instance of any class may publish.
 *
 * Subscribing:
 *    SUBSCRIBE(event_class)
 *    {
 *          // do somethign with the event
 *    }
 *
 *    Note: an instance of any class may become a subscriber; however, in order
 *    to receive events, the instance needs to register using the macro REGISTER().
 *    Unregistring a subscriber or/and publisher is optional, as subscribers/publishers
 *    will be auto unregister on any next publish, subscriber, unsubscribe action.
 *
 * Producing (optional -- the initial value for an event when new subscribers are
 * register):
 *    PUBLISHER(event_class)
 *    {
 *          return instance-of-event-class;
 *    }
 *
 *    Note: there could only be one publisher per event type. The last publisher to
 *    register will become the publisher of that event.
 *
 */

#ifndef Tolo_Tolo_h
#define Tolo_Tolo_h

#define SUBSCRIBE(_event_type_) - (void) on##_event_type_:(_event_type_ *) event

#define PUBLISHER(_event_type_) - (_event_type_ *) get##_event_type_

#define REGISTER() [Tolo.sharedInstance subscribe:self]

#define UNREGISTER() [Tolo.sharedInstance unsubscribe:self]

#define PUBLISH(_value_) [Tolo.sharedInstance publish:_value_]

#import "ToloCore.h"

@interface Tolo : ToloCore

@end

#endif
