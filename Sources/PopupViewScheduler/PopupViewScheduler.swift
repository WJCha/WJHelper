//
//  PopupViewScheduler.swift
//  TestPopup
//
//  Created by FuDai on 2025/6/6.
//

/*
 用法示例：
 
 // 自定义弹窗视图
 class ClickablePopupView: UIView, Popupable {
     
     var onContentTap: (() -> Void)?
     
     init() {
         super.init(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
         setupView()
     }
     
     required init?(coder: NSCoder) {
         fatalError("init(coder:) has not been implemented")
     }
     
     private func setupView() {
         backgroundColor = .systemBlue
         layer.cornerRadius = 12
         
         let label = UILabel()
         label.text = "点击我跳转到下一页"
         label.textAlignment = .center
         label.textColor = .white
         label.frame = bounds
         addSubview(label)
         
         // 添加点击手势
         let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
         addGestureRecognizer(tap)
     }
     
     @objc private func didTap() {
         onContentTap?()
     }
 }

 
 
 使用：
 class ViewController: UIViewController {
     override func viewDidLoad() {
         super.viewDidLoad()
         
         // 创建多个普通弹窗
         let popup1 = ClickablePopupView()
         popup1.backgroundColor = .systemPink
         
         let popup2 = ClickablePopupView()
         popup2.backgroundColor = .orange
         
         let popup3 = ClickablePopupView()
         popup3.backgroundColor = .yellow
         
         // 设置第一个弹窗的点击事件
         popup1.onContentTap = { [weak self] in
             let vc = HomeViewController()
             vc.modalPresentationStyle = .fullScreen
             self?.present(vc, animated: true)
             
         }
         
      
         
         // 调度普通弹窗
         PopupViewScheduler.shared.schedule(popup: popup1, configuration: .init(backgroundColor: .red, showBackground: false, dismissOnBackgroundTap: false, position: .custom(frame: view.bounds)), completion:  {
             print("第一个弹框完成")
         })
         
         PopupViewScheduler.shared.schedule(popup: popup2, condition: {
             PopupViewScheduler.isOnViewController(HomeViewController.self)
         }, completion: {
             print("第2个弹框完成")
         })
         PopupViewScheduler.shared.schedule(popup: popup3, condition: {
             PopupViewScheduler.isOnViewController(ViewController.self)
         })
         
         // 5秒后触发紧急弹窗
         DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
             let emergencyPopup = ....
             PopupViewScheduler.shared.showEmergency(popup: emergencyPopup) {
                 print("紧急弹窗已显示")
             }
         }
     }
     
     override func viewDidAppear(_ animated: Bool) {
         super.viewDidAppear(animated)
         PopupViewScheduler.shared.resume() // 控制器回来时，恢复队列
     }
     

 }

 
 */

import UIKit

// 条件类型
typealias PopupDisplayCondition = () -> Bool

// 自定义弹窗协议
protocol Popupable: UIView {
    /// 显示动画
    func show(completion: @escaping () -> Void)
    
    /// 隐藏动画
    func hide(completion: @escaping () -> Void)
    
    /// 点击背景是否关闭（默认true）
    var dismissOnBackgroundTap: Bool { get }
    
    /// 点击弹窗内容回调
    /// - 如果闭包有值，调度器会在点击时挂起调度队列，如方便跳转到其他页面时，不会马上显示下一个弹框，
    /// 反之需要自己在点击弹框需要页面跳转时手动挂起队列，等待合适时机恢复队列
    var onContentTap: (() -> Void)? { get set }
}

// 协议默认实现
extension Popupable {
    var dismissOnBackgroundTap: Bool { true }
    
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

// 弹窗调度器（支持紧急插入）
class PopupViewScheduler {
    static let shared = PopupViewScheduler()
    private init() {}
    
    private var popupQueue = [PopupItem]()
    private var currentPopup: PopupItem?
    private var suspendedPopup: PopupItem? // 被紧急弹窗中断的普通弹窗
    private let backgroundView = UIView()
    private var isSuspended = false
    
    private struct PopupItem {
        let popupView: Popupable
        let configuration: Configuration
        let condition: PopupDisplayCondition?
        let completion: (() -> Void)?
        let isEmergency: Bool // 是否紧急弹窗
    }
    
    struct Configuration {
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
        
        static let `default` = Configuration()
    }
    
    // MARK: - 公开方法
    
    /// 调度普通弹窗显示
    func schedule(popup: Popupable,
                  configuration: Configuration = .default,
                  condition: PopupDisplayCondition? = nil,
                  completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let item = PopupItem(popupView: popup,
                               configuration: configuration,
                               condition: condition,
                               completion: completion,
                               isEmergency: false)
            
            self.popupQueue.append(item)
            self.showNextIfNeeded()
        }
    }
    
    /// 紧急插入弹窗（立即显示）
    func showEmergency(popup: Popupable,
                       configuration: Configuration = .default,
                       completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let item = PopupItem(popupView: popup,
                               configuration: configuration,
                               condition: nil,
                               completion: completion,
                               isEmergency: true)
            
            // 如果有当前显示的弹窗，先保存并隐藏
            if let current = self.currentPopup, !current.isEmergency {
                self.suspendedPopup = current
                self.hideCurrentPopup(completion: {
                    self.currentPopup = item
                    self.showPopup(item)
                })
            } else {
                // 如果没有普通弹窗显示，或者当前已经是紧急弹窗，直接显示
                self.currentPopup = item
                self.showPopup(item)
            }
        }
    }
    
    /// 暂停弹窗队列
    func suspend() {
        DispatchQueue.main.async {
            self.isSuspended = true
            self.hideCurrentPopup()
        }
    }
    
    /// 恢复弹窗队列
    func resume() {
        DispatchQueue.main.async {
            self.isSuspended = false
            self.showNextIfNeeded()
        }
    }
    
    /// 清空所有待显示弹窗
    func clearQueue() {
        DispatchQueue.main.async {
            self.popupQueue.removeAll()
        }
    }
    
    /// 检查当前是否在特定页面
    static func isOnViewController(_ viewControllerType: UIViewController.Type) -> Bool {
        guard let topVC = UIApplication.shared.topViewController else { return false }
        return topVC.isKind(of: viewControllerType)
    }
    
    
}

// MARK: - 私有方法
extension PopupViewScheduler {
    private func showNextIfNeeded() {
        guard !isSuspended, currentPopup == nil else { return }
        
        // 如果有被中断的普通弹窗，优先恢复
        if let suspended = suspendedPopup {
            suspendedPopup = nil
            currentPopup = suspended
            showPopup(suspended)
            return
        }
        
        // 找到第一个满足条件的弹窗
        guard let index = popupQueue.firstIndex(where: { item in
            item.condition?() ?? true
        }) else { return }
        
        let item = popupQueue.remove(at: index)
        currentPopup = item
        showPopup(item)
    }
    
    private func showPopup(_ item: PopupItem) {
        guard let window = UIApplication.shared.keyWindow else { return }
        
        let popup = item.popupView
        let config = item.configuration
        
        // 设置背景
        if config.showBackground {
            setupBackgroundView(in: window, config: config, popup: popup)
        }
        
        // 设置弹窗位置
        positionPopup(popup, in: window, position: config.position)
        
        window.addSubview(popup)
        
        // 显示动画
        UIView.animate(withDuration: 0.2) {
            self.backgroundView.alpha = 1
        }
        
        popup.show { [weak self] in
            item.completion?()
            // 如果有设置点击回调，转换一下，监听点击事件，一旦点击则挂起弹框队列
            if let onTap = popup.onContentTap {
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
        
        suspend()
        action()
    }
    
    @objc private func backgroundTapped() {
        hideCurrentPopup()
    }
    
    private func hideCurrentPopup(completion: (() -> Void)? = nil) {
        guard let current = currentPopup else {
            completion?()
            return
        }
        
        current.popupView.hide { [weak self] in
            current.popupView.removeFromSuperview()
            
            UIView.animate(withDuration: 0.2, animations: {
                self?.backgroundView.alpha = 0
            }, completion: { _ in
                self?.backgroundView.removeFromSuperview()
                self?.currentPopup = nil
                
                if self?.isSuspended == false {
                    completion?()
                    self?.showNextIfNeeded()
                } else {
                    completion?()
                }
            })
        }
    }
}

private var actionKey: UInt8 = 0

// 扩展：获取顶层视图控制器
extension UIApplication {
    var keyWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            return self.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .first?.windows.first
        } else {
            return UIApplication.shared.delegate?.window ?? nil
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
