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
        Task {
            let size = CGSize(width: 1024, height: 1024)
            let images = self.generateVideoTemplateImages()
            do {
                let videoURL = try await VideoCreator.build(images: images, outputSize: size)
                let audioURL = Bundle.main.url(forResource: "music", withExtension: "aac")!
                let videoWithAudioURL = try await VideoCreator.mergeVideoAndAudio(videoUrl: videoURL, audioUrl: audioURL)
            } catch (let error) {
                print(error.localizedDescription)
            }
        }
    }

    private func fetchAssetsPhotos() -> [UIImage] {
        var images = [UIImage]()
        for i in 1...8 {
            autoreleasepool {
                let image = UIImage(named: "image\(i)")!
                images.append(image)
            }
        }
        return images
    }

    private func generateVideoTemplateImages() -> [UIImage] {
        var resultImages = [UIImage]()

        let fetchedImages = self.fetchAssetsPhotos()
        resultImages.append(fetchedImages[0])
        
        for i in 1..<fetchedImages.count {
            autoreleasepool {
                let originalImage = fetchedImages[i]
                let object = originalImage.generateObject()!
                let result = UIImage.mergedImages(images: [fetchedImages[i - 1], object])!
                resultImages.append(result)
                resultImages.append(originalImage)
            }
        }
        
        return resultImages
    }
}
