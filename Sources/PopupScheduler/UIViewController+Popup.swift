//
//  UIViewController+Ex.swift
//  TestPopup
//
//  Created by Jie on 2025/6/8.
//

import UIKit


// MARK: - UIViewController 扩展（确保方法交换只执行一次）
extension UIViewController {
    
    
    // 静态属性的初始化只有一次，可保证方法交换的代码只执行一次
    private static let popup_swizzleLifecycle: Void = {
        // 交换 viewDidAppear 方法
        let originalAppear = class_getInstanceMethod(
            UIViewController.self,
            #selector(viewDidAppear(_:)))
        
        let swizzledAppear = class_getInstanceMethod(
            UIViewController.self,
            #selector(popup_swizzled_viewDidAppear(_:)))
        
        if let original = originalAppear, let swizzled = swizzledAppear {
            method_exchangeImplementations(original, swizzled)
        }
        
        // 交换 viewWillDisappear 方法
        let originalDisappear = class_getInstanceMethod(
            UIViewController.self,
            #selector(viewWillDisappear(_:)))
        
        let swizzledDisappear = class_getInstanceMethod(
            UIViewController.self,
            #selector(popup_swizzled_viewWillDisappear(_:)))
        
        if let original = originalDisappear, let swizzled = swizzledDisappear {
            method_exchangeImplementations(original, swizzled)
        }
    }()
    
    @objc fileprivate func popup_swizzled_viewDidAppear(_ animated: Bool) {
        // 先调用原始实现
        popup_swizzled_viewDidAppear(animated)
        guard PopupScheduler.shared.autoManageConfig.enabled, PopupScheduler.shared.autoManageConfig.resumeOnAppear else { return }
        PopupScheduler.shared.resume()
    }
    
    @objc fileprivate func popup_swizzled_viewWillDisappear(_ animated: Bool) {
        // 先调用原始实现
        popup_swizzled_viewWillDisappear(animated)
        guard PopupScheduler.shared.autoManageConfig.enabled, PopupScheduler.shared.autoManageConfig.suspendOnWillDisappear else { return }
        PopupScheduler.shared.suspend()
    }
    
    static func enablePopupAutoManagement() {
        // 通过访问静态属性触发交换
        _ = popup_swizzleLifecycle
    }
}
