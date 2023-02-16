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
            VideoCreator.build(images: images, outputSize: size) { error, url in
                let audioURL = Bundle.main.url(forResource: "music", withExtension: "aac")!
                Task {
                    do {
                        let videoURL = try await VideoCreator.mergeVideoAndAudio(videoUrl: url!, audioUrl: audioURL)
                        print("ALL TASKS ARE FINISHED!!!!! URL: \(videoURL)")
                    } catch (let error) {
                        print(error.localizedDescription)
                    }
                }
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

    func generateVideoTemplateImages() -> [UIImage] {
        var resultImages = [UIImage]()

        let fetchedImages = self.fetchAssetsPhotos()
        resultImages.append(fetchedImages[0])
        
        for i in 1..<fetchedImages.count {
            let originalImage = fetchedImages[i]
            let object = originalImage.generateObject()!
            let result = UIImage.mergedImages(images: [fetchedImages[i - 1], object])!
            resultImages.append(result)
            resultImages.append(originalImage)
        }
        
        return resultImages
    }
}
