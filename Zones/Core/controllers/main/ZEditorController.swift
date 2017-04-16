//
//  ZEditorController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZEditorController: ZGenericController, ZGestureRecognizerDelegate {


    var        hereWidget = ZoneWidget()
    @IBOutlet var spinner:  ZProgressIndicator?


    override func identifier() -> ZControllerID { return .editor }


    override func setup() {
        view.clearGestures()
        view.createPointGestureRecognizer(self, action: #selector(ZEditorController.oneClick), clicksRequired: 1)
        super.setup()
    }


    // MARK:- events
    // MARK:-


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        if [.search, .found, .startup].contains(kind) {
            return
        } else if gWorkMode != .editMode {
            view.snp.removeConstraints()
            hereWidget.removeFromSuperview()

            return
        }

        let                        zone = object as? Zone
        var                   recursing = true
        var specificWidget: ZoneWidget? = hereWidget
        var specificView:        ZView? = view
        var specificindex:         Int? = nil
        gTextCapturing                  = false
        hereWidget.widgetZone           = gHere
        view    .zlayer.backgroundColor = gBackgroundColor.cgColor

        if zone != nil && zone != gHere {
            specificWidget = zone!.widget
            specificindex  = zone!.siblingIndex
            specificView   = specificWidget?.superview
            recursing      = [.data, .redraw].contains(kind)

            if zone!.isSelected {
                zone!.grab()
            }

            toConsole(zone?.zoneName)
        }

        specificWidget?.layoutInView(specificView, atIndex: specificindex, recursing: recursing, kind: kind)
        view.applyToAllSubviews { iView in
            iView.setNeedsDisplay()
        }
    }


    override func displayActivity() {
        let isReady = gOperationsManager.isReady

        spinner?.isHidden = isReady

        if isReady {
            spinner?.stopAnimating()
        } else {
            spinner?.startAnimating()
        }
    }

    
    func oneClick(_ sender: ZGestureRecognizer?) {
        gShowsSearching = false

        gSelectionManager.deselect()
        signalFor(nil, regarding: .search)
    }


    // MARK:- drag and drop
    // MARK:-


    func relationOf(_ iPoint: CGPoint, to iView: ZView?) -> ZRelation {
        var relation: ZRelation = .upon

        if  iView     != nil {
            let margin = CGFloat(5.0)
            let  point = view.convert(iPoint, to: iView)
            let   rect = iView!.bounds
            let      y = point.y

            if y < rect.minY + margin {
                relation = .above
            } else if y > rect.maxY - margin {
                relation = .below
            }
        }

        return relation
    }


    func handleDragEvent(_ iGesture: ZGestureRecognizer?) {
        if  let           location = iGesture?.location (in: view) {
            let               done = [ZGestureRecognizerState.ended, ZGestureRecognizerState.cancelled].contains(iGesture!.state)
            let                dot = iGesture?.view as! ZoneDot
            let        draggedZone = dot.widgetZone!
            if  let    dropNearest = hereWidget.widgetNearestTo(location, in: view) {
                var       dropZone = dropNearest.widgetZone
                let      dropIndex = dropZone?.siblingIndex
                let       dropHere = dropZone == gHere
                let           same = dropZone == draggedZone
                let       relation = relationOf(location, to: dropNearest.textWidget)
                let  useDropParent = relation != .upon && !dropHere
                ;         dropZone = same ? nil : useDropParent ? dropZone?.parentZone : dropZone
                let  lastDropIndex = dropZone == nil ? 0 : dropZone!.count
                var          index = (useDropParent && dropIndex != nil) ? (dropIndex! + relation.rawValue) : ((asTask || same) ? 0 : lastDropIndex)
                ;            index = !dropHere ? index : relation != .below ? 0 : lastDropIndex
                let      dragIndex = draggedZone.siblingIndex!
                let      sameIndex = dragIndex == index || dragIndex == index - 1
                let   dropIsParent = draggedZone.isChild(of: dropZone)
                let         isNoop = same || (sameIndex && dropIsParent) || index < 0
                let              s = gSelectionManager
                let          prior = s.dragDropZone?.widget
                s .dragDropIndices = isNoop || done ? nil : NSMutableIndexSet(index: index)
                s    .dragDropZone = isNoop || done ? nil : dropZone
                s    .dragRelation = isNoop || done ? nil : relation
                s       .dragPoint = isNoop || done ? nil : location

                if !isNoop && !done && !dropHere && index > 0 {
                    s.dragDropIndices?.add(index - 1)
                }

                prior?           .displayForDrag() // erase  child lines
                dropZone?.widget?.displayForDrag() // redraw child lines
                view            .setNeedsDisplay() // redraw dragline and dot

                // report("\(relation) \(dropZone?.zoneName ?? "no name")")

                if done {
                    let editor = gEditingManager

                    draggedZone.widget?.dragDot.innerDot?.setNeedsDisplay()

                    if !isNoop && dropZone != nil {
                        if dropZone!.isBookmark {
                            editor.moveZone(draggedZone, dropZone!)
                        } else {
                            if dropIsParent && dragIndex <= index {
                                index -= 1
                            }

                            editor.moveZone(draggedZone, into: dropZone!, at: index, orphan: true) {
                                editor.syncAndRedraw()
                            }
                        }
                    }
                    
                    editor.syncAndRedraw()
                }
            }
        }
    }
}