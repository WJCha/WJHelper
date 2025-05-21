//
//  WaterflowLayout.swift
//  WaterFlow
//
//  Created by 陈威杰 on 2023/4/24.
//

import UIKit


@objc
public protocol WaterflowLayoutDelegate: NSObjectProtocol {
    
    /// 返回 Item 的高度
    func waterflowLayout(_ layout: WaterflowLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat
    
    /// 返回布局列数，default is 2
    @objc optional func columnOfWaterflowLayout(_ layout: WaterflowLayout) -> Int
    
    /// 返回每列的间隔间距，default is 5
    @objc optional func columnSpacingForWaterflowLayout(_ layout: WaterflowLayout) -> CGFloat
    
    /// 返回每行的间隔间距，default is 5
    @objc optional func rowSpacingForWaterflowLayout(_ layout: WaterflowLayout) -> CGFloat
    
    /// 返回组头大小,跟 UICollectionViewFlowLayout 流水布局的 referenceSizeForHeaderInSection 方法一样的效果
    /// 即宽度没有用，只需要高度即可，如 CGSize(width: 0, height: 50)，
    /// 内部计算宽度为 collectionView.width - collectionView.contentInset.left - collectionView.contentInset.right
    @objc optional func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: WaterflowLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    
    /// 返回组尾大小,跟 UICollectionViewFlowLayout 流水布局的 referenceSizeForFooterInSection 方法一样的效果
    /// 即宽度没有用，只需要高度即可，如 CGSize(width: 0, height: 50)
    /// 内部计算宽度为 collectionView.width - collectionView.contentInset.left - collectionView.contentInset.right
    @objc optional func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: WaterflowLayout, referenceSizeForFooterInSection section: Int) -> CGSize
    
    /// 每组 Cell 四周的内边距，跟 UICollectionViewFlowLayout 流水布局的 insetForSectionAt 方法一样的效果
    @objc optional func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: WaterflowLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    
    /// 组头和组尾之间的间距，default is 0
    @objc optional func spacingBetweenHeaderAndFooter(in collectionView: UICollectionView, layout: WaterflowLayout) -> CGFloat

    
}


@objcMembers
open class WaterflowLayout: UICollectionViewLayout {
    
    public weak var delegate: WaterflowLayoutDelegate?
    
    /// 当前可滚动的最大高度
    public private(set) var maxContentHeight: CGFloat = 0
    /// 所有布局属性
    public private(set) var layoutAttributes: [UICollectionViewLayoutAttributes] = []
    /// 存放每一列的最新高度(含组头组尾高度)
    private(set) lazy var columnHeights: [CGFloat] = []
    
    
    open override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        
        // 清空数据
        layoutAttributes.removeAll()
        maxContentHeight = collectionView.contentInset.top
        columnHeights = Array(repeating: collectionView.contentInset.top, count: columnOfWaterflowLayout)
        
        
        // 获取组数，创建对应布局属性
        let numberOfSections = collectionView.numberOfSections
        for section in 0 ..< numberOfSections {
            
            // 添加当前组 header 类型的 layoutAttributes
            let headerIndexPath = IndexPath(row: 0, section: section)
            let headerAttribute = layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: headerIndexPath)

            if let headerAttribute = headerAttribute {
                layoutAttributes.append(headerAttribute)
                // 更新最大高度 => header 最大 Y 值 + 该组的上边距
                maxContentHeight = CGRectGetMaxY(headerAttribute.frame) + insetForSectionAt(headerIndexPath.section).top
                columnHeights = columnHeights.map { _ in maxContentHeight }
            }

            // 添加当前组的 cell layoutAttributes
            let numberOfItems = collectionView.numberOfItems(inSection: section)
            for row in 0 ..< numberOfItems {
                let indexPath: IndexPath = .init(row: row, section: section)
                let attributes = layoutAttributesForItem(at: indexPath)
                guard let attributes else { return }
                layoutAttributes.append(attributes)
                
            }

            // 添加当前组 footer 类型的 layoutAttributes
            let footerIndexPath = IndexPath(row: 0, section: section)
            let footerAttribute = layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, at: footerIndexPath)
            if let footerAttribute = footerAttribute {
                layoutAttributes.append(footerAttribute)
                // 更新最大高度
                maxContentHeight = CGRectGetMaxY(footerAttribute.frame)
                columnHeights = columnHeights.map { _ in maxContentHeight }
            }

        }
        
    }
    
    
    
    /// 返回创建的组头或组尾属性
    open override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        
        guard let collectionView else { return nil }
        
        let collectionWidth = collectionView.frame.width
        let supplementaryViewWidth = collectionWidth - collectionView.contentInset.left - collectionView.contentInset.right
        
        let attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: elementKind, with: indexPath)
        
        let headerHeight = heightForHeaderAt(indexPath.section)
        let footerHeight = heightForFooterAt(indexPath.section)
        
        if elementKind == UICollectionView.elementKindSectionHeader {
            
            var headerY: CGFloat = 0
            if indexPath.section != 0 { // 不是第一组的情况
                headerY = maxContentHeight + spacingBetweenHeaderAndFooter
            }
            
            attributes.frame = .init(x: 0, y: headerY, width: supplementaryViewWidth, height: headerHeight)
            
        } else {
            /// 当前最大高度 + 该组的 bottom 内边距
            let footerY = maxContentHeight + insetForSectionAt(indexPath.section).bottom
            attributes.frame = .init(x: 0, y: footerY, width: supplementaryViewWidth, height: footerHeight)
            
        }
        
        return attributes
        
    }
    
    /// 返回创建的 Cell 布局属性
    open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let collectionView else { return nil }
        
        // 创建布局属性
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        
        let collectionWidth = collectionView.frame.width
        let leftTotalEdge = collectionView.contentInset.left + insetForSectionAt(indexPath.section).left
        let rightTotalEdge = collectionView.contentInset.right + insetForSectionAt(indexPath.section).right
        let columnTotalSpacing = CGFloat((columnOfWaterflowLayout - 1)) * columnSpacingForWaterflowLayout
        
        let cellWidth = (collectionWidth - leftTotalEdge - rightTotalEdge - columnTotalSpacing) / CGFloat(columnOfWaterflowLayout)
        
        
        // 找出最短的一列
        var minColumnHeight = columnHeights.first.map { $0 } ?? 0
        // 最短列的所在索引
        var destColumn = 0
        for (i, height) in columnHeights.enumerated() {
            if i == 0 { continue }
            if minColumnHeight > height {
                minColumnHeight = height
                destColumn = i
            }
        }
        
        
        let cellX = insetForSectionAt(indexPath.section).left + (columnSpacingForWaterflowLayout + cellWidth) * CGFloat(destColumn)
        var cellY = minColumnHeight
        
        if indexPath.item >= columnOfWaterflowLayout {
            cellY += rowSpacingForWaterflowLayout
        }
        
        attributes.frame = .init(x: cellX, y: cellY, width: cellWidth, height: heightForItemAtIndexPath(indexPath, itemWidth: cellWidth))

        
        // 更新当前最短列最新的高度
        columnHeights[destColumn] = CGRectGetMaxY(attributes.frame)
        
        // 更新当前最大高度
        maxContentHeight = columnHeights.max() ?? 0
        
        return attributes
    }
    
    
    /// 返回某个显示范围内的布局属性
    open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        // 可直接返回该数组
        // layoutAttributes
        
        // 查找当前显示范围应该显示的 cell 属性
        var visibleAttributesArray = [UICollectionViewLayoutAttributes]()
        for attribute in layoutAttributes {
            // intersects 相交的意思，则查找当前显示范围内应该显示出来的 cell 属性
            if attribute.frame.intersects(rect) {
                visibleAttributesArray.append(attribute)
            }
        }
        
        return visibleAttributesArray
    }
    
    
    /// 返回可滚动范围
    open override var collectionViewContentSize: CGSize { CGSize(width: 0, height: maxContentHeight) }

}



private extension WaterflowLayout {
    
    var columnOfWaterflowLayout: Int {
        delegate?.columnOfWaterflowLayout?(self) ?? 2
    }
    
    var columnSpacingForWaterflowLayout: CGFloat {
        delegate?.columnSpacingForWaterflowLayout?(self) ?? 5
    }
    
    var rowSpacingForWaterflowLayout: CGFloat {
        delegate?.rowSpacingForWaterflowLayout?(self) ?? 5
    }
    
    var spacingBetweenHeaderAndFooter: CGFloat {
        guard let collectionView else { return 0 }
        return delegate?.spacingBetweenHeaderAndFooter?(in: collectionView, layout: self) ?? 0
    }
    
    func insetForSectionAt(_ section: Int) -> UIEdgeInsets {
        guard let collectionView else { return .zero }
        return delegate?.collectionView?(collectionView, layout: self, insetForSectionAt: section) ?? .zero
    }
    
    func heightForItemAtIndexPath(_ indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        delegate?.waterflowLayout(self, heightForItemAt: indexPath, itemWidth: itemWidth) ?? 0
    }
    
    func heightForHeaderAt(_ section: Int) -> CGFloat {
        guard let collectionView else { return 0 }
        return delegate?.collectionView?(collectionView, layout: self, referenceSizeForHeaderInSection: section).height ?? 0
    }

    func heightForFooterAt(_ section: Int) -> CGFloat {
        guard let collectionView else { return 0 }
        return delegate?.collectionView?(collectionView, layout: self, referenceSizeForFooterInSection: section).height ?? 0
    }
    
    
}
