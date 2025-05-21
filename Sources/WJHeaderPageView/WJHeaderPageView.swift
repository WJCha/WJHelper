//
//  WJHeaderPageView.swift
//  FudaiShenghuo
//
//  Created by Jie on 2025/3/26.
//  Copyright © 2025 FengQing. All rights reserved.
//
//  ⚠️ 内层的 scrollview 视图要设置 alwaysBounceVertical 为 true；

import UIKit

fileprivate let kHeaderIdentifier = "WJHeaderPageView.CategoryTitleView"
fileprivate let kPageCellIdentifier = "WJHeaderPageView.PageCell"



@objc
public protocol WJHeaderPageViewDelegate: NSObjectProtocol {
    
    /// header 的 cell 个数, 默认 1
    @objc optional
    func numberOfItemInHeader(_ pageView: WJHeaderPageView) -> Int
    
    /// header 的 cell 样式
    func pageView(_ pageView: WJHeaderPageView, cellForItemInHeaderAt indexPath: IndexPath) -> UICollectionViewCell
    
    /// header 的 cell 高度，默认 200
    @objc optional
    func pageView(_ pageView: WJHeaderPageView, heightForItemInHeaderAt indexPath: IndexPath) -> Int
    
    /// 吸顶的标题栏高度， 默认 50
    @objc optional
    func heightForPinSectionHeader(in pageView: WJHeaderPageView) -> Int
    
    /// 返回吸顶的标题栏视图，可以返回 JXPagerView 框架中的 JXCategoryView
    func viewForPinSectionHeader(in pageView: WJHeaderPageView) -> UIView
    
    /// 返回分页容器，可以返回 JXPagerView 框架中的 JXCategoryListContainerView
    func viewForPageContainer(in pageView: WJHeaderPageView) -> UIView
    
    /// 手势处理
    @objc optional
    func mainCollectionViewGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    
    /// ⚠️ 需要自行在该代理方法中将嵌套的子列表的 ScrollView 的偏移量 contentOffset 重置为 0
    @objc optional
    func listScrollViewWillResetContentOffsetToZero(_ pageView: WJHeaderPageView)
    
    /// 主视图滚动变化
    @objc optional
    func mainCollectionViewDidScrollChange(_ pageView: WJHeaderPageView, pinRate: CGFloat, contentOffset: CGPoint)
    
    /// 主视图是否可以点击状态栏回到顶部，默认 false
    @objc optional
    func mainCollectionViewShouldScrollToTop(_ pageView: WJHeaderPageView) -> Bool
    
}

@objcMembers
public class WJHeaderPageView: UIView {
    
    
    /// 代理
    public weak var delegate: WJHeaderPageViewDelegate?
    /// 吸顶偏移量，大于 0，正数越大越往下沉, 取整数，在比较时可以避免一些小数点精度问题
    public var pinOffset: Int = 0 { didSet { pinOffset = max(pinOffset, 0) } }
    
    /// 吸顶进度
    private(set) var progress: CGFloat = 0
  
    
    /// 协调器，将其传递给子列表。
    /// 在子列表 ScrollView 的 scrollViewDidScroll：滚动方法中调用 coordinator 的 listScrollViewDidScroll：用于处理主视图 ScrollView 和子视图 ScrollView 滑动联动
    private(set) var coordinator: WJHeaderPageViewCoordinateProtocol!

    /// 主容器滚动视图，即外层滚动视图
    private(set) lazy var mainCollectionView: WJHeaderPageMainCollectionView = getCollectionView
    
    /// 分类标题
    weak private var categoryTitleView: UIView?

    public init(frame: CGRect, coordinator: WJHeaderPageViewCoordinateProtocol?) {
        super.init(frame: frame)
        configPageView(coordinator: coordinator)
        
    }
    
    private func configPageView(coordinator: WJHeaderPageViewCoordinateProtocol?) {
        updateCoordinator(coordinator ?? WJHeaderRefreshCoordinator())
        configUI()
        bindEvent()
    }
    


    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configPageView(coordinator:  WJHeaderRefreshCoordinator())
        //fatalError("init(coder:) has not been implemented")
    }
    

    public override func layoutSubviews() {
        super.layoutSubviews()
        mainCollectionView.frame = bounds
    }

}

public extension WJHeaderPageView {
    /// 更新协调器, 方法内部会为 coordinator.pageView 赋值
    func updateCoordinator(_ coordinator: WJHeaderPageViewCoordinateProtocol) {
        self.coordinator = coordinator
        self.coordinator.pageView = self
    }
    
    /// 注册头部 cell
    func registerHeaderCell(_ cellClass: AnyClass?, forCellWithReuseIdentifier identifier: String ) {
        mainCollectionView.register(cellClass, forCellWithReuseIdentifier: identifier)
    }
    
    /// 复用头部 cell
    func dequeueReusableHeaderCell(withReuseIdentifier identifier: String, for indexPath: IndexPath) -> UICollectionViewCell {
        mainCollectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
    }
    
    /// 获取某个头部 cell
    func cellForHeader(at index: Int) -> UICollectionViewCell? {
        mainCollectionView.cellForItem(at: .init(item: index, section: 0))
    }

    /// 刷新数据
    func reloadData() {
        self.mainCollectionView.reloadData()
    }
    
    /// 直接吸顶
    func pinHeader(animate: Bool = true) {
        setProgress(1.0, animate: animate)
    }
    
    /// 设置吸顶进度
    func setProgress(_ progress: CGFloat, animate: Bool = false) {
        guard let totalHeaderHeight else { return }
        
        var rate: CGFloat = progress
        if progress <= 0 {
            rate = 0
        }
        if progress >= 1 { rate = 1 }
        let distance: CGFloat = totalHeaderHeight - CGFloat(pinOffset)
        mainCollectionView.setContentOffset(.init(x: 0, y: distance * rate), animated: animate)
    }
    
    /// 滚动到顶部
    func scrollToTop(animate: Bool = true) {
        mainCollectionView.setContentOffset(.init(x: 0, y: 0), animated: animate)
        coordinator.listScrollViewResetContentOffsetToZero?()
    }
    
    /// 头部视图总高度
    var totalHeaderHeight: CGFloat? {
        
        guard let categoryView = getAndSaveCategoryTitleView() else { return nil }
        return categoryView.frame.origin.y
        
//        if let titleView = categoryTitleView {
//            return titleView.frame.origin.y
//        }
//        
//        guard let categoryView = mainCollectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: .init(item: 0, section: 1))
//        else {
//            return nil
//        }
//        categoryTitleView = categoryView
//        return categoryView.frame.origin.y
    }
    

}

private extension WJHeaderPageView {
    
    var getCollectionView: WJHeaderPageMainCollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero
        let collectionView = WJHeaderPageMainCollectionView.init(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.isDirectionalLockEnabled = true
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: kPageCellIdentifier)
        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: kHeaderIdentifier)
        //collectionView.scrollsToTop = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.gestureDelegate = self
        collectionView.isPrefetchingEnabled = false
        if #available(iOS 11.0, *) {
            collectionView.contentInsetAdjustmentBehavior = .never
        }
        return collectionView
    }
    
    func configUI() {
        addSubview(mainCollectionView)
    }
    
    func bindEvent() {
        coordinator.listScrollViewResetContentOffsetToZero = { [weak self] in
            guard let self else { return }
            self.delegate?.listScrollViewWillResetContentOffsetToZero?(self)
        }
    }
 
    /// 分类标题栏高度
    var categoryTitleViewHeight: Int {
        delegate?.heightForPinSectionHeader?(in: self) ?? 50
    }
    
    /// 获取分类标题视图
    func getAndSaveCategoryTitleView() -> UIView? {
        if let titleView = categoryTitleView {
            return titleView
        }
        
        guard let categoryView = mainCollectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: .init(item: 0, section: 1))
        else {
            return nil
        }
        categoryTitleView = categoryView
        return categoryTitleView
    }
}

extension WJHeaderPageView: WJHeaderPageMainCollectionViewDelegate {
    
    public func mainCollectionViewGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if let outDeal = delegate?.mainCollectionViewGestureRecognizer?(gestureRecognizer, shouldRecognizeSimultaneouslyWith: otherGestureRecognizer) {
            return outDeal
        }
        
        
        
//        guard let categoryView = mainCollectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: .init(item: 0, section: 1)) else { return false }
//        
//        let hoverHeight = categoryView.frame.origin.y + CGFloat(categoryTitleViewHeight)
//        
//        if hoverHeight != 0 && otherGestureRecognizer.location(in: gestureRecognizer.view).y > hoverHeight {
//            return true
//        }
//        
    
        return gestureRecognizer.isKind(of: UIPanGestureRecognizer.self) && otherGestureRecognizer.isKind(of: UIPanGestureRecognizer.self)
    }
}


extension WJHeaderPageView: UICollectionViewDataSource {
    
    // 第一组为 header 头部样式
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        2
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return delegate?.numberOfItemInHeader?(self) ?? 1
        }
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // 头部 cell
        if indexPath.section == 0 {
            return delegate?.pageView(self, cellForItemInHeaderAt: indexPath) ?? UICollectionViewCell(frame: .zero)
        }
        // 分页容器 cell
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: kPageCellIdentifier, for: indexPath)
        cell.backgroundColor = .clear
        guard let container = delegate?.viewForPageContainer(in: self) else { return cell }
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.contentView.addSubview(container)
        container.frame = cell.bounds
        return cell
        
    }
    
    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionFooter {
            return UICollectionReusableView.init(frame: .zero)
        }
        
        if indexPath.section == 0 {
            return UICollectionReusableView.init(frame: .zero)
        }
        
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: kHeaderIdentifier, for: indexPath)
        
        guard let categoryView = delegate?.viewForPinSectionHeader(in: self) else {
            return UICollectionReusableView.init(frame: .zero)
        }
        header.backgroundColor = .clear
        header.subviews.forEach { $0.removeFromSuperview() }
        header.addSubview(categoryView)
        categoryView.frame = header.bounds
        categoryTitleView = header
        return header
        
    }
    
    
    
    
}

extension WJHeaderPageView: UICollectionViewDelegate {
    
    public func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        delegate?.mainCollectionViewShouldScrollToTop?(self) ?? false
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let categoryView = mainCollectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: .init(item: 0, section: 1))
        else {
            delegate?.mainCollectionViewDidScrollChange?(self, pinRate: 0, contentOffset: scrollView.contentOffset)
            return
        }
        
        progress = 0
        if categoryView.frame.origin.y > CGFloat(pinOffset) {
            progress = min(scrollView.contentOffset.y / (categoryView.frame.origin.y - CGFloat(pinOffset)), 1);
            progress = max(0, progress)
        }
        
        delegate?.mainCollectionViewDidScrollChange?(self, pinRate: progress, contentOffset: scrollView.contentOffset)
        
        coordinator.mainScrollViewDidScroll(scrollView, headerHeight: categoryView.frame.origin.y, pinOffset: CGFloat(pinOffset))
        
//        if scrollView.contentOffset.y >= categoryView.frame.origin.y - pinOffset {
//            // 吸顶
//            scrollView.contentOffset = .init(x: 0, y: categoryView.frame.origin.y - pinOffset)
//            if (mainCanScroll) {
//                mainCanScroll = false;
//                NotificationCenter.default.post(name: .init("ddddd"), object: nil)
//            }
//            
//        } else {
//            
//            if (!mainCanScroll) {
//                // 当主层不能滚动的时候，即正在吸顶时，继续让其固定 offsetY , 此时只有子层可以滚动
//                scrollView.contentOffset = .init(x: 0, y: categoryView.frame.origin.y - pinOffset)
//     
//            }
//
//            
//        }
        
    }
    
}

extension WJHeaderPageView: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return .zero
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 0 { return CGSize.zero }
        return CGSize.init(width: collectionView.frame.size.width, height: CGFloat(categoryTitleViewHeight))
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 0 {
            let height = delegate?.pageView?(self, heightForItemInHeaderAt: indexPath) ?? 200
            // ⚠️ UICollectionView 的 Bug，如果第一组 cell 高度为 0，会导致直接不走 cellForItemAtIndexPath: 数据源方法，哪怕第二组 cell 高度不为 0，
            // 要解决这个 Bug，第一组 cell 高度为 0 时，只需要返回 0.1 的高度即可
            return CGSize.init(width: collectionView.frame.size.width, height: height <= 0 ? CGFloat(0.1) : CGFloat(height))
        }
        let pageHeight = collectionView.frame.size.height - CGFloat(categoryTitleViewHeight)
        return CGSize.init(width: collectionView.frame.size.width, height: CGFloat(pageHeight))
    }
}
