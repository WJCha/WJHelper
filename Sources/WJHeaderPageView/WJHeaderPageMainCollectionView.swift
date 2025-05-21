//
//  WJHeaderPageMainCollectionView.swift
//  FudaiShenghuo
//
//  Created by Jie on 2025/3/26.
//  Copyright © 2025 FengQing. All rights reserved.
//

import UIKit

@MainActor
@objc
public protocol WJHeaderPageMainCollectionViewDelegate: AnyObject {
    @objc optional
    func mainCollectionViewGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
}

@objcMembers
public class WJHeaderPageMainCollectionView: UICollectionView, UIGestureRecognizerDelegate {
    
    weak var gestureDelegate: WJHeaderPageMainCollectionViewDelegate?

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureDelegate?.mainCollectionViewGestureRecognizer?(gestureRecognizer, shouldRecognizeSimultaneouslyWith: otherGestureRecognizer) ?? false
        
    }

}
