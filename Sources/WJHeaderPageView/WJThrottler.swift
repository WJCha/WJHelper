//
//  WJFunctionThrottle.swift
//  FudaiShenghuo
//
//  Created by Jie on 2025/4/27.
//  Copyright © 2025 FengQing. All rights reserved.
//

import Foundation


/// 一段时间内只允许调用一次
public class WJThrottler {
    private var lastFireTime: Date?
    private let interval: TimeInterval
    private let queue: DispatchQueue
 
    init(interval: TimeInterval, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }
 
    func throttle(_ action: @Sendable @escaping () -> Void) {
        let now = Date()
        if let lastFireTime = lastFireTime, now.timeIntervalSince(lastFireTime) < interval {
            return
        }
        lastFireTime = now
        queue.async {
            action()
        }
    }
}
 
