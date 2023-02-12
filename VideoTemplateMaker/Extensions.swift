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

let numberOfComponentsPerARBGPixel = 4
let numberOfComponentsPerRGBAPixel = 4
let numberOfComponentsPerGrayPixel = 3

extension CGContext {
    class func ARGBBitmapContext(width: Int, height: Int, withAlpha: Bool) -> CGContext? {
        let alphaInfo = withAlpha ? CGImageAlphaInfo.premultipliedFirst : CGImageAlphaInfo.noneSkipFirst
        let bmContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * numberOfComponentsPerARBGPixel, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: alphaInfo.rawValue)
        return bmContext
    }

    // MARK: - RGBA bitmap context
    class func RGBABitmapContext(width: Int, height: Int, withAlpha: Bool) -> CGContext? {
        let alphaInfo = withAlpha ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast
        let bmContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * numberOfComponentsPerRGBAPixel, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: alphaInfo.rawValue)
        return bmContext
    }

    // MARK: - Gray bitmap context
    class func GrayBitmapContext(width: Int, height: Int) -> CGContext? {
        let bmContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * numberOfComponentsPerGrayPixel, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        return bmContext
    }
}

extension CVPixelBuffer {
    func cgImage() -> CGImage? {
        let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(self), space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        let ciContext = CIContext.init(cgContext: context)
        let ciImage = CIImage(cvImageBuffer: self)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}

extension CGImage {
    func generateMask() -> CGImage? {
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
    
    func createMaskImage() -> CGImage? {
        return CGImage(maskWidth: self.width, height: self.height, bitsPerComponent: self.bitsPerComponent, bitsPerPixel: self.bitsPerPixel, bytesPerRow: self.bytesPerRow, provider: self.dataProvider!, decode: nil, shouldInterpolate: false)
    }
    
    func masked(withImage maskImage: CGImage) -> CGImage? {
        // Create an ARGB bitmap context
        let originalWidth = self.width
        let originalHeight = self.height

        guard let bmContext = CGContext.ARGBBitmapContext(width: originalWidth, height: originalHeight, withAlpha: true) else {
            return nil
        }

        // Image quality
        bmContext.setShouldAntialias(true)
        bmContext.setAllowsAntialiasing(true)
        bmContext.interpolationQuality = .high

        // Image mask
        guard let mask = CGImage(maskWidth: maskImage.width, height: maskImage.height, bitsPerComponent: maskImage.bitsPerComponent, bitsPerPixel: maskImage.bitsPerPixel, bytesPerRow: maskImage.bytesPerRow, provider: maskImage.dataProvider!, decode: nil, shouldInterpolate: false) else {
            return nil
        }

        // Draw the original image in the bitmap context
        let r = CGRect(x: 0, y: 0, width: originalWidth, height: originalHeight)
        bmContext.clip(to: r, mask: maskImage)
        bmContext.draw(self, in: r)

        // Get the CGImage object
        guard let imageRefWithAlpha = bmContext.makeImage() else {
            return nil
        }

        // Apply the mask
        return imageRefWithAlpha.masking(mask)
    }
}
