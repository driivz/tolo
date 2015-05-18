//
//  ToloSwift.swift
//  Tolo
//
//  Created by Sungwoo on 5/18/15.
//  Copyright (c) 2015 Sungwoo Choo. All rights reserved.
//

import Foundation

public class Tolo: ToloCore {
    public static func register(target: NSObject) {
        ToloCore.sharedInstance().subscribe(target)
    }
    
    public static func unregister(target: NSObject) {
        ToloCore.sharedInstance().unsubscribe(target)
    }
    
    public static func publish(event: NSObject) {
        ToloCore.sharedInstance().publish(event)
    }
}