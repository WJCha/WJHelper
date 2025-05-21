//
//  WJHeaderPageViewCoordinateProtocol.swift
//  FudaiShenghuo
//
//  Created by Jie on 2025/4/25.
//  Copyright © 2025 FengQing. All rights reserved.
//

import UIKit

@MainActor
@objc
public protocol WJHeaderPageViewCoordinateProtocol: NSObjectProtocol {
    /// pageView 实现时，请将其声明为弱引用, 即 weak var pageView: WJHeaderPageView?
    /// WJHeaderPageView 初始化时内部会自动为该属性赋值
    var pageView: WJHeaderPageView? { get set }
    /// 重置子滚动视图 ContentOffset 偏移量为 CGRect.zero 回调
    var listScrollViewResetContentOffsetToZero: (() -> Void)? { get set }
    /// WJHeaderPageView 主视图滚动会自动调用该方法，在此方法处理滚动联动
    func mainScrollViewDidScroll(_ scrollView: UIScrollView, headerHeight: CGFloat, pinOffset: CGFloat)
    /// ⚠️ 请在子视图 scrollView 的 scrollViewDidScroll: 方法中主动调用该方法，在此方法处理滚动联动
    func listScrollViewDidScroll(_ scrollView: UIScrollView)
}
