//
//  SwiftProgressSubscriberView.swift
//  HelloTolo
//
//  Created by Sungwoo on 5/18/15.
//  Copyright (c) 2015 Sungwoo Choo. All rights reserved.
//

import UIKit
import ToloKit

@objc class SwiftProgressSubscriberView: UIView {
    var label: UILabel
    var progressView: UIProgressView
    
    override init(frame: CGRect) {
        label = UILabel(frame: CGRectMake(0, 0, 40, frame.size.height))
        label.textAlignment = .Center
        label.backgroundColor = UIColor.clearColor()
        label.textColor = UIColor.blackColor()
        progressView = UIProgressView(frame: CGRectMake(45, (frame.size.height-5)/2, frame.size.width-45, 5))
        progressView.progress = 0
        super.init(frame: frame)
        addSubview(label)
        addSubview(progressView)
        Tolo.register(self)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // on* listens tolo event
    func onEventProgressUpdated(event: EventProgressUpdated) {
        progressView.progress = Float(event.progress)
        label.text = String(format: "%0.2f", event.progress)
    }
}