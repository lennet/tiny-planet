//
//  VideoFilter.swift
//  TinyPlanet
//
//  Created by Leo Thomas on 16.05.17.
//  Copyright © 2017 Leonard Thomas. All rights reserved.
//

#if os(iOS) || os(tvOS)
    import UIKit
    typealias Image = UIImage
#elseif os(OSX)
    import AppKit
    typealias Image = NSImage
#endif

import AVFoundation

public enum FilterType {
    case none
    case tinyPlanet
    case rabbitHole
}

extension FilterType {
    
    public init(rawValue: Int) {
        switch rawValue {
        case 0:
            self = .none
            break
        case 1:
            self = .tinyPlanet
            break
        case 2:
            self = .rabbitHole
            break
        default:
            self = .none
            break
        }
    }
    
}

public class VideoFilter {
    
    public var type: FilterType = .none
    let context = CIContext()
    
    let output: AVPlayerItemVideoOutput
    let player: AVPlayer
    var newImageHandler: ((Image) -> ())?
    var onWrongImageRatio: (()->())?
    
    public init(url: URL) {
        output = AVPlayerItemVideoOutput(pixelBufferAttributes: nil)
        
        player = AVPlayer(url: url)
        player.isMuted = true
        player.currentItem?.add(output)
        
        #if os(iOS) || os(tvOS)
            let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidRefresh(link:)))
            displayLink.add(to: .current, forMode: .commonModes)
        #endif
        player.play()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil, queue: nil) { (notification) in
            self.player.seek(to: kCMTimeZero)
            self.player.play()
        }
    }
    
    #if os(iOS) || os(tvOS)
    @objc func displayLinkDidRefresh(link: CADisplayLink) {
    let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        updateFrame(time: itemTime)
    }
    #endif
    
    func updateFrame(time: CMTime) {
        if output.hasNewPixelBuffer(forItemTime: time) {
            var presentationItemTime = kCMTimeZero
            guard let imageBuffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: &presentationItemTime) else {
                return
            }
            
            if imageBuffer.width/imageBuffer.height != 2 {
                onWrongImageRatio?()
                onWrongImageRatio = nil
            }
            
            let outputBuffer: CVPixelBuffer
            switch type {
            case .none:
                outputBuffer = imageBuffer
                break
            case .tinyPlanet, .rabbitHole:
                outputBuffer = filter(imageBuffer: imageBuffer.copy(with: context) ?? imageBuffer)
            }
            display(imageBuffer: outputBuffer)
        }
    }
    
    func render(to url: URL, progess:((Float)->())?, completion:((Bool)->())?) {
        guard let asset = player.currentItem?.asset else {
            return
        }
        
        player.pause()
        
        let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
        
        let composition = AVMutableVideoComposition(asset: asset) { (request) in
            
            guard let buffer = request.sourceImage.pixelBuffer?.copy(with: self.context) else {
                request.finish(with: request.sourceImage, context: nil)
                return
            }
            
            DispatchQueue.main.async {
                progess?(export?.progress ?? 0)
            }
            
            let outputBuffer = self.filter(imageBuffer: buffer)
            let output = CIImage(cvPixelBuffer: outputBuffer)
            request.finish(with: output, context: nil)
        }
        composition.renderSize = CGSize(width: 1000, height: 1000)
        
        export?.outputFileType = AVFileTypeQuickTimeMovie
        
        export?.outputURL = url
        export?.videoComposition = composition
        
        export?.exportAsynchronously{
            completion?(true)
        }
        
    }
    
    func filter(imageBuffer: CVPixelBuffer) -> CVPixelBuffer {
        guard type != .none else {
            return imageBuffer
        }
        let isTinyPlanet = type == .tinyPlanet
        
        CVPixelBufferLockBaseAddress(imageBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0) else {
            print("no baseadress, this is a planar buffer or the base address isn't locked")
            return imageBuffer
        }
        
        let doublePi = Double.doublePi
        
        let blueOffset = 0
        let greenOffset = 1
        let redOffset = 2
        let alphaOffset = 3
        
        let width = CVPixelBufferGetWidthOfPlane(imageBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(imageBuffer, 0)
        let outputSize = (height*2)
        let numOfChannels = 4
        let bytestPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0)
        var outputBuffer: CVPixelBuffer?
        
        _ = CVPixelBufferCreate(kCFAllocatorDefault, outputSize, outputSize, kCVPixelFormatType_32BGRA, nil, &outputBuffer)
        
        let byteBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        CVPixelBufferLockBaseAddress(outputBuffer!, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        defer { CVPixelBufferUnlockBaseAddress(outputBuffer!, []) }
        
        guard let outputBaseAddress = CVPixelBufferGetBaseAddress(outputBuffer!) else {
            print("no baseadress, this is a planar buffer or the base address isn't locked")
            return imageBuffer
        }
        
        let outputByteBuffer = outputBaseAddress.assumingMemoryBound(to: UInt8.self)
        
        for y in 0..<outputSize {
            for x in 0..<outputSize {
                let coordinate = ComplexNumber(real: Double(height - (y)), imaginary: Double(height - (x))).asPolarCoordinate
                
                guard coordinate.radius <= Double(height) else {
                    continue
                }
                var newX: Int
                
                if y < (outputSize/2) {
                    newX = Int((max(Double(width-1),0) / 2) + ((coordinate.theta * max(Double(width-1),0)) / (doublePi)))
                } else {
                    newX = Int(max(Double(width-1),0) + ((coordinate.theta * max(Double(width-1),0)) / (doublePi)))
                }
                
                var newY: Int
                if isTinyPlanet {
                    newY = max(Int(Double(height-1) - coordinate.radius),0)
                } else {
                    newY = Int(coordinate.radius)
                }
                
                let index = ((y * bytestPerRow) + (x * numOfChannels))
                let newIndex = (((newY * width) + newX) * numOfChannels)
                
                guard index < (height * height * height), newIndex < (height * width * numOfChannels) else {
                    continue
                }
                
                let blueValue = byteBuffer[newIndex+blueOffset]
                outputByteBuffer[index+blueOffset] = blueValue
                
                let greenValue = byteBuffer[newIndex+greenOffset]
                outputByteBuffer[index+greenOffset] = greenValue
                
                let redValue = byteBuffer[newIndex+redOffset]
                outputByteBuffer[index+redOffset] = redValue
                
                let alphaValue = byteBuffer[newIndex+alphaOffset]
                outputByteBuffer[index+alphaOffset] = alphaValue
            }
        }
        
        return outputBuffer ?? imageBuffer
        
    }
    
    func display(imageBuffer: CVPixelBuffer) {
        
        let ciimage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgimage = CIContext().createCGImage(ciimage, from: CGRect(origin: .zero, size: CGSize(width: imageBuffer.width, height: imageBuffer.height))) else {
            return
        }
        
        
        DispatchQueue.main.async {
            self.newImageHandler?(Image(cgImage: cgimage))
        }
        
    }
    
}
