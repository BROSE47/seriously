//
//  ZIndicatorView.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 2/16/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import Foundation

class ZIndicatorView: ZView {
    
    
    override func draw(_ iDirtyRect: CGRect) {
        super.draw(iDirtyRect)
        
        var           rect = bounds.squareCenetered
        let          inset = rect.size.width / 3.0
        let    circleInset = inset / 3.85
        rect               = rect.insetBy(dx: inset,       dy: inset)
        var   triangleRect = rect.insetBy(dx: 0,           dy: inset / 14.0)
        var     circleRect = rect.insetBy(dx: circleInset, dy: circleInset)
        let      thickness = rect.size.height / 30.0

        let     multiplier = CGFloat(gInsertionsFollow ? 1 : -1)
        let verticalOffset = gInsertionsFollow ? 15.0 - triangleRect.minY : bounds.maxY - triangleRect.maxY - 15.0
        let   circleOffset = (circleInset / 1.8 * multiplier) + verticalOffset
        triangleRect       = triangleRect.offsetBy(dx: 0.0, dy: verticalOffset)
        circleRect         = circleRect  .offsetBy(dx: 0.0, dy: circleOffset)
        let    circlesRect = triangleRect.insetBy(fractionX: 0.425, fractionY: 0.15)

        gBackgroundColor.lightish(by: 1.02).setStroke()

        ZBezierPath.drawTriangle(orientedUp: gInsertionsFollow, in: triangleRect, fillWith: gBackgroundColor.darker(by: 0.75), thickness: thickness)
        
        if  gBrowsingIsConfined {
            ZBezierPath.drawCircle(in: circleRect, fillWith: gBackgroundColor, thickness: thickness)
        } else {
            ZBezierPath.drawCircles(orientedUp: gInsertionsFollow, in: circlesRect, fillWith: gBackgroundColor, thickness: thickness)
        }
    }
}


extension ZBezierPath {

    static func drawTriangle(orientedUp: Bool, in iRect: CGRect, fillWith iColor: ZColor, thickness: CGFloat) {
        let path = ZBezierPath()
        
        path.appendTriangle(orientedUp: orientedUp, in: iRect)
        path.draw(fillWith: iColor, thickness: thickness)
    }
    
    static func drawCircle(in iRect: CGRect, fillWith iColor: ZColor, thickness: CGFloat) {
        let path = ZBezierPath(ovalIn: iRect)
        
        path.draw(fillWith: iColor, thickness: thickness)
    }
    
    static func drawCircles(orientedUp: Bool, in iRect: CGRect, fillWith iColor: ZColor, thickness: CGFloat) {
        let path = ZBezierPath()
        
        path.appendCircles(orientedUp: orientedUp, in: iRect)
        path.draw(fillWith: iColor, thickness: thickness)
    }

    func draw(fillWith iColor: ZColor, thickness: CGFloat) {
        lineWidth = thickness

        iColor.setFill()
        stroke()
        // fill()
    }
    
    func appendTriangle(orientedUp: Bool, in iRect: CGRect) {
        let yStart = orientedUp ? iRect.minY : iRect.maxY
        let   yEnd = orientedUp ? iRect.maxY : iRect.minY
        let    tip = CGPoint(x: iRect.midX, y: yStart)
        let   left = CGPoint(x: iRect.minX, y: yEnd)
        let  right = CGPoint(x: iRect.maxX, y: yEnd)

        move(to: tip)
        line(to: left)
        line(to: right)
        line(to: tip)
    }
    
    func appendCircles(orientedUp: Bool, in iRect: CGRect) {
        let   rect = iRect.offsetBy(fractionX: 0.0, fractionY: orientedUp ? 0.1 : -0.1)
        var    top = rect.insetBy(fractionX: 0.0, fractionY: 0.375)  // shrink to one-fifth size
        let middle = top.offsetBy(dx: 0.0, dy: top.midY - rect.midY)
        let bottom = top.offsetBy(dx: 0.0, dy: top.maxY - rect.maxY) // move to bottom
        top        = top.offsetBy(dx: 0.0, dy: top.minY - rect.minY) // move to top
        
        appendOval(in: top)
        appendOval(in: middle)
        appendOval(in: bottom)
    }

}


extension CGRect {
    var squareCenetered: CGRect {
        let length = size.minimumDimension
        let origin = CGPoint(x: minX + (size.width - length) / 2.0, y: minY + (size.height - length) / 2.0)

        return CGRect(origin: origin, size: CGSize(width: length, height: length))
    }
}


extension CGSize {
    
    var minimumDimension: CGFloat {
        return width > height ? height : width
    }

}