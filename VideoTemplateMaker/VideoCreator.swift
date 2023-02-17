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
        let sourcePixelBufferAttributes: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: outputSize.width,
            kCVPixelBufferHeightKey as String: outputSize.height
        ]
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)

        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }

        guard videoWriter.startWriting() else { throw NSError(domain: "something went wrong", code: 2) }

        videoWriter.startSession(atSourceTime: .zero)
        guard pixelBufferAdaptor.pixelBufferPool != nil else { throw NSError(domain: "something went wrong", code: 3) }

        let fps: Int32 = 1
        let frameDuration = CMTime(value: 1, timescale: fps)

        var frameCount: Int64 = 0

        while (!photos.isEmpty) {
            if (videoWriterInput.isReadyForMoreMediaData) {
                let photo = photos.remove(at: 0)
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
                    context.draw(photo.cgImage!, in: photo.size.fitted(in: outputSize))

                    CVPixelBufferUnlockBaseAddress(managedPixelBuffer, .readOnly)

                    pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                } else {
                    throw NSError(domain: "something went wrong", code: 4)
                }
                frameCount += 1
            }
        }
        videoWriterInput.markAsFinished()
        await videoWriter.finishWriting()
        
        return videoOutputURL
    }

    static func mergeVideoAndAudio(videoUrl: URL, audioUrl: URL) async throws -> URL {
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
        let aAudioAssetTrack: AVAssetTrack = try await aAudioAsset.loadTracks(withMediaType: .audio).first!
        
        // Default must have tranformation
        compositionAddVideo.preferredTransform = try await aVideoAssetTrack.load(.preferredTransform)
        
        mutableCompositionVideoTrack.append(compositionAddVideo)
        mutableCompositionAudioTrack.append(compositionAddAudio)
        mutableCompositionAudioOfVideoTrack.append(compositionAddAudioOfVideo)

        try await mutableCompositionVideoTrack.first!.insertTimeRange(CMTimeRange(start: .zero, duration: aVideoAssetTrack.load(.timeRange).duration), of: aVideoAssetTrack, at: .zero)
        
        //In my case my audio file is longer then video file so i took videoAsset duration
        //instead of audioAsset duration
        try await mutableCompositionAudioTrack.first!.insertTimeRange(CMTimeRange(start: .zero, duration: aVideoAssetTrack.load(.timeRange).duration), of: aAudioAssetTrack, at: .zero)
        
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
