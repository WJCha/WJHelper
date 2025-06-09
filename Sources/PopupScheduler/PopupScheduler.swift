
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
    public static let shared = PopupScheduler()
    private init() {}
    
    // 队列挂起恢复自动管理配置
    private(set) var autoManageConfig = AutoManageConfiguration()
    
    private var queue = [PopupItem]()
    private var currentPopup: PopupItem?
    private let backgroundView = UIView()
    private var isSuspended = false
    private var isAnimating = false
    
    /// 检查队列是否被挂起
    public var isQueueSuspended: Bool {
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
        
        public enum Position {
            case center
            case top(offset: CGFloat)
            case bottom(offset: CGFloat)
            case custom(frame: CGRect)
        }
        
        public init(backgroundColor: UIColor = UIColor.black.withAlphaComponent(0.5),
                    showBackground: Bool = true,
                    dismissOnBackgroundTap: Bool = true,
                    position: Position = .center
        ) {
            self.backgroundColor = backgroundColor
            self.showBackground = showBackground
            self.dismissOnBackgroundTap = dismissOnBackgroundTap
            self.position = position
        }
        
        @MainActor public static let `default` = Configuration()
    }
    
    /// 自动管理队列的配置
    public struct AutoManageConfiguration {
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
    var mainWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            return self.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first
        } else {
            return delegate?.window ?? nil
        }
    }
    
    var topViewController: UIViewController? {
        guard let rootViewController = mainWindow?.rootViewController else { return nil }
        
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


