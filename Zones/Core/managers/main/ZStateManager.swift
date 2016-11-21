//
//  ZStateManager.swift
//  Zones
//
//  Created by Jonathan Sand on 10/14/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZStateManager: NSObject {


    var   textCapturing:      Bool = false
    var       toolState: ZToolMode = .edit
    let   genericOffset:    CGSize = CGSize(width: 0.0, height: 4.0)
    let       lineColor:    ZColor = ZColor.purple //(hue: 0.6, saturation: 0.6, brightness: 1.0,                alpha: 1)
    let unselectedColor:    ZColor = ZColor(hue: 0.6, saturation: 0.0, brightness: unselectBrightness, alpha: 1)
    let    lineThicknes:   CGFloat = 1.25
    let       dotLength:   CGFloat = 12.0


    var lightFillColor: ZColor { get { return lineColor.withAlphaComponent(0.03) } }
}
