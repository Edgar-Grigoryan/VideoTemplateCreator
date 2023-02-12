//
//  ViewController.swift
//  VideoTemplateMaker
//
//  Created by Edgar Grigoryan on 11.02.23.
//

import UIKit
import AVKit
import Photos

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let size = CGSize(width: 1024, height: 1024)
//        VideoCreator.build(myPhotos: self.fetchAssetsPhotos(), outputSize: size)
    }

    func fetchLibraryPhotos(targetSize: CGSize, completion: @escaping ([UIImage]) -> Void) {
        PHPhotoLibrary.requestAuthorization { (status) in
            switch status {
            case .authorized:
                let assets = PHAsset.fetchAssets(with: .image, options: nil)
                var images = [UIImage]()
                assets.enumerateObjects { asset, index, stop in
                    let options = PHImageRequestOptions()
                    options.isSynchronous = true
                    options.deliveryMode = .highQualityFormat

                    PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .default, options: options) { image, info in
                        images.append(image!)
                    }
                }
                completion(images)
            default:
                fatalError("Cannot fetch library photos.")
            }
        }
    }

    func fetchAssetsPhotos() -> [UIImage] {
        var images = [UIImage]()
        for i in 1...8 {
            images.append(UIImage(named: "image\(i)")!)
        }
        return images
    }

    func saveVideoToLibrary(videoURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            // Return if unauthorized
            guard status == .authorized else {
                print("Error saving video: unauthorized access")
                return
            }

            // If here, save video to library
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }) { success, error in
                if !success {
                    print("Error saving video: \(error!)")
                }
            }
        }
    }

//    func aaaaa() {
//        let imageSize: CGFloat = 1024
//        let size = CGSize(width: imageSize, height: imageSize)
//        let originalImage = self.fetchAssetsPhotos()[0]
//        let rect = CGRect(origin: CGPoint(x: originalImage.size.width / 2, y: CGFloat(Int(originalImage.size.height / 2.0))), size: .zero).insetBy(dx: -imageSize / 2, dy: -imageSize / 2)
//        let image = originalImage.cgImage!.cropping(to: rect)!
//        let mask = originalImage.cgImage!.generateMask()!
//        
//        let photo = UIImage(cgImage: mask)
//        let k = photo.maskWithColor(color: .clear)
//        print("ssss")
//    }
}
