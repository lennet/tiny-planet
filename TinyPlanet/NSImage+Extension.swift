//
//  NSImage+Extension.swift
//  TinyPlanet
//
//  Created by Leo Thomas on 13.06.17.
//  Copyright © 2017 Leonard Thomas. All rights reserved.
//

import Cocoa

extension NSImage {
    
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
    }
    
}
