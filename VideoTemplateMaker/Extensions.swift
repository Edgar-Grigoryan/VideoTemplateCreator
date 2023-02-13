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

//let numberOfComponentsPerARBGPixel = 4
//let numberOfComponentsPerRGBAPixel = 4
//let numberOfComponentsPerGrayPixel = 3
//
//extension CGContext {
//    class func ARGBBitmapContext(width: Int, height: Int, withAlpha: Bool) -> CGContext? {
//        let alphaInfo = withAlpha ? CGImageAlphaInfo.premultipliedFirst : CGImageAlphaInfo.noneSkipFirst
//        let bmContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * numberOfComponentsPerARBGPixel, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: alphaInfo.rawValue)
//        return bmContext
//    }
//
//    // MARK: - RGBA bitmap context
//    class func RGBABitmapContext(width: Int, height: Int, withAlpha: Bool) -> CGContext? {
//        let alphaInfo = withAlpha ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast
//        let bmContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * numberOfComponentsPerRGBAPixel, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: alphaInfo.rawValue)
//        return bmContext
//    }
//
//    // MARK: - Gray bitmap context
//    class func GrayBitmapContext(width: Int, height: Int) -> CGContext? {
//        let bmContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * numberOfComponentsPerGrayPixel, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
//        return bmContext
//    }
//}

extension CVPixelBuffer {
    func cgImage() -> CGImage? {
        let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(self), space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        let ciContext = CIContext.init(cgContext: context)
        let ciImage = CIImage(cvImageBuffer: self)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}

extension CGImage {
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
    
//    func createMaskImage() -> CGImage? {
//        return CGImage(maskWidth: self.width, height: self.height, bitsPerComponent: self.bitsPerComponent, bitsPerPixel: self.bitsPerPixel, bytesPerRow: self.bytesPerRow, provider: self.dataProvider!, decode: nil, shouldInterpolate: false)
//    }
    
//    func masked(withImage maskImage: CGImage) -> CGImage? {
//        // Create an ARGB bitmap context
//        let originalWidth = self.width
//        let originalHeight = self.height
//
//        guard let bmContext = CGContext.ARGBBitmapContext(width: originalWidth, height: originalHeight, withAlpha: true) else {
//            return nil
//        }
//
//        // Image quality
//        bmContext.setShouldAntialias(true)
//        bmContext.setAllowsAntialiasing(true)
//        bmContext.interpolationQuality = .high
//
//        // Image mask
//        guard let mask = CGImage(maskWidth: maskImage.width, height: maskImage.height, bitsPerComponent: maskImage.bitsPerComponent, bitsPerPixel: maskImage.bitsPerPixel, bytesPerRow: maskImage.bytesPerRow, provider: maskImage.dataProvider!, decode: nil, shouldInterpolate: false) else {
//            return nil
//        }
//
//        // Draw the original image in the bitmap context
//        let r = CGRect(x: 0, y: 0, width: originalWidth, height: originalHeight)
//        bmContext.clip(to: r, mask: maskImage)
//        bmContext.draw(self, in: r)
//
//        // Get the CGImage object
//        guard let imageRefWithAlpha = bmContext.makeImage() else {
//            return nil
//        }
//
//        // Apply the mask
//        return imageRefWithAlpha.masking(mask)
//    }
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
    var documentDirectory: URL {
        return self.urls(for: .documentDirectory, in: .userDomainMask).first!        
    }
}
