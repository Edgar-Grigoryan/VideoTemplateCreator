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
//        self.aaaaa()
        VideoCreator.build(myPhotos: self.fetchAssetsPhotos(), outputSize: size)
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

    func aaaaa() {
        let originalImage = self.fetchAssetsPhotos()[0]
        let newmask = originalImage.cgImage!.generateMask()!
        
        let photo = UIImage(cgImage: newmask)
        let mask = photo.maskWithColor(color: .clear)!
        let size = mask.size
        let bounds = CGRect(origin: .zero, size: size)
        
        UIGraphicsBeginImageContext(size);
        mask.draw(in: bounds)
        originalImage.draw(in: bounds, blendMode: .sourceAtop, alpha: 1)
    
//        [uiimage drawAtPoint:CGPointZero blendMode:kCGBlendModeOverlay alpha:1.0];
//        [uiimage2 drawAtPoint:CGPointZero blendMode:kCGBlendModeOverlay alpha:1.0];

        let blendedImage = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext();
        
        print("ssss")
    }
}
