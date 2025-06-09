
//
//  PopupViewScheduler.swift
//  TestPopup
//
//  Created by Jie on 2025/6/6.
//
/**
 使用示例：
 
 // 创建多个普通弹窗
 let popup1 = ClickablePopupView()
 popup1.backgroundColor = .systemPink
 popup1.priority = .middle
 
 // 设置第一个弹窗的点击事件
 popup1.onCloseCurrentPopupAndJump = { [weak self] in
     let vc = HomeViewController()
     vc.modalPresentationStyle = .fullScreen
     self?.present(vc, animated: true)
     
 }
 
 let popup2 = ClickablePopupView()
 popup2.backgroundColor = .orange
 popup2.priority = .high

 PopupScheduler.shared.clearQueue()
 
 // 调度普通弹窗
 PopupScheduler.shared.schedule(popups: [
     (popup1, PopupScheduler.Configuration.init(backgroundColor: .cyan), { true }, { print("第1显示完成") }),
     (popup2, .default, { PopupScheduler.isOnViewController(HomeViewController.self) }, { print("第2显示完成") })
 ])
 */

import UIKit

@MainActor private var actionKey: UInt8 = 0
// 条件类型
public typealias PopupDisplayCondition = () -> Bool
// 批量添加弹窗别名
public typealias PopupsType = (Popupable, PopupScheduler.Configuration, PopupDisplayCondition?, (() -> Void)?)

public enum PopupPriority: Int, Comparable {
    case low
    case middle
    case high
    case emergency // 紧急优先级，会立即取代当前正在显示的低优先级弹窗
    
    public static func < (lhs: PopupPriority, rhs: PopupPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// 自定义弹窗协议
public protocol Popupable: UIView {
    /// 弹窗唯一标识（可选, 默认 nil，都会添加到队列）
    var id: String? { get set }
    
    /// 弹窗优先级（可选）
    var priority: PopupPriority { get set }
    
    /// 显示动画（可选）
    func show(completion: @escaping () -> Void)
    
    /// 隐藏动画（可选）
    func hide(completion: @escaping () -> Void)
    
    /// 点击背景是否关闭（可选 默认 true）
    var dismissOnBackgroundTap: Bool { get }
    
    /// 点击弹窗内容回调
    /// - 如果没有开启自动管理队列，内部会关闭当前弹窗并挂起队列，
    ///   您需要注意在适合的时机手动恢复队列，如在跳入下一个页面显示完毕后手动恢复队列
    /// - 如果开启了自动管理队列，内部单纯执行闭包，不会挂起队列，如果闭包是跳转到下一个页面，
    ///   会在当前页面即将消失自动挂起队列，跳入的页面显示完毕会自动恢复队列
    var onCloseCurrentPopupAndJump: (() -> Void)? { get set }
    
    /// 更新弹窗内容
    func update(with newPopup: Popupable)
}

public extension Popupable {
    
    var id: String? {
        get { nil }
        set { }
    }
    
    var priority: PopupPriority {
        get { .low }
        set { }
    }
    
    var dismissOnBackgroundTap: Bool { true }
    
    
    // 可以给 newPopup 新弹窗一个数据属性，然后在该方法访问 newPopup.data.. 获得数据更新到当前旧弹窗上
    // 这里默认实现将新弹窗视图 addSubview 到旧弹窗视图上
    func update(with newPopup: Popupable) {
        self.subviews.forEach { $0.removeFromSuperview() }
        self.addSubview(newPopup)
    }
    
    func show(completion: @escaping () -> Void) {
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 0,
                       options: .curveEaseInOut) {
            self.alpha = 1
            self.transform = .identity
        } completion: { _ in
            completion()
        }
    }
    
    func hide(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.2,
                       animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: { _ in
            completion()
        })
    }
}

// 弹窗调度器
@MainActor
public class PopupScheduler {
    // 单例
    static let shared = PopupScheduler()
    private init() {}
    
    // 队列挂起恢复自动管理配置
    private(set) var autoManageConfig = AutoManageConfiguration()
    
    private var queue = [PopupItem]()
    private var currentPopup: PopupItem?
    private let backgroundView = UIView()
    private var isSuspended = false
    private var isAnimating = false
    
    /// 检查队列是否被挂起
    var isQueueSuspended: Bool {
        return isSuspended
    }
    
    // 弹窗模型
    public struct PopupItem {
        let popupView: Popupable
        let configuration: Configuration
        let condition: PopupDisplayCondition?
        let completion: (() -> Void)?
        
        @MainActor var priority: PopupPriority {
            return popupView.priority
        }
    }
    
    // 弹窗配置
    public struct Configuration {
        var backgroundColor: UIColor = UIColor.black.withAlphaComponent(0.5)
        var showBackground: Bool = true
        var dismissOnBackgroundTap: Bool = true
        var position: Position = .center
        
        enum Position {
            case center
            case top(offset: CGFloat)
            case bottom(offset: CGFloat)
            case custom(frame: CGRect)
        }
        
        @MainActor public static let `default` = Configuration()
    }
    
    /// 自动管理队列的配置
    struct AutoManageConfiguration {
        /// 是否启用自动管理（默认关闭）
        var enabled: Bool = false
        /// 是否在视图控制器消失时挂起队列（默认 true）
        var suspendOnWillDisappear: Bool = true
        /// 是否在视图控制器出现时恢复队列（默认 true）
        var resumeOnAppear: Bool = true
    }
    
}

// MARK: - 公开方法
public extension PopupScheduler {
    
    /// 开启/关闭自动管理队列（适合页面跳转的情况, 开启后页面跳转时，默认页面即将消失会挂起队列，页面显示完毕后会恢复队列）
    func autoQueueManagement(enabled: Bool,
                             suspendOnWillDisappear: Bool = true,
                           resumeOnAppear: Bool = true) {
        autoManageConfig.enabled = enabled
        autoManageConfig.suspendOnWillDisappear = suspendOnWillDisappear
        autoManageConfig.resumeOnAppear = resumeOnAppear
        
        if enabled {
            UIViewController.enablePopupAutoManagement()
        }
    }
    
    /// 调度单个弹窗显示
    func schedule(popup: Popupable,
                 configuration: Configuration = .default,
                 condition: PopupDisplayCondition? = nil,
                 completion: (() -> Void)? = nil) {
      
        guard let item = self.checkOrCreatePopupItem(popup: popup, configuration: configuration, condition: condition, completion: completion) else {
            return
        }
        
        queue.append(item)
        queue.sort { $0.priority > $1.priority }
        
        if popup.priority == .emergency, let current = self.currentPopup, current.priority != .emergency {
            hideCurrentPopup(interrupted: true)
        } else {
            showNextIfNeeded()
        }
        
    }
    
    /// 批量调度多个弹窗显示
    func schedule(popups: [PopupsType]) {
        var hasEmergencyPopup = false
        
        for item in popups {
            let (popup, config, condition, completion) = item
            
            if let item = self.checkOrCreatePopupItem(popup: popup, configuration: config, condition: condition, completion: completion) {
                queue.append(item)
                if popup.priority == .emergency {
                    hasEmergencyPopup = true
                }
            }
        }
        
        queue.sort { $0.priority > $1.priority }
        
        if hasEmergencyPopup, let current = self.currentPopup, current.priority != .emergency {
            hideCurrentPopup(interrupted: true)
        } else {
            showNextIfNeeded()
        }
        
    }
    
    /// 批量调度多个弹窗显示（简化版）
    func schedule(popups: [Popupable]) {
        let items: [PopupsType] = popups.map { popup -> PopupsType in
            (popup, PopupScheduler.Configuration.default, nil, nil )
        }
        schedule(popups: items)
    }
    
    /// 主动挂起弹窗队列
    func suspend(hideCurrentPopup: Bool = true) {
        if hideCurrentPopup {
            isSuspended = true
            self.hideCurrentPopup()
        } else {
            guard !isSuspended else { return }
            isSuspended = true
        }
        
    }
    
    /// 回收当前弹窗到队列并挂起队列，后续用户手动恢复后将重新显示
    func reclaimCurrentPopupAndSuspend(completion: (() -> Void)? = nil) {
       
        isSuspended = true
        guard let current = currentPopup else {
            completion?()
            return
        }
        queue.insert(current, at: 0)
        hideCurrentPopup(interrupted: false, completion: completion)
    
    }
    
    /// 恢复弹窗队列
    func resume() {
        isSuspended = false
        showNextIfNeeded()
    }
    
    /// 清空所有待显示弹窗
    func clearQueue() {
        queue.removeAll()
    }
    
    /// 关闭当前显示的弹窗，如果队列没有挂起，会显示下一页（如果有）
    func dismissCurrentPopup() {
        hideCurrentPopup()
        
    }
    
    /// 检查当前是否在特定页面
    static func isOnViewController(_ viewControllerType: UIViewController.Type) -> Bool {
        guard let topVC = UIApplication.shared.topViewController else { return false }
        return topVC.isKind(of: viewControllerType)
    }
}

// MARK: - 私有方法
extension PopupScheduler {
    private func checkOrCreatePopupItem(popup: Popupable,
                                     configuration: Configuration = .default,
                                     condition: PopupDisplayCondition? = nil,
                                     completion: (() -> Void)? = nil) -> PopupItem? {
        if let popupId = popup.id {
            // 新插入的弹窗跟正在显示的弹窗 id 一致，则更新弹窗
            if let current = currentPopup, current.popupView.id == popupId {
                current.popupView.update(with: popup)
                return nil
            }
            // 新插入的弹窗跟待展示的弹窗 id 一致，则直接替换
            if let index = queue.firstIndex(where: { $0.popupView.id == popupId }) {
                let oldItem = queue[index]
                let newItem = PopupItem(popupView: popup,
                                      configuration: configuration,
                                      condition: condition ?? oldItem.condition,
                                      completion: completion ?? oldItem.completion)
                queue[index] = newItem
                return nil
            }
        }
        
        return PopupItem(popupView: popup,
                       configuration: configuration,
                       condition: condition,
                       completion: completion)
    }
    
    /// 显示下一个弹窗
    private func showNextIfNeeded() {
        guard !isSuspended, currentPopup == nil else { return }
        
        guard let index = queue.firstIndex(where: { $0.condition?() ?? true }) else { return }
        
        let item = queue.remove(at: index)
        currentPopup = item
        showPopup(item)
    }
    
    private func showPopup(_ item: PopupItem) {
        guard let window = UIApplication.shared.keyWindow else { return }
        
        let popup = item.popupView
        let config = item.configuration
        
        if config.showBackground {
            setupBackgroundView(in: window, config: config, popup: popup)
        }
        
        positionPopup(popup, in: window, position: config.position)
        
        window.addSubview(popup)
        
        UIView.animate(withDuration: 0.2) {
            self.backgroundView.alpha = 1
        }
        
        popup.show { [weak self] in
            item.completion?()
            if let onTap = popup.onCloseCurrentPopupAndJump {
                // 转换点击事件（如果闭包有值）
                self?.setupContentTap(for: popup, action: onTap)
            }
        }
    }
    
    private func setupBackgroundView(in window: UIWindow, config: Configuration, popup: Popupable) {
        backgroundView.backgroundColor = config.backgroundColor
        backgroundView.frame = window.bounds
        backgroundView.alpha = 0
        window.addSubview(backgroundView)
        
        if config.dismissOnBackgroundTap && popup.dismissOnBackgroundTap {
            let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
            backgroundView.addGestureRecognizer(tap)
        }
    }
    
    private func positionPopup(_ popup: UIView, in window: UIWindow, position: Configuration.Position) {
        switch position {
        case .center:
            popup.center = window.center
        case .top(let offset):
            popup.center = CGPoint(x: window.center.x, y: popup.bounds.height/2 + offset)
        case .bottom(let offset):
            popup.center = CGPoint(x: window.center.x, y: window.bounds.height - popup.bounds.height/2 - offset)
        case .custom(let frame):
            popup.frame = frame
        }
    }
    
    private func setupContentTap(for popup: UIView, action: @escaping () -> Void) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(contentTapped(_:)))
        popup.addGestureRecognizer(tap)
        objc_setAssociatedObject(popup, &actionKey, action, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    @objc private func contentTapped(_ sender: UITapGestureRecognizer) {
        guard let popup = sender.view,
              let action = objc_getAssociatedObject(popup, &actionKey) as? (() -> Void) else { return }
        
        // 启用自动管理队列不需要在这里调用挂起，反之帮忙挂起队列
        if !autoManageConfig.enabled {
            suspend()
        }
        action()
    }
    
    @objc private func backgroundTapped() {
        hideCurrentPopup()
    }
    
    
    /// 关闭当前展示的弹窗
    /// - Parameters:
    ///   - interrupted: true 表示打断，用于紧急弹窗显示，回收当前正在展示的普通弹窗
    ///   - completion: 关闭完成回调
    private func hideCurrentPopup(interrupted: Bool = false, completion: (() -> Void)? = nil) {
        // if self.isAnimating { return }
        
        guard let current = currentPopup, !isAnimating else {
            completion?()
            return
        }
        
        if interrupted && current.priority != .emergency {
            queue.insert(current, at: 0)
        }
        
        self.isAnimating = true
        current.popupView.hide { [weak self] in
            current.popupView.removeFromSuperview()
            
            UIView.animate(withDuration: 0.2, animations: {
                self?.backgroundView.alpha = 0
            }, completion: { _ in
                self?.backgroundView.removeFromSuperview()
                self?.currentPopup = nil
                self?.isAnimating = false
                
                if self?.isSuspended == false {
                    self?.showNextIfNeeded()
                }
                completion?()
            })
        }
    }
}




// MARK: - UIApplication 扩展
public extension UIApplication {
    var keyWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            return self.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first
        } else {
            return delegate?.window ?? nil
        }
    }
    
    var topViewController: UIViewController? {
        guard let rootViewController = keyWindow?.rootViewController else { return nil }
        
        func findTopViewController(from viewController: UIViewController?) -> UIViewController? {
            if let presented = viewController?.presentedViewController {
                return findTopViewController(from: presented)
            }
            
            if let navigation = viewController as? UINavigationController {
                return findTopViewController(from: navigation.visibleViewController)
            }
            
            if let tabBar = viewController as? UITabBarController {
                return findTopViewController(from: tabBar.selectedViewController)
            }
            
            return viewController
        }
        
        return findTopViewController(from: rootViewController)
    }
}




//
////
////  PopupViewScheduler.swift
////  TestPopup
////
////  Created by Jie on 2025/6/6.
////
//
//import UIKit
//
//// 条件类型
//typealias PopupDisplayCondition = () -> Bool
//// 批量添加弹窗别名
//typealias PopupsType = (Popupable, PopupScheduler.Configuration, PopupDisplayCondition?, (() -> Void)?)
//
//enum PopupPriority: Int, Comparable {
//    case low = 0
//    case middle = 1
//    case high = 2
//    // 紧急优先级，会立即显示，那么当前正在显示低优先级弹窗
//    case emergency = 3
//    
//    static func < (lhs: PopupPriority, rhs: PopupPriority) -> Bool {
//        return lhs.rawValue < rhs.rawValue
//    }
//}
//
//// 自定义弹窗协议
//protocol Popupable: UIView {
//    /// 弹窗唯一标识（可选, 默认 nil，都会添加到队列）
//    /// - 新添加进队列的弹窗有以下两种情况：
//    /// - 1. 弹窗 id 跟待展示队列中的弹窗 id 相同，则会替换；
//    /// - 2. 弹窗 id 跟正在展示中的弹窗 id 相同则会调用弹窗的 update(with:) 方法，根据需要可以自行更新数据
//    var id: String? { get set }
//    
//    /// 弹窗优先级（可选）
//    var priority: PopupPriority { get set }
//    
//    /// 显示动画（可选）
//    func show(completion: @escaping () -> Void)
//    
//    /// 隐藏动画（可选）
//    func hide(completion: @escaping () -> Void)
//    
//    /// 点击背景是否关闭（可选 默认 true）
//    var dismissOnBackgroundTap: Bool { get }
//    
//    /// 点击弹窗内容回调（回调有值，在点击执行该回调时，内部会认为是跳转其他页面，所以会挂起队列，需要手动调用调度器的 resume 方法恢复调度）
//    var onCloseCurrentPopupAndJump: (() -> Void)? { get set }
//    
//    /// 更新弹窗内容（当队列有新添加的弹窗，如果该弹窗跟正在显示的弹窗 id 相同，则会调用该方法，酌情更新数据）
//    func update(with newPopup: Popupable)
//}
//
//extension Popupable {
//    var id: String? {
//        get { nil }
//        set { }
//    }
//    
//    var priority: PopupPriority {
//        get { .low }
//        set { }
//    }
//    
//    var dismissOnBackgroundTap: Bool { true }
//    
//    func update(with newPopup: Popupable) {
//        self.subviews.forEach { $0.removeFromSuperview() }
//        self.addSubview(newPopup)
//    }
//    
//    func show(completion: @escaping () -> Void) {
//        alpha = 0
//        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
//        
//        UIView.animate(withDuration: 0.3,
//                       delay: 0,
//                       usingSpringWithDamping: 0.7,
//                       initialSpringVelocity: 0,
//                       options: .curveEaseInOut) {
//            self.alpha = 1
//            self.transform = .identity
//        } completion: { _ in
//            completion()
//        }
//    }
//    
//    func hide(completion: @escaping () -> Void) {
//        UIView.animate(withDuration: 0.2,
//                       animations: {
//            self.alpha = 0
//            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
//        }, completion: { _ in
//            completion()
//        })
//    }
//}
//
//// 弹窗调度器
//class PopupScheduler {
//    static let shared = PopupScheduler()
//    private init() {}
//    
//    private var queue = [PopupItem]()
//    private var currentPopup: PopupItem?
//    private let backgroundView = UIView()
//    private var isSuspended = false
//    private var isAnimating = false  // 是否在动画中, 防止快递点击背景关闭弹窗问题
//    
//    /// 检查队列是否被挂起
//    var isQueueSuspended: Bool {
//        return isSuspended
//    }
//    
//    struct PopupItem {
//        let popupView: Popupable
//        let configuration: Configuration
//        let condition: PopupDisplayCondition?
//        let completion: (() -> Void)?
//        
//        var priority: PopupPriority {
//            return popupView.priority
//        }
//    }
//    
//    struct Configuration {
//        var backgroundColor: UIColor = UIColor.black.withAlphaComponent(0.5)
//        var showBackground: Bool = true
//        var dismissOnBackgroundTap: Bool = true
//        var position: Position = .center
//        
//        enum Position {
//            case center
//            case top(offset: CGFloat)
//            case bottom(offset: CGFloat)
//            case custom(frame: CGRect)
//        }
//        
//        static let `default` = Configuration()
//    }
//}
//
//// MARK: - 公开方法
//extension PopupScheduler {
//    /// 调度单个弹窗显示
//    func schedule(popup: Popupable,
//                 configuration: Configuration = .default,
//                 condition: PopupDisplayCondition? = nil,
//                 completion: (() -> Void)? = nil) {
//        DispatchQueue.main.async {
//            guard let item = self.checkOrCreatePopupItem(popup: popup, configuration: configuration, condition: condition, completion: completion) else {
//                return
//            }
//            
//            // 添加到队列
//            self.queue.append(item)
//            // 按优先级排序
//            self.queue.sort { $0.priority > $1.priority }
//            
//            // 如果是紧急弹窗且当前有普通弹窗显示，则中断回收当前普通弹窗
//            if popup.priority == .emergency, let current = self.currentPopup, current.priority != .emergency {
//                // 回收普通弹窗，并关闭，关闭后会重新检查是否显示下一页
//                self.hideCurrentPopup(interrupted: true)
//            } else {
//                self.showNextIfNeeded()
//            }
//        }
//    }
//    
//    /// 批量调度多个弹窗显示
//    /// - Parameters:
//    ///   - popups: 弹窗及配置数组，每个元素是元组 (popup: Popupable, configuration: Configuration, condition: PopupDisplayCondition?, completion: (() -> Void)?)
//    func schedule(popups: [PopupsType]) {
//        DispatchQueue.main.async {
//            var hasEmergencyPopup = false
//            
//            for item in popups {
//                let (popup, config, condition, completion) = item
//                
//                if let item = self.checkOrCreatePopupItem(popup: popup, configuration: config, condition: condition, completion: completion) {
//                    self.queue.append(item)
//                    if popup.priority == .emergency {
//                        hasEmergencyPopup = true
//                    }
//                }
//            }
//            
//            // 排序队列
//            self.queue.sort { $0.priority > $1.priority }
//            
//            // 如果有紧急弹窗且当前有普通弹窗显示，则中断当前弹窗
//            if hasEmergencyPopup, let current = self.currentPopup, current.priority != .emergency {
//                self.hideCurrentPopup(interrupted: true)
//            } else {
//                self.showNextIfNeeded()
//            }
//        }
//    }
//    
//    /// 批量调度多个弹窗显示（简化版, 展示条件将统一为 true）
//    /// - Parameters:
//    ///   - popups: 弹窗数组，使用默认配置
//    func schedule(popups: [Popupable]) {
//        let items: [PopupsType] = popups.map { popup -> PopupsType in
//            (popup, PopupScheduler.Configuration.default, nil, nil )
//        }
//        schedule(popups: items)
//    }
//    
//    /// 主动挂起弹窗队列
//    /// Parameter hideCurrentPopup: true 挂起并关闭当前显示中的弹窗；false 单纯挂起队列
//    /// - 挂起后新添加的弹窗会保留在队列中，但不会自动显示
//    /// - 需要调用 resume() 恢复显示
//    func suspend(hideCurrentPopup: Bool = true) {
//        DispatchQueue.main.async {
//            if hideCurrentPopup {
//                self.isSuspended = true
//                self.hideCurrentPopup()
//            } else {
//                guard !self.isSuspended else { return }
//                self.isSuspended = true
//                print("弹窗队列已挂起")
//            }
//        }
//    }
//    
//    /// 恢复弹窗队列
//    func resume() {
//        DispatchQueue.main.async {
//            self.isSuspended = false
//            self.showNextIfNeeded()
//        }
//    }
//    
//    /// 清空所有待显示弹窗
//    func clearQueue() {
//        DispatchQueue.main.async {
//            self.queue.removeAll()
//        }
//    }
//    
//    /// 关闭当前显示的弹窗, 如果队列没有挂起，会检查是否有下一个弹窗，有则显示下一个弹窗
//    func dismissCurrentPopup() {
//        DispatchQueue.main.async {
//            self.hideCurrentPopup()
//        }
//    }
//}
//
//extension PopupScheduler {
//    /// 检查当前是否在特定页面
//    static func isOnViewController(_ viewControllerType: UIViewController.Type) -> Bool {
//        guard let topVC = UIApplication.shared.topViewController else { return false }
//        return topVC.isKind(of: viewControllerType)
//    }
//}
//
//// MARK: - 私有方法
//extension PopupScheduler {
//    /// 检查或创建弹窗模型
//    private func checkOrCreatePopupItem(popup: Popupable,
//                                     configuration: Configuration = .default,
//                                     condition: PopupDisplayCondition? = nil,
//                                     completion: (() -> Void)? = nil
//    ) -> PopupItem? {
//        // 检查是否有相同 ID 的弹窗
//        if let popupId = popup.id {
//            // 1. 检查当前显示的弹窗，有则更新数据
//            if let current = self.currentPopup, current.popupView.id == popupId {
//                current.popupView.update(with: popup)
//                return nil
//            }
//            
//            // 2. 检查队列，待展示已有相同 id 则替换
//            if let index = self.queue.firstIndex(where: { $0.popupView.id == popupId }) {
//                let oldItem = self.queue[index]
//                let newItem = PopupItem(popupView: popup,
//                                      configuration: configuration,
//                                      condition: condition ?? oldItem.condition,
//                                      completion: completion ?? oldItem.completion)
//                self.queue[index] = newItem
//                return nil
//            }
//        }
//        
//        return PopupItem(popupView: popup,
//                       configuration: configuration,
//                       condition: condition,
//                       completion: completion)
//    }
//    
//    /// 显示下一个弹窗
//    private func showNextIfNeeded() {
//        guard !isSuspended, currentPopup == nil else { return }
//        
//        // 找到第一个满足条件的弹窗
//        guard let index = queue.firstIndex(where: { $0.condition?() ?? true }) else { return }
//        
//        let item = queue.remove(at: index)
//        currentPopup = item
//        showPopup(item)
//    }
//    
//    private func showPopup(_ item: PopupItem) {
//        guard let window = UIApplication.shared.keyWindow else { return }
//        
//        let popup = item.popupView
//        let config = item.configuration
//        
//        // 设置背景
//        if config.showBackground {
//            setupBackgroundView(in: window, config: config, popup: popup)
//        }
//        
//        // 设置弹窗位置
//        positionPopup(popup, in: window, position: config.position)
//        
//        window.addSubview(popup)
//        
//        // 显示动画
//        UIView.animate(withDuration: 0.2) {
//            self.backgroundView.alpha = 1
//        }
//        
//        popup.show { [weak self] in
//            item.completion?()
//            if let onTap = popup.onCloseCurrentPopupAndJump {
//                self?.setupContentTap(for: popup, action: onTap)
//            }
//        }
//    }
//    
//    private func setupBackgroundView(in window: UIWindow, config: Configuration, popup: Popupable) {
//        backgroundView.backgroundColor = config.backgroundColor
//        backgroundView.frame = window.bounds
//        backgroundView.alpha = 0
//        window.addSubview(backgroundView)
//        
//        if config.dismissOnBackgroundTap && popup.dismissOnBackgroundTap {
//            let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
//            backgroundView.addGestureRecognizer(tap)
//        }
//    }
//    
//    private func positionPopup(_ popup: UIView, in window: UIWindow, position: Configuration.Position) {
//        switch position {
//        case .center:
//            popup.center = window.center
//        case .top(let offset):
//            popup.center = CGPoint(x: window.center.x, y: popup.bounds.height/2 + offset)
//        case .bottom(let offset):
//            popup.center = CGPoint(x: window.center.x, y: window.bounds.height - popup.bounds.height/2 - offset)
//        case .custom(let frame):
//            popup.frame = frame
//        }
//    }
//    
//    private func setupContentTap(for popup: UIView, action: @escaping () -> Void) {
//        let tap = UITapGestureRecognizer(target: self, action: #selector(contentTapped(_:)))
//        popup.addGestureRecognizer(tap)
//        objc_setAssociatedObject(popup, &actionKey, action, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
//    }
//    
//    @objc private func contentTapped(_ sender: UITapGestureRecognizer) {
//        guard let popup = sender.view,
//              let action = objc_getAssociatedObject(popup, &actionKey) as? (() -> Void) else { return }
//        
//        suspend()
//        action()
//    }
//    
//    @objc private func backgroundTapped() {
//        hideCurrentPopup()
//    }
//    
//    private func hideCurrentPopup(interrupted: Bool = false, completion: (() -> Void)? = nil) {
//        if self.isAnimating { return }
//        
//        guard let current = currentPopup else {
//            completion?()
//            return
//        }
//        
//        // 如果是被中断的普通弹窗，放回队列头部
//        if interrupted && current.priority != .emergency {
//            queue.insert(current, at: 0)
//        }
//        
//        self.isAnimating = true
//        current.popupView.hide { [weak self] in
//            current.popupView.removeFromSuperview()
//            
//            UIView.animate(withDuration: 0.2, animations: {
//                self?.backgroundView.alpha = 0
//            }, completion: { _ in
//                self?.backgroundView.removeFromSuperview()
//                self?.currentPopup = nil
//                self?.isAnimating = false
//                
//                if self?.isSuspended == false {
//                    self?.showNextIfNeeded()
//                }
//                completion?()
//            })
//        }
//    }
//}
//
//private var actionKey: UInt8 = 0
//
//// 扩展：获取顶层视图控制器
//extension UIApplication {
//    var keyWindow: UIWindow? {
//        if #available(iOS 13.0, *) {
//            return self.connectedScenes
//                .compactMap { $0 as? UIWindowScene }
//                .first?.windows.first
//        } else {
//            return delegate?.window ?? nil
//        }
//    }
//    
//    var topViewController: UIViewController? {
//        guard let rootViewController = keyWindow?.rootViewController else { return nil }
//        
//        func findTopViewController(from viewController: UIViewController?) -> UIViewController? {
//            if let presented = viewController?.presentedViewController {
//                return findTopViewController(from: presented)
//            }
//            
//            if let navigation = viewController as? UINavigationController {
//                return findTopViewController(from: navigation.visibleViewController)
//            }
//            
//            if let tabBar = viewController as? UITabBarController {
//                return findTopViewController(from: tabBar.selectedViewController)
//            }
//            
//            return viewController
//        }
//        
//        return findTopViewController(from: rootViewController)
//    }
//}
