//
//  Extensions.swift
//  VideoTemplateMaker
//
//  Created by Edgar Grigoryan on 11.02.23.
//

import Foundation
import CoreVideo
import CoreImage
import CoreML
import UIKit

extension CVPixelBuffer {
    // Creates CGImage from CVPixelBuffer
    func cgImage() -> CGImage? {
        let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(self), space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        let ciContext = CIContext.init(cgContext: context)
        let ciImage = CIImage(cvImageBuffer: self)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}

extension CGImage {
    // Geneates an image from givent CGImage with White object and Black background
    func generateGrayScaleMask() -> CGImage? {
        var result: CGImage?
        do {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .cpuAndGPU
            let model = try segmentation_8bit(configuration: configuration)
            let input = try segmentation_8bitInput(imgWith: self)
            let output = try model.prediction(input: input).var_2274
            result = output.cgImage()
        } catch (let err) {
            print(err)
        }
        return result
    }
}

extension UIImage {
    func maskWithColor(color: UIColor) -> UIImage? {
        let maskingColors: [CGFloat] = [0, 130, 0, 130, 0, 130] // tones of black
        let bounds = CGRect(origin: .zero, size: self.size)

        let maskImage = self.cgImage!
        var returnImage: UIImage?

        // make sure image has no alpha channel
        let rFormat = UIGraphicsImageRendererFormat()
        rFormat.opaque = true
        let renderer = UIGraphicsImageRenderer(size: self.size, format: rFormat)
        let noAlphaImage = renderer.image {
            (context) in
            self.draw(at: .zero)
        }

        let noAlphaCGRef = noAlphaImage.cgImage

        if let imgRefCopy = noAlphaCGRef?.copy(maskingColorComponents: maskingColors) {

            let rFormat = UIGraphicsImageRendererFormat()
            rFormat.opaque = false
            let renderer = UIGraphicsImageRenderer(size: self.size, format: rFormat)
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
    
    func generateMask() -> UIImage? {
        guard let grayScaleMask = self.cgImage?.generateGrayScaleMask() else { return nil }

        let grayScaleUIImage = UIImage(cgImage: grayScaleMask)
        return grayScaleUIImage.maskWithColor(color: .clear)
    }
    
    func generateObject() -> UIImage? {
        guard let mask = self.generateMask() else { return nil }
        
        let size = mask.size
        let bounds = CGRect(origin: .zero, size: size)
        
        UIGraphicsBeginImageContext(size)

        mask.draw(in: bounds)
        self.draw(in: bounds, blendMode: .sourceAtop, alpha: 1)
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()
        
        return resultImage
    }
    
    // Creates an image (UIImage) with merging an array of images
    static func mergedImages(images: [UIImage]) -> UIImage? {
        let size = images[0].size

        UIGraphicsBeginImageContext(size)
        let bounds = CGRect(origin: .zero, size: size)

        for image in images {
            image.draw(in: bounds)
        }

        let resultImage = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()
        
        return resultImage
    }
}

extension FileManager {
    // Returns the Document directory
    var documentDirectory: URL {
        return self.urls(for: .documentDirectory, in: .userDomainMask).first!        
    }
}
