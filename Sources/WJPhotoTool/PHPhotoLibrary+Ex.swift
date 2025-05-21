 //
//  PHPhotoLibrary+Rx.swift
//  WaterFlow
//
//  Created by Jie on 2023/7/25.
//

import Foundation
import Photos

public extension PHPhotoLibrary {
    
    @objc
    static var isAuthorized: Bool {
        if #available(iOS 14.0, *) {
            let status = authorizationStatus(for: .readWrite)
            return status == .authorized || status == .limited
        } else {
            return authorizationStatus() == .authorized
        }
    }
    
    
    
    @objc
    static func performAuthorized(_ changeBlock: @escaping () -> Void, noPermission: ((PHAuthorizationStatus) -> Void)? = nil) {
        
        if PHPhotoLibrary.isAuthorized {
            changeBlock()
        } else {
            if #available(iOS 14.0, *) {
                requestAuthorization(for: .readWrite) {
                    if $0 == .authorized || $0 == .limited {
                        changeBlock()
                    } else {
                        noPermission?($0)
                    }
                }
            } else {
                requestAuthorization {
                    if $0 == .authorized {
                        changeBlock()
                    } else {
                        noPermission?($0)
                    }
                }
            }
        }
    
    }
   
    
}
