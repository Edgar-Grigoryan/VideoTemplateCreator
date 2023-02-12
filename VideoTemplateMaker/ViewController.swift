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

extension UIImage {
    func maskWithColor(color: UIColor) -> UIImage? {
        let maskingColors: [CGFloat] = [0, 130, 0, 130, 0, 130]
        let bounds = CGRect(origin: .zero, size: size)

        let maskImage = cgImage!
        var returnImage: UIImage?

        // make sure image has no alpha channel
        let rFormat = UIGraphicsImageRendererFormat()
        rFormat.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: rFormat)
        let noAlphaImage = renderer.image {
            (context) in
            self.draw(at: .zero)
        }

        let noAlphaCGRef = noAlphaImage.cgImage

        if let imgRefCopy = noAlphaCGRef?.copy(maskingColorComponents: maskingColors) {

            let rFormat = UIGraphicsImageRendererFormat()
            rFormat.opaque = false
            let renderer = UIGraphicsImageRenderer(size: size, format: rFormat)
            returnImage = renderer.image {
                (context) in
                context.cgContext.scaleBy(x: 1, y: -1)
                context.cgContext.translateBy(x: 0, y: -bounds.size.height)
                context.cgContext.clip(to: bounds, mask: maskImage)
                context.cgContext.setFillColor(color.cgColor)
                context.cgContext.fill(bounds)
                context.cgContext.draw(imgRefCopy, in: bounds)
            }

        }
        return returnImage
    }

}
