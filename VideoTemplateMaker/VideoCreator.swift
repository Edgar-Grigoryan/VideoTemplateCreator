//
//  VideoCreator.swift
//  VideoTemplateMaker
//
//  Created by Edgar Grigoryan on 11.02.23.
//

import Foundation
import UIKit
import AVFoundation
import Photos
import AVKit
import AssetsLibrary

class VideoCreator {
    static func build(images: [UIImage], outputSize: CGSize) async throws -> URL {
        var photos = images
        let videoOutputURL = FileManager.default.documentDirectory.appending(component: "video.mp4")
        if FileManager.default.fileExists(atPath: videoOutputURL.path) {
            try FileManager.default.removeItem(atPath: videoOutputURL.path)
        }

        let videoWriter = try AVAssetWriter(outputURL: videoOutputURL, fileType: .mp4)

        let outputSettings: [String : Any] = [
            AVVideoCodecKey : AVVideoCodecType.h264,
            AVVideoWidthKey : outputSize.width,
            AVVideoHeightKey : outputSize.height
        ]

        guard videoWriter.canApply(outputSettings: outputSettings, forMediaType: .video) else {
            throw NSError(domain: "something went wrong", code: 1)
        }

        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        let sourcePixelBufferAttributesDictionary: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: outputSize.width,
            kCVPixelBufferHeightKey as String: outputSize.height
        ]
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)

        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }

        guard videoWriter.startWriting() else { throw NSError(domain: "something went wrong", code: 2) }

        videoWriter.startSession(atSourceTime: .zero)
        guard pixelBufferAdaptor.pixelBufferPool != nil else { throw NSError(domain: "something went wrong", code: 3) }

        let fps: Int32 = 1
        let frameDuration = CMTime(value: 1, timescale: fps)

        var frameCount: Int64 = 0
        var appendSucceeded = true

        while (!photos.isEmpty) {
            if (videoWriterInput.isReadyForMoreMediaData) {
                let nextPhoto = photos.remove(at: 0)
                let lastFrameTime = CMTime(value: frameCount, timescale: fps)
                let presentationTime = frameCount == 0 ? lastFrameTime : (lastFrameTime + frameDuration)

                var pixelBuffer: CVPixelBuffer? = nil
                
                let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)

                if let pixelBuffer = pixelBuffer, status == 0 {
                    let managedPixelBuffer = pixelBuffer

                    CVPixelBufferLockBaseAddress(managedPixelBuffer, .readOnly)

                    let data = CVPixelBufferGetBaseAddress(managedPixelBuffer)
                    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                    let context = CGContext(data: data, width: Int(outputSize.width), height: Int(outputSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(managedPixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!

                    context.clear(CGRect(origin: .zero, size: outputSize))

                    let horizontalRatio = outputSize.width / nextPhoto.size.width
                    let verticalRatio = outputSize.height / nextPhoto.size.height
                    let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit

                    let newSize = CGSize(width: nextPhoto.size.width * aspectRatio, height: nextPhoto.size.height * aspectRatio)

                    let x = (newSize.width < outputSize.width) ? (outputSize.width - newSize.width) / 2 : 0
                    let y = (newSize.height < outputSize.height) ? (outputSize.height - newSize.height) / 2 : 0

                    context.draw(nextPhoto.cgImage!, in: CGRect(origin: CGPoint(x: x, y: y), size: newSize))

                    CVPixelBufferUnlockBaseAddress(managedPixelBuffer, .readOnly)

                    appendSucceeded = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                } else {
                    print("Failed to allocate pixel buffer")
                    appendSucceeded = false
                }
                frameCount += 1
            }
            if !appendSucceeded {
                break
            }
        }
        videoWriterInput.markAsFinished()
        await videoWriter.finishWriting()
        
        return videoOutputURL
    }

    static func mergeVideoAndAudio(videoUrl: URL, audioUrl: URL, shouldFlipHorizontally: Bool = false) async throws -> URL {
        let mixComposition = AVMutableComposition()
        var mutableCompositionVideoTrack = [AVMutableCompositionTrack]()
        var mutableCompositionAudioTrack = [AVMutableCompositionTrack]()
        var mutableCompositionAudioOfVideoTrack = [AVMutableCompositionTrack]()
        
        //start merge
        
        let aVideoAsset = AVAsset(url: videoUrl)
        let aAudioAsset = AVAsset(url: audioUrl)
        
        guard let compositionAddVideo = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "something went wrong", code: 1)
        }
        
        guard let compositionAddAudio = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "something went wrong", code: 2)
        }
        
        guard let compositionAddAudioOfVideo = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "something went wrong", code: 3)
        }
        
        let aVideoAssetTrack: AVAssetTrack = try await aVideoAsset.loadTracks(withMediaType: .video).first!
        let aAudioOfVideoAssetTrack: AVAssetTrack? = try await aVideoAsset.loadTracks(withMediaType: .audio).first
        let aAudioAssetTrack: AVAssetTrack = try await aAudioAsset.loadTracks(withMediaType: .audio).first!
        
        // Default must have tranformation
        compositionAddVideo.preferredTransform = try await aVideoAssetTrack.load(.preferredTransform)
        
        if shouldFlipHorizontally {
            // Flip video horizontally
            var frontalTransform: CGAffineTransform = CGAffineTransform(scaleX: -1.0, y: 1.0)
            
            frontalTransform = try await frontalTransform.translatedBy(x: -aVideoAssetTrack.load(.naturalSize).width, y: 0.0)
            frontalTransform = try await frontalTransform.translatedBy(x: 0.0, y: -aVideoAssetTrack.load(.naturalSize).width)
            compositionAddVideo.preferredTransform = frontalTransform
        }
        
        mutableCompositionVideoTrack.append(compositionAddVideo)
        mutableCompositionAudioTrack.append(compositionAddAudio)
        mutableCompositionAudioOfVideoTrack.append(compositionAddAudioOfVideo)

        try await mutableCompositionVideoTrack.first!.insertTimeRange(CMTimeRange(start: .zero, duration: aVideoAssetTrack.load(.timeRange).duration), of: aVideoAssetTrack, at: .zero)
        
        //In my case my audio file is longer then video file so i took videoAsset duration
        //instead of audioAsset duration
        try await mutableCompositionAudioTrack.first!.insertTimeRange(CMTimeRange(start: .zero, duration: aVideoAssetTrack.load(.timeRange).duration), of: aAudioAssetTrack, at: .zero)
        
        // adding audio (of the video if exists) asset to the final composition
        if let aAudioOfVideoAssetTrack = aAudioOfVideoAssetTrack {
            try await mutableCompositionAudioOfVideoTrack.first!.insertTimeRange(CMTimeRange(start: .zero, duration: aVideoAssetTrack.load(.timeRange).duration), of: aAudioOfVideoAssetTrack, at: .zero)
        }
        
        // Exporting
        let savePathUrl = FileManager.default.documentDirectory.appending(component: "videoWithAudio.mp4")
        // delete old video
        if FileManager.default.fileExists(atPath: savePathUrl.path) {
            try FileManager.default.removeItem(atPath: savePathUrl.path)
        }
        
        let assetExport: AVAssetExportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)!
        assetExport.outputFileType = .mp4
        assetExport.outputURL = savePathUrl
        assetExport.shouldOptimizeForNetworkUse = true
        
        await assetExport.export()
        
        if let error = assetExport.error {
            throw error
        }

        return savePathUrl
    }
}
