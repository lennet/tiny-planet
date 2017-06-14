//
//  ComplexNumber.swift
//  TinyPlanet
//
//  Created by Leo Thomas on 16.05.17.
//  Copyright © 2017 Leonard Thomas. All rights reserved.
//

import Foundation

struct ComplexNumber {
    var real: Double
    var imaginary: Double
}

extension ComplexNumber {
    
    var radius: Double {
        return sqrt(pow(imaginary, 2) + pow(real, 2))
    }
    
    var angle: Double {
        guard real != 0 else {
            return 0
        }
        return atan(imaginary/real)
    }
    
    var asPolarCoordinate: PolarCoordinate {
        return PolarCoordinate(radius: radius, theta: angle)
    }
    
}
