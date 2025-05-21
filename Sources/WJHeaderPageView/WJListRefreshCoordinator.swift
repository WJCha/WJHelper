//
//  WJListRefreshCoordinator.swift
//  FudaiShenghuo
//
//  Created by Jie on 2025/4/25.
//  Copyright © 2025 FengQing. All rights reserved.
//

import UIKit

/// 用于**子列表**头部刷新的滚动联动协调器
@objcMembers
open class WJListRefreshCoordinator: NSObject, WJHeaderPageViewCoordinateProtocol {

    public weak var pageView: WJHeaderPageView?

    /// 主视图 scrollView 是否可滚动
    public var mainCanScroll: Bool = true
    /// 子视图 scrollView 是否可滚动
    public var childCanScroll: Bool = false
    

    /// 是否正在下拉子列表刷新
    public var isDragRefresh: Bool = false
    
    // 重置子视图的滚动列表偏移量为 0 回调
    public var listScrollViewResetContentOffsetToZero: (() -> Void)?
    

    
  
    /// 主视图 ScrollView 滚动方法处理，可以继承本类，重写该方法
    /// - Parameters:
    ///   - scrollView: 主视图 ScrollView
    ///   - headerHeight: 整个头部的高度
    ///   - pinOffset: 吸顶偏移量
    open func mainScrollViewDidScroll(_ scrollView: UIScrollView, headerHeight: CGFloat, pinOffset: CGFloat) {
        
        var headerDiff: CGFloat = headerHeight
        if headerHeight < pinOffset { headerDiff = pinOffset }
        
        if scrollView.contentOffset.y >= headerDiff - pinOffset {
            // 吸顶
            scrollView.contentOffset = .init(x: 0, y: headerDiff - pinOffset)
            if (mainCanScroll) {
                mainCanScroll = false;
                childCanScroll = true
            }
            
        } else {
            
            // 子视图滚动中，固定偏移量为吸顶
            if (!mainCanScroll) {
                // 当主层不能滚动的时候，即正在吸顶时，继续让其固定 offsetY , 此时只有子层可以滚动
                scrollView.contentOffset = .init(x: 0, y: headerDiff - pinOffset)
     
            }
            
            if scrollView.contentOffset.y <= 0 || isDragRefresh {
                scrollView.contentOffset = .zero
            }
            
        }
    }
    
    
    // 用于稍微减少 listScrollViewResetContentOffsetToZero 回调的执行
    private var limit: Bool = false
    private let throttler = WJThrottler(interval: 1.0) // 1 秒内只允许调用一次
    

    
    /// ⚠️ 请在子视图 scrollView 的 scrollViewDidScroll: 方法中调用该方法
    /// 子视图 ScrollView 滚动方法处理
    open func listScrollViewDidScroll(_ scrollView: UIScrollView) {
        
        if scrollView.contentOffset.y > 0, self.pageView!.mainCollectionView.contentOffset.y >= 0 {
            limit = true
        }
        
        // 子视图要设置 alwaysBounceVertical 为 true；
        // 否则如果子视图内容高度不足于滚动时，可能导致无法拖动切换到滚动主视图
        // 这里帮忙做一层小改动，子视图最好要自己设置，毕竟初始状态时，这里无法帮忙设置
        if !scrollView.alwaysBounceVertical { scrollView.alwaysBounceVertical = true }
        
        // 避免下拉过程往上滚动导致立马回弹偏移量为 0
        isDragRefresh = self.pageView!.progress == 0 && scrollView.contentOffset.y < 0
        
        // 子视图不能滚动的情况下，一直都要偏移 0
        if !childCanScroll, self.pageView!.mainCollectionView.contentOffset.y != 0 {
            
            scrollView.contentOffset = .zero
        }
        
        if scrollView.contentOffset.y <= 0 {
            childCanScroll = false
            //给主视图的scrollView发送改变是否可以滚动的状态。让主视图的scrollView可以滚动
            mainCanScroll = true
            //重置子视图的滚动列表偏移量为 0
            if limit && (pageView!.totalHeaderHeight ?? 0) > CGFloat(pageView!.pinOffset) {
                throttler.throttle { [weak self] in
                    DispatchQueue.main.async {
                        self?.listScrollViewResetContentOffsetToZero?()
                    }
                    //print("执行动作")
                }
                
                
                limit = false
            }
        }


        
        
        
        
    }


}
