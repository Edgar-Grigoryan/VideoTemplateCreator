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

class VideoCreator {
    private static func saveVideoToLibrary(videoURL: URL) {
        print(videoURL)
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                print("Error saving video: unauthorized access")
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }) { success, error in
                if !success {
                    print("Error saving video: \(error!)")
                } else {
                    print("VIDEO SAVED IN LIBRARY!!!")
                }
            }
        }
    }

    static func build(myPhotos: [UIImage], outputSize: CGSize, completion: @escaping (_ error: Error?, _ url: URL?) -> Void) {
        var photos = myPhotos
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentDirectory: URL = urls.first else {
            completion(NSError(domain: "documentDir Error", code: 1), nil)
            return
        }
        
        let videoOutputURL = documentDirectory.appending(component: "OutputVideo.mp4")
        if FileManager.default.fileExists(atPath: videoOutputURL.path) {
            do {
                try FileManager.default.removeItem(atPath: videoOutputURL.path)
            } catch {
                completion(NSError(domain: "Unable to delete file: \(error) : \(#function).", code: 2), nil)
                return
            }
        }

        guard let videoWriter = try? AVAssetWriter(outputURL: videoOutputURL, fileType: AVFileType.mp4) else {
            completion(NSError(domain: "AVAssetWriter error", code: 3), nil)
            return
        }

        let outputSettings: [String : Any] = [
            AVVideoCodecKey : AVVideoCodecType.h264,
            AVVideoWidthKey : NSNumber(value: Float(outputSize.width)),
            AVVideoHeightKey : NSNumber(value: Float(outputSize.height))
        ]

        guard videoWriter.canApply(outputSettings: outputSettings, forMediaType: AVMediaType.video) else {
            completion(NSError(domain: "Negative : Can't apply the Output settings...", code: 4), nil)
            return
        }

        let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        let sourcePixelBufferAttributesDictionary = [
            kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: NSNumber(value: Float(outputSize.width)),
            kCVPixelBufferHeightKey as String: NSNumber(value: Float(outputSize.height))
        ]
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)

        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }

        if videoWriter.startWriting() {
            videoWriter.startSession(atSourceTime: .zero)
            assert(pixelBufferAdaptor.pixelBufferPool != nil)

            let media_queue = DispatchQueue(label: "mediaInputQueue")

            videoWriterInput.requestMediaDataWhenReady(on: media_queue, using: { () -> Void in
                let fps: Int32 = 1
                let frameDuration = CMTimeMake(value: 1, timescale: fps)

                var frameCount: Int64 = 0
                var appendSucceeded = true

                while (!photos.isEmpty) {
                    if (videoWriterInput.isReadyForMoreMediaData) {
                        let nextPhoto = photos.remove(at: 0)
                        let lastFrameTime = CMTimeMake(value: frameCount, timescale: fps)
                        let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)

                        var pixelBuffer: CVPixelBuffer? = nil
                        let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)

                        if let pixelBuffer = pixelBuffer, status == 0 {
                            let managedPixelBuffer = pixelBuffer

                            CVPixelBufferLockBaseAddress(managedPixelBuffer, .readOnly)

                            let data = CVPixelBufferGetBaseAddress(managedPixelBuffer)
                            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                            let context = CGContext(data: data, width: Int(outputSize.width), height: Int(outputSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(managedPixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!

                            context.clear(CGRectMake(0, 0, CGFloat(outputSize.width), CGFloat(outputSize.height)))

                            let horizontalRatio = CGFloat(outputSize.width) / nextPhoto.size.width
                            let verticalRatio = CGFloat(outputSize.height) / nextPhoto.size.height
                            let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit

                            let newSize:CGSize = CGSizeMake(nextPhoto.size.width * aspectRatio, nextPhoto.size.height * aspectRatio)

                            let x = newSize.width < outputSize.width ? (outputSize.width - newSize.width) / 2 : 0
                            let y = newSize.height < outputSize.height ? (outputSize.height - newSize.height) / 2 : 0

                            context.draw(nextPhoto.cgImage!, in: CGRectMake(x, y, newSize.width, newSize.height))

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
                videoWriter.finishWriting { () -> Void in
                    print("Video Creation FINISHED!!!")
                    completion(nil, videoOutputURL)
                }
            })
        }
    }
}

//extension VideoCreator {
//    static func mergeVideoAndAudio(videoUrl: URL, audioUrl: URL, shouldFlipHorizontally: Bool = false, completion: @escaping (_ error: Error?, _ url: URL?) -> Void) {
//
//               let mixComposition = AVMutableComposition()
//               var mutableCompositionVideoTrack = [AVMutableCompositionTrack]()
//               var mutableCompositionAudioTrack = [AVMutableCompositionTrack]()
//               var mutableCompositionAudioOfVideoTrack = [AVMutableCompositionTrack]()
//
//               //start merge
//
//               let aVideoAsset = AVAsset(url: videoUrl)
//               let aAudioAsset = AVAsset(url: audioUrl)
//
//               let compositionAddVideo = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo,
//                                                                              preferredTrackID: kCMPersistentTrackID_Invalid)
//
//               let compositionAddAudio = mixComposition.addMutableTrack(withMediaType: AVMediaTypeAudio,
//                                                                            preferredTrackID: kCMPersistentTrackID_Invalid)
//
//               let compositionAddAudioOfVideo = mixComposition.addMutableTrack(withMediaType: AVMediaTypeAudio,
//                                                                                   preferredTrackID: kCMPersistentTrackID_Invalid)
//
//               let aVideoAssetTrack: AVAssetTrack = aVideoAsset.tracks(withMediaType: AVMediaTypeVideo)[0]
//               let aAudioOfVideoAssetTrack: AVAssetTrack? = aVideoAsset.tracks(withMediaType: AVMediaTypeAudio).first
//               let aAudioAssetTrack: AVAssetTrack = aAudioAsset.tracks(withMediaType: AVMediaTypeAudio)[0]
//
//               // Default must have tranformation
//               compositionAddVideo.preferredTransform = aVideoAssetTrack.preferredTransform
//
//               if shouldFlipHorizontally {
//                   // Flip video horizontally
//                   var frontalTransform: CGAffineTransform = CGAffineTransform(scaleX: -1.0, y: 1.0)
//                   frontalTransform = frontalTransform.translatedBy(x: -aVideoAssetTrack.naturalSize.width, y: 0.0)
//                   frontalTransform = frontalTransform.translatedBy(x: 0.0, y: -aVideoAssetTrack.naturalSize.width)
//                   compositionAddVideo.preferredTransform = frontalTransform
//               }
//
//               mutableCompositionVideoTrack.append(compositionAddVideo)
//               mutableCompositionAudioTrack.append(compositionAddAudio)
//               mutableCompositionAudioOfVideoTrack.append(compositionAddAudioOfVideo)
//
//               do {
//                   try mutableCompositionVideoTrack[0].insertTimeRange(CMTimeRangeMake(kCMTimeZero,
//                                                                                       aVideoAssetTrack.timeRange.duration),
//                                                                       of: aVideoAssetTrack,
//                                                                       at: kCMTimeZero)
//
//                   //In my case my audio file is longer then video file so i took videoAsset duration
//                   //instead of audioAsset duration
//                   try mutableCompositionAudioTrack[0].insertTimeRange(CMTimeRangeMake(kCMTimeZero,
//                                                                                       aVideoAssetTrack.timeRange.duration),
//                                                                       of: aAudioAssetTrack,
//                                                                       at: kCMTimeZero)
//
//                   // adding audio (of the video if exists) asset to the final composition
//                   if let aAudioOfVideoAssetTrack = aAudioOfVideoAssetTrack {
//                       try mutableCompositionAudioOfVideoTrack[0].insertTimeRange(CMTimeRangeMake(kCMTimeZero,
//                                                                                                  aVideoAssetTrack.timeRange.duration),
//                                                                                  of: aAudioOfVideoAssetTrack,
//                                                                                  at: kCMTimeZero)
//                   }
//               } catch {
//                   print(error.localizedDescription)
//               }
//
//               // Exporting
//               let savePathUrl: URL = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/newVideo.mp4")
//               do { // delete old video
//                   try FileManager.default.removeItem(at: savePathUrl)
//               } catch { print(error.localizedDescription) }
//
//               let assetExport: AVAssetExportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)!
//               assetExport.outputFileType = AVFileTypeMPEG4
//               assetExport.outputURL = savePathUrl
//               assetExport.shouldOptimizeForNetworkUse = true
//
//               assetExport.exportAsynchronously { () -> Void in
//                   switch assetExport.status {
//                   case AVAssetExportSessionStatus.completed:
//                       print("success")
//                       completion(nil, savePathUrl)
//                   case AVAssetExportSessionStatus.failed:
//                       print("failed \(assetExport.error?.localizedDescription ?? "error nil")")
//                       completion(assetExport.error, nil)
//                   case AVAssetExportSessionStatus.cancelled:
//                       print("cancelled \(assetExport.error?.localizedDescription ?? "error nil")")
//                       completion(assetExport.error, nil)
//                   default:
//                       print("complete")
//                       completion(assetExport.error, nil)
//                   }
//               }
//
//           }
//}
