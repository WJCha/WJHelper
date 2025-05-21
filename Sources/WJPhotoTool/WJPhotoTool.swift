//
//  WJPhotoTool.swift
//  WaterFlow
//
//  Created by Jie on 2023/7/25.
//

import UIKit
import Photos
import PhotosUI

@objc public enum WJPhotoToolMediaType: Int {
    case image
    case video
}

@available(iOS 14, *)
@objcMembers
public class WJPhotoTool: NSObject {
    
    private var pickItemCompleteHandle: (([PHPickerResult]) -> Void)?
    private var imagePickerCompleteHandle: (([UIImagePickerController.InfoKey : Any]) -> Void)?
    
    @MainActor static let share: WJPhotoTool = .init()
    private override init() {
        super.init()
    }
    

}

@available(iOS 14, *)
@MainActor
public extension WJPhotoTool {
    
    @available(iOS 14, *)
    func pickItemFromAlbum(selectionLimit: Int = 1, filter: PHPickerFilter?, on viewController: UIViewController, complete: @escaping ([PHPickerResult]) -> Void) {
        pickItemCompleteHandle = complete
        
        var configuration = PHPickerConfiguration.init()
        // 可选择的资源数量，0表示不设限制，默认为1
        configuration.selectionLimit = selectionLimit
        /**
         configuration.filter = .images // 只显示图片（注：images 包含 livePhotos）
         configuration.filter = .any(of: [.livePhotos, .videos]) // 显示 Live Photos 和视频（注：livePhotos 不包含 images）
         */
        configuration.filter = filter
        // 如果要获取视频，最好设置该属性，避免系统对视频进行转码
        configuration.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        viewController.present(picker, animated: true)
        
    }
    
    func pickItemFromAlbum(
            sourceType: UIImagePickerController.SourceType = .savedPhotosAlbum,
            allowsEditing: Bool = false,
            mediaType: WJPhotoToolMediaType = .image,
            on viewController: UIViewController,
            complete: @escaping ([UIImagePickerController.InfoKey : Any]) -> Void
    ){
        
        if !UIImagePickerController.isSourceTypeAvailable(sourceType) {
            fatalError()
        }
        
        imagePickerCompleteHandle = complete
        let picker = UIImagePickerController.init()
        picker.sourceType = sourceType
        picker.allowsEditing = allowsEditing
        picker.mediaTypes = mediaType == .video ? [UTType.movie.identifier] : [UTType.image.identifier]
        picker.delegate = self
        viewController.present(picker, animated: true)
    }
    
}



@available(iOS 14, *)
public extension WJPhotoTool {
    
    
    /// 创建自定义相册（同步方法）
    /// - Parameter name: 相册名
    /// - Returns: 相册本地标识（localIdentifier）
    @discardableResult
    static func createAlbum(name: String) throws -> String {

        var localIdentifier: String = ""
        if let album = WJPhotoTool.fetchAlbum(name: name) {
            // 相册已存在
            localIdentifier = album.localIdentifier
        } else {
            // 创建相册
            try PHPhotoLibrary.shared().performChangesAndWait {
                localIdentifier = PHAssetCollectionChangeRequest
                                        .creationRequestForAssetCollection(withTitle: name)
                                        .placeholderForCreatedAssetCollection
                                        .localIdentifier
            }
        }

        return localIdentifier
    }
    
    

    
    /// 保存图片到自定义相册（同步方法）
    /// - Parameters:
    ///   - name: 自定义相册名称
    static func savePhoto(_ photo: UIImage, toAlbum name: String? = nil) throws {
        
        try WJPhotoTool.saveItemToAlbum(name) {
            PHAssetChangeRequest.creationRequestForAsset(from: photo).placeholderForCreatedAsset
        }
        
    }
    
    /// 保存图片到自定义相册（同步方法）
    /// - Parameters:
    ///   - name: 自定义相册名称
    static func savePhotoForFileURL(_ fileURL: URL, toAlbum name: String? = nil) throws {
        
        try WJPhotoTool.saveItemToAlbum(name) {
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)?.placeholderForCreatedAsset
        }
        
    }
    
    /// 保存视频到自定义相册
    /// - Parameters:
    ///   - name: 相册名
    ///   - fileUrl: 视频资源路径
    static func saveVideoForFileURL(_ fileURL: URL, toAlbum name: String? = nil) throws {
        try WJPhotoTool.saveItemToAlbum(name) {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)?.placeholderForCreatedAsset
        }
        
    }

    /// 获取某个相册
    /// - Parameter name: 相册名
    /// - Returns: 相册
    static func fetchAlbum(name: String) -> PHAssetCollection? {
//        let result = WJPhotoTool.fetchAllAlbums(name: name)
//        return result.first
        let result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        var collection: PHAssetCollection?
        result.enumerateObjects { item, idx, stop in
            if item.localizedTitle == name {
                collection = item
                stop.pointee = true
            }
        }
        return collection
    }
    
    
    /// 获取所有自定义相册
    static func fetchAllAlbums(name: String) -> [PHAssetCollection] {
        let result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        var collections: [PHAssetCollection] = []
        result.enumerateObjects { collection, idx, stop in
            if collection.localizedTitle == name {
                collections.append(collection)
            }
        }
        return collections
    }
}

@available(iOS 14, *)
private extension WJPhotoTool {
    /// 保存内容到自定义相册（同步方法）
    /// - Parameters:
    ///   - name: 自定义相册名称
    static func saveItemToAlbum(_ name: String? = nil, item: @escaping () -> PHObjectPlaceholder?) throws {
        
        if !PHPhotoLibrary.isAuthorized {
            print("没有相册访问权限")
            return
        }
        
        var placeholderForCreatedAsset: PHObjectPlaceholder?
        try PHPhotoLibrary.shared().performChangesAndWait {
            // 保存内容到【相机胶卷】
            placeholderForCreatedAsset = item()
            // placeholderForCreatedAsset = PHAssetChangeRequest.creationRequestForAsset(from: photo).placeholderForCreatedAsset
        }
        
        guard let placeholderForCreatedAsset, let name else { return }
        
        
        
        // 保存内容到【自定义相册】
        let albums = WJPhotoTool.fetchAllAlbums(name: name)
        var localIdentifiers = [String]()
        if albums.count == 0 {
            if let identifier = try? WJPhotoTool.createAlbum(name: name) {
                localIdentifiers.append(identifier)
            }
        } else {
            localIdentifiers = albums.map { $0.localIdentifier }
   
        }

        
        try PHPhotoLibrary.shared().performChangesAndWait {
            
            let results = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: localIdentifiers, options: nil)
            
            results.enumerateObjects { collection, idx, stop in
                let collectionChangeRequest = PHAssetCollectionChangeRequest(for: collection)
                collectionChangeRequest?.insertAssets([placeholderForCreatedAsset] as NSFastEnumeration, at: .init(integer: 0))
                
            }
            
            
        }
    }
    
    
}


@available(iOS 14.0, *)
extension WJPhotoTool: PHPickerViewControllerDelegate {
    
    /// 取消选择也会触发代理方法，会返回空的 results
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        // 回调结果集
        pickItemCompleteHandle?(results)
    }

}

@available(iOS 14.0, *)
public extension [PHPickerResult] {
    
    /// 从结果集中获取图片
    func imageForEach(_ complete: @escaping @Sendable (UIImage) -> Void) {
        forEach {
            // 遍历获取挑选的每个图片
            if $0.itemProvider.canLoadObject(ofClass: UIImage.self) {
                $0.itemProvider.loadObject(ofClass: UIImage.self) { data, error in
                    if let image = data as? UIImage {
                        DispatchQueue.main.async {
                            complete(image)
                        }
                    }
                }
            }
        }
    }
    
    /// 从结果集中获取视频链接
    func videoForEach(_ complete: @escaping @Sendable (URL) -> Void) {
        forEach {
            // 遍历获取挑选的每个视频
            if !($0.itemProvider.canLoadObject(ofClass: UIImage.self)) {
                $0.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    // 系统会将视频文件存放到 tmp 文件夹下
                    // 我们必须在这个回调结束前，将视频拷贝出去，一旦回调结束，系统就会把视频删掉
                    guard let url = url else { return }
                    let fileName = "\(url.lastPathComponent)"
                    let newUrl = URL(fileURLWithPath: NSTemporaryDirectory() + fileName)
                    try? FileManager.default.copyItem(at: url, to: newUrl)
                    DispatchQueue.main.async {
                        complete(newUrl)
                    }
                }
            }
        }
    }
    
}

@available(iOS 14.0, *)
extension WJPhotoTool: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        imagePickerCompleteHandle?(info)
    }

}

