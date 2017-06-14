//
//  CVPixelBuffer+Extension.swift
//  TinyPlanet
//
//  Created by Leo Thomas on 13.06.17.
//  Copyright © 2017 Leonard Thomas. All rights reserved.
//

import AVFoundation

extension CVPixelBuffer {

    var width: Int {
        return CVPixelBufferGetWidth(self)
    }
    
    var height: Int {
        return CVPixelBufferGetHeight(self)
    }
    
    func copy(with context: CIContext = CIContext()) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        _ = CVPixelBufferCreate(nil, self.width, self.height, kCVPixelFormatType_32BGRA, nil, &buffer)
        
        guard let result = buffer else {
            return nil
        }
        CIContext().render(CIImage(cvImageBuffer: self), to: result)
        return result
    }
}
