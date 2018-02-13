//
//  ZoneDot.swift
//  Zones
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

import SnapKit


class ZoneDot: ZView, ZGestureRecognizerDelegate {


    // MARK:- properties
    // MARK:-
    

    weak var     widget: ZoneWidget?
    var        innerDot: ZoneDot?
    var       dragStart: CGPoint? = nil
    var        isToggle:  Bool = true
    var      isInnerDot:  Bool = false
    var      isDragDrop:  Bool { return widgetZone == gDragDropZone }
    var      widgetZone: Zone? { return widget?.widgetZone }
    var isDragDotHidden:  Bool { return widgetZone?.onlyShowToggleDot ?? true }


    var innerOrigin: CGPoint? {
        if  let inner = innerDot {
            let  rect = inner.convert(inner.bounds, to: self)

            return rect.origin
        }

        return nil
    }


    var innerExtent: CGPoint? {
        if  let inner = innerDot {
            let  rect = inner.convert(inner.bounds, to: self)

            return rect.extent
        }

        return nil
    }


    var isDropTarget: Bool {
        if  let   index = widgetZone?.siblingIndex, !isToggle {
            let isIndex = gDragDropIndices?.contains(index)
            let  isDrop = widgetZone?.parentZone == gDragDropZone

            if isDrop && isIndex! {
                return true
            }
        }

        return false
    }


    var toggleDotIsVisible: Bool {
        var isHidden = false
        if  let zone = widgetZone, isInnerDot, isToggle {
            isHidden = !zone.canTravel && zone.fetchableCount == 0 && !isDragDrop
        }
        
        return !isHidden
    }


    // MARK:- initialization
    // MARK:-


    var         ratio:  CGFloat { return widget?.ratio ?? 1.0 }
    var innerDotWidth:  CGFloat { return ratio * CGFloat(isToggle ? gDotHeight : isDragDotHidden ? 0.0 : gDotWidth) }
    var innerDotHeight: CGFloat { return ratio * CGFloat(gDotHeight) }


    func setupForWidget(_ iWidget: ZoneWidget, asToggle: Bool) {
        isToggle = asToggle
        widget   = iWidget

        if isInnerDot {
            snp.removeConstraints()
            snp.makeConstraints { make in
                let  size = CGSize(width: innerDotWidth, height: innerDotHeight)

                make.size.equalTo(size)
            }

            setNeedsDisplay(frame)
        } else {
            if  innerDot            == nil {
                innerDot             = ZoneDot()
                innerDot!.isInnerDot = true

                addSubview(innerDot!)
            }

            innerDot!.setupForWidget(iWidget, asToggle: isToggle)
            snp.removeConstraints()
            snp.makeConstraints { make in
                var   width = !isToggle && isDragDotHidden ? CGFloat(0.0) : (gGenericOffset.width * 2.0) - (gGenericOffset.height / 6.0) - 42.0 + innerDotWidth
                let  height = innerDotHeight + 5.0 + (gGenericOffset.height * 3.0)

                if !iWidget.isInMain {
                    width  *= kReductionRatio
                }

                make.size.equalTo(CGSize(width: width, height: height))
                make.center.equalTo(innerDot!)
            }
        }

        #if os(iOS)
            backgroundColor = kClearColor
        #endif
        
        updateConstraints()
        setNeedsDisplay()
    }


    // MARK:- draw
    // MARK:-


    enum ZDecorationType: Int {
        case vertical
        case sideDot
    }


    func isVisible(_ rect: CGRect) -> Bool {
        return window?.contentView?.bounds.intersects(rect) ?? false
    }


    func drawFavoritesHighlight(in dirtyRect: CGRect) {
        if  let          zone  = widgetZone, innerDot != nil, !zone.isRootOfFavorites {
            let      dotRadius = Double(innerDotWidth / 2.0)
            let     tinyRadius =  dotRadius * 0.7
            let   tinyDiameter = tinyRadius * 2.0
            let         center = innerDot!.frame.center
            let      offCenter = CGPoint(x: center.x - CGFloat(tinyRadius), y: center.y - CGFloat(tinyRadius))
            let    orbitRadius = CGFloat(dotRadius + tinyRadius)
            let              x = offCenter.x - orbitRadius
            let              y = offCenter.y
            let           rect = CGRect(x: x, y: y, width: CGFloat(tinyDiameter), height: CGFloat(tinyDiameter))
            let           path = ZBezierPath(ovalIn: rect)
            path.lineWidth     = CGFloat(gLineThickness * 1.2)
            path.flatness      = 0.0001

            path.stroke()
        }
    }


    func drawDot(in dirtyRect: CGRect) {
        let  thickness = CGFloat(gLineThickness)
        let       path = ZBezierPath(ovalIn: dirtyRect.insetBy(dx: thickness, dy: thickness))
        path.lineWidth = thickness * 2.0
        path .flatness = 0.0001

        path.stroke()
        path.fill()
    }


    func drawTinyDots(_ dirtyRect: CGRect) {
        if  let  zone  = widgetZone, innerDot != nil, gCountsMode == .dots, !zone.isRootOfFavorites, (!zone.showChildren || zone.isBookmark || zone.hasMissingChildren()) {
            var count  = zone.indirectFetchableCount

            if  count == 0 {
                count  = zone.count
            }

            if  count > 1 {
                let      dotRadius = Double(innerDotHeight / 2.0)
                let     tinyRadius = (dotRadius * gLineThickness / 12.0) + 0.7
                let   tinyDiameter = tinyRadius * 2.0
                let         center = innerDot!.frame.center
                let      offCenter = CGPoint(x: center.x - CGFloat(tinyRadius), y: center.y - CGFloat(tinyRadius))
                let color: ZColor? = isDragDrop ? gRubberbandColor : zone.color
                let     startAngle = Double(0)
                let incrementAngle = Double.pi / Double(count)
                let    orbitRadius = CGFloat(dotRadius + tinyRadius * 1.2)

                for index in 1 ... count {
                    let  increment = Double(index * 2 - 1)
                    let      angle = startAngle - incrementAngle * increment // positive means counterclockwise in osx (clockwise in ios)
                    let          x = offCenter.x + orbitRadius * CGFloat(cos(angle))
                    let          y = offCenter.y + orbitRadius * CGFloat(sin(angle))
                    let       rect = CGRect(x: x, y: y, width: CGFloat(tinyDiameter), height: CGFloat(tinyDiameter))
                    let       path = ZBezierPath(ovalIn: rect)
                    path .flatness = 0.0001

                    color?.setFill()
                    path.fill()
                }
            }
        }
    }


    func drawTinyCenterDot(in dirtyRect: CGRect) {
        let     inset = CGFloat(innerDotHeight / 3.0)
        let      path = ZBezierPath(ovalIn: dirtyRect.insetBy(dx: inset, dy: inset))
        path.flatness = 0.0001

        path.fill()
    }


    func drawAccessDecoration(of type: ZDecorationType, in dirtyRect: CGRect) {
        let     ratio = (widget?.isInMain ?? true) ? 1.0 : kReductionRatio
        var thickness = CGFloat(gLineThickness + 0.1) * ratio
        var      path = ZBezierPath(rect: CGRect.zero)
        var      rect = CGRect.zero

        switch type {
        case .vertical:
            rect      = CGRect(origin: CGPoint(x: dirtyRect.midX - (thickness / 2.0), y: dirtyRect.minY),                   size: CGSize(width: thickness, height: dirtyRect.size.height))
            path      = ZBezierPath(rect: rect)
        case .sideDot:
            thickness = (thickness + 2.5) * dirtyRect.size.height / 12.0
            rect      = CGRect(origin: CGPoint(x: dirtyRect.maxX -  thickness - 1.0,   y: dirtyRect.midY - thickness / 2.0), size: CGSize(width: thickness, height: thickness))
            path      = ZBezierPath(ovalIn: rect)
        }

        path.fill()
    }


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        if  let                zone = widgetZone, isVisible(dirtyRect) {
            let highlightAsFavorite = zone.isCurrentFavorite

            if  toggleDotIsVisible {
                if  isInnerDot {
                    let showTinyCenterDot = zone.canTravel && zone.fetchableCount == 0
                    let       dotIsFilled = isToggle ? (!zone.isRootOfFavorites && (!zone.showChildren || zone.hasMissingChildren() || showTinyCenterDot || isDragDrop)) : (zone.isGrabbed || highlightAsFavorite)
                    let       strokeColor = isToggle  && isDragDrop ? gRubberbandColor : zone.color
                    var         fillColor = dotIsFilled ? strokeColor : gBackgroundColor

                    ///////////////
                    // INNER DOT //
                    ///////////////

                    fillColor.setFill()
                    strokeColor.setStroke()
                    drawDot(in: dirtyRect)

                    if  isToggle {
                        if  showTinyCenterDot {

                            /////////////////////
                            // TINY CENTER DOT //
                            /////////////////////

                            gBackgroundColor.setFill()
                            drawTinyCenterDot(in: dirtyRect)
                        }
                    } else if zone.hasAccessDecoration {
                        let  type = zone.directChildrenWritable ? ZDecorationType.sideDot : ZDecorationType.vertical
                        fillColor = dotIsFilled ? gBackgroundColor : strokeColor

                        ////////////////////////
                        // ACCESS DECORATIONS //
                        ////////////////////////

                        fillColor.setFill()
                        drawAccessDecoration(of: type, in: dirtyRect)
                    }
                } else if isToggle {

                    /////////////////////
                    // TINY OUTER DOTS //
                    /////////////////////

                    // addBorderRelative(thickness: 1.0, radius: 0.5, color: ZColor.red.cgColor)
                    drawTinyDots(dirtyRect)
                } else if highlightAsFavorite {

                    ////////////////////////////////
                    // HIGHLIGHT CURRENT FAVORITE //
                    ////////////////////////////////

                    zone.color.withAlphaComponent(0.7).setStroke()
                    drawFavoritesHighlight(in: dirtyRect)
                }
            }
        }
    }

}
