//
//  ZGraphController.swift
//  Thoughtful
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


var gGraphController: ZGraphController? { return gControllers.controllerForID(.idGraph) as? ZGraphController }


class ZGraphController: ZGesturesController, ZScrollDelegate {
    
	override  var    controllerID :  ZControllerID { return .idGraph }
	@IBOutlet var         spinner :  ZProgressIndicator?
	@IBOutlet var        dragView :  ZDragView?
	@IBOutlet var     spinnerView :  ZView?
	var        thoughtsRootWidget :  ZoneWidget? { return gHereMaybe?.widget }
	var       favoritesRootWidget :  ZoneWidget? { return gFavoritesRoot?.widget }
	var        rubberbandPreGrabs =  ZoneArray    ()
	var       priorScrollLocation =  CGPoint.zero
	var           rubberbandStart =  CGPoint.zero
	let 		     clickManager =  ZClickManager()

	class ZClickManager : NSObject {

		var lastClicked:   Zone?
		var lastClickTime: Date?

		func isDoubleClick(on iZone: Zone? = nil) -> Bool {
			let    isFast = lastClickTime?.timeIntervalSinceNow ?? -10.0 > -1.8
			let  isRepeat = lastClicked == iZone
			lastClickTime = Date()
			lastClicked   = iZone

			columnarReport("repeat: \(isRepeat)", "fast: \(isFast)")

			return isRepeat ? isFast : false
		}
	}

	var rubberbandRect: CGRect? { // wrapper with new value logic
		get {
			return dragView?.rubberbandRect
		}
		
		set {
			if  let d = dragView {
				if  newValue == nil || rubberbandStart == .zero {
					d.rubberbandRect = .zero

					gSelecting.assureMinimalGrabs()
					gSelecting.updateCurrentBrowserLevel()
					gSelecting.updateCousinList()
				} else {
					d.rubberbandRect = newValue
					let       inRing = gRingView?.handleClick(in: newValue) ?? false

					if  !inRing {
						gSelecting.ungrabAll(retaining: rubberbandPreGrabs)
						gHere.ungrab()

						let visibleWidgets = gHere.visibleWidgets + (gFavoritesRoot?.visibleWidgets ?? [])

						for widget in visibleWidgets {
							if  let    hitRect = widget.hitRect {
								let widgetRect = widget.convert(hitRect, to: d)

								if  let   zone = widget.widgetZone, !zone.isRootOfFavorites,
									widgetRect.intersects(newValue!) {
									widget.widgetZone?.addToGrab()
								}
							}
						}
					}
				}
				
				d.setAllSubviewsNeedDisplay()
			}
		}
	}

    override func setup() {
		gestureView = dragView // do this before calling super setup

		super.setup()
		platformSetup()

		if  let widget = thoughtsRootWidget {
			dragView?.addSubview(widget)
		}

        if  !kIsPhone,
			let widget = favoritesRootWidget {
            dragView?.addSubview(widget)
        }
    }

    #if os(OSX)
    
    func platformSetup() {
        guard let lighten = CIFilter(name: "CIColorControls") else { return }

		lighten.setDefaults()
        lighten.setValue(1, forKey: "inputBrightness")

		spinner?.contentFilters = [lighten]
    }
    
    #elseif os(iOS)
    
    @IBOutlet weak var keyInput: ZKeyInput?
    
    func platformSetup() {
        keyInput?.becomeFirstResponder()
    }
    
    #endif

	// MARK:- operations
	// MARK:-

    #if os(iOS) && false
    private func updateMinZoomScaleForSize(_ size: CGSize) {
        let           w = thoughtsRootWidget
        let heightScale = size.height / w.bounds.height
        let  widthScale = size.width  / w.bounds.width
        let    minScale = min(widthScale, heightScale)
        gScaling        = Double(minScale)
    }


    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateMinZoomScaleForSize(view.bounds.size)
    }
    #endif

	func toggleGraphs() {
		toggleDatabaseID()
		gFocusRing.push()
		gHere.grab()
		gHere.revealChildren()
		gFavorites.updateAllFavorites()
	}

	func recenter() {
		gScaling      = 1.0
		gScrollOffset = CGPoint.zero
		
		layoutForCurrentScrollOffset()
	}

    func layoutForCurrentScrollOffset() {
        if  let d = dragView {
			if  let widget = thoughtsRootWidget {
				widget.snp.removeConstraints()
				widget.snp.makeConstraints { make in
					make.centerY.equalTo(d).offset(gScrollOffset.y)
					make.centerX.equalTo(d).offset(gScrollOffset.x)
				}
			}

			if  let widget = favoritesRootWidget {
				if  widget.superview == nil {
					d.addSubview(widget)
				}
            
				widget.snp.removeConstraints()
				widget.snp.makeConstraints { make in
					if kIsPhone {
						make.centerY.equalTo(d).offset(gScrollOffset.y)
						make.centerX.equalTo(d).offset(gScrollOffset.x)
					} else {
						make  .top.equalTo(d).offset(45.0 - Double(gGenericOffset.height / 3.0))
						make .left.equalTo(d).offset(15.0 - Double(gGenericOffset.width       ))
					}
				}
			}
            
            d.setNeedsDisplay()
        }
    }
    
    // MARK:- events
    // MARK:-

	func isDoneGesture(_ iGesture: ZGestureRecognizer?) -> Bool { return doneStates.contains(iGesture!.state) }

    func layoutRootWidget(for iZone: Any?, _ iKind: ZSignalKind, inPublicGraph: Bool) {
        if  kIsPhone && (inPublicGraph == gShowFavorites) { return }

        let                        here = inPublicGraph ? gHereMaybe         : gFavoritesRoot
        var specificWidget: ZoneWidget? = inPublicGraph ? thoughtsRootWidget : favoritesRootWidget
        var specificView:        ZView? = dragView
        var specificIndex:         Int?
        var                   recursing = true
        gTextCapturing                  = false
        specificWidget?     .widgetZone = here

        if  let      zone  = iZone as? Zone {
			specificWidget = zone.widget
            specificIndex  = zone.siblingIndex
            specificView   = specificWidget?.superview
            recursing      = [.eData, .eRelayout].contains(iKind)
        }

        specificWidget?.layoutInView(specificView, atIndex: specificIndex, recursing: recursing, iKind, isThought: inPublicGraph, visited: [])
    }
    
    override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
        if  [.eDatum, .eData, .eRelayout].contains(iKind) { // ignore for preferences, search, information, startup
			prepare(for: iKind)
			protectAndClearViews(and: iSignalObject as? Zone)
			layoutRootWidget(for: iSignalObject, iKind, inPublicGraph: true)
			layoutRootWidget(for: iSignalObject, iKind, inPublicGraph: false)

			if  dragView?.subviews.count ?? 0 > 0 {
				layoutForCurrentScrollOffset()
				dragView?.setAllSubviewsNeedDisplay()
			}
        }

		gRingView?.setNeedsDisplay()
    }

	func protectAndClearViews(and zone: Zone?) {
		dragView?.removeAllSubviews()
	}
	
	func prepare(for iKind: ZSignalKind) {
		if  kIsPhone {
			favoritesRootWidget?.isHidden = !gShowFavorites
			thoughtsRootWidget? .isHidden =  gShowFavorites
		}
	}
	
	func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
		return (gestureRecognizer == clickGesture && otherGestureRecognizer == movementGesture) ||
			otherGestureRecognizer == edgeGesture
	}

	override func restartGestureRecognition() {
		gestureView?.gestureHandler = self
		gDraggedZone				= nil
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) {
        if  gIsSearchMode {
            gSearching.exitSearchMode()
        }
        
        if  gIsGraphOrEditIdeaMode,
			let gesture = iGesture as? ZKeyPanGestureRecognizer,
            let (_, dropNearest, location) = widgetNearest(gesture),
            let   flags = gesture.modifiers {
            let   state = gesture.state

            dropNearest.widgetZone?.deferWrite()

            if  isEditingText(at: location) {
                restartGestureRecognition()     // let text editor consume the gesture
            } else if flags.isCommand {
                scrollEvent(move: state == .changed, to: location)
            } else if gIsDragging {
                dragMaybeStopEvent(iGesture)
            } else if state == .changed {       // changed
                rubberbandRect = CGRect(start: rubberbandStart, end: location)
			} else if ![.began, .possible].contains(state) {         // ended, cancelled or failed
                rubberbandRect = nil

				restartGestureRecognition()
				signalMultiple([.eDatum]) // so color well and indicators get updated
			} else  if  let  dot = detectDot(iGesture) {
				if  !dot.isReveal {
					dragStartEvent(dot, iGesture)
				} else if let zone = dot.widgetZone {
					cleanupAfterDrag()
					gGraphEditor.clickActionOnRevealDot(for: zone, COMMAND: flags.isCommand, OPTION: flags.isOption)   // no dragging
				}
			} else if let widget = detectWidget(iGesture) {
				if  let         zone = widget.widgetZone {
					printDebug(.edit, "[detect]  \(zone)")
					gTemporarilySetMouseDownLocation(location.x)
					gTemporarilySetMouseZone(zone)
					gTextEditor.edit(zone)
				}
            } else {                            // began
                rubberbandStartEvent(location, iGesture)
            }
        }
    }
	
	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
        if  gIsSearchMode {
            gSearching.exitSearchMode()
        }
        
        if  gIsGraphOrEditIdeaMode,
			let    gesture = iGesture {
            let    COMMAND = gesture.isCommandDown
			let     OPTION = gesture.isOptionDown
			let      SHIFT = gesture.isShiftDown
            let editWidget = gCurrentlyEditingWidget
            var  regarding = ZSignalKind.eDatum
			let    inCrumb = gBreadcrumbsLabel != nil && gBreadcrumbsLabel!.hitCrumb(gesture.location(in: nil)) != nil
            var withinEdit = false

			if  editWidget != nil {
				editWidget?.widgetZone?.deferWrite()

				// ////////////////////////////////////////
				// detect click inside text being edited //
				// ////////////////////////////////////////

                let backgroundLocation = gesture.location(in: dragView)
                let           textRect = editWidget!.convert(editWidget!.bounds, to: dragView)
                withinEdit             = textRect.contains(backgroundLocation)
            }

            if  !withinEdit, !inCrumb {
				gSetGraphMode()
				gTextEditor.clearEdit()

				if  let   widget = detectWidget(gesture) {
					if  let zone = widget.widgetZone {
						gTemporarilySetMouseZone(zone)

						if  let dot = detectDotIn(widget, gesture) {

							// ///////////////
							// click in dot //
							// ///////////////

							if  dot.isReveal {
								gGraphEditor.clickActionOnRevealDot(for: zone, COMMAND: COMMAND, OPTION: OPTION)
							} else {
								regarding = .eDetails // update selection level

								zone.dragDotClicked(COMMAND, SHIFT, clickManager.isDoubleClick(on: zone))
							}
						} else {
							gTextEditor.edit(zone)
						}
					}
				} else {
					let   rect = CGRect(origin: gesture.location(in: dragView), size: CGSize())
					let inRing = gRingView?.itemInRect(rect) ?? false

					// //////////////////////
					// click in background //
					// //////////////////////

					if !inRing {
						gTextEditor.stopCurrentEdit()

						if  clickManager.isDoubleClick() {
							recenter()
						} else if !kIsPhone {	// default reaction to click on background: select here
							gHereMaybe?.grab()  // safe version of here prevent crash early in launch
						}
					}
                }

                signalMultiple([regarding])
            }

            restartGestureRecognition()
        }
	}
	
	
    // //////////////////////////////////////////
    // next four are only called by controller //
    // //////////////////////////////////////////
    
    
    func dragStartEvent(_ dot: ZoneDot, _ iGesture: ZGestureRecognizer?) {
        if  var zone = dot.widgetZone { // should always be true
            if  iGesture?.isOptionDown ?? false {
                zone = zone.deepCopy // option means drag a copy
            }

            if  iGesture?.isShiftDown ?? false {
                zone.addToGrab()
            } else if !zone.isGrabbed {
                zone.grab()
            }
            
            if  let location  = iGesture?.location(in: dot) {
                dot.dragStart = location
                gDraggedZone  = zone
            }
        }
    }
    
    
    func dragMaybeStopEvent(_ iGesture: ZGestureRecognizer?) {
        if  dragDropMaybe(iGesture) {
            cleanupAfterDrag()
            
            if  isDoneGesture(iGesture) {
				signalMultiple([.ePreferences, .eCrumbs]) // so color well gets updated
                restartGestureRecognition()
            }
        }
    }

    
    func scrollEvent(move: Bool, to location: CGPoint) {
        if move {
            gScrollOffset   = CGPoint(x: gScrollOffset.x + location.x - priorScrollLocation.x, y: gScrollOffset.y + priorScrollLocation.y - location.y)
            
            layoutForCurrentScrollOffset()
        }
        
        priorScrollLocation = location
    }
    
    
    // //////////////////////////////////////////
    // next four are only called by controller //
    // //////////////////////////////////////////
    
    
    func rubberbandStartEvent(_ location: CGPoint, _ iGesture: ZGestureRecognizer?) {
        rubberbandStart = location
        gDraggedZone    = nil
        
        // ///////////////////
        // detect SHIFT key //
        // ///////////////////
        
        if let gesture = iGesture, gesture.isShiftDown {
            rubberbandPreGrabs.append(contentsOf: gSelecting.currentGrabs)
        } else {
            rubberbandPreGrabs.removeAll()
        }
        
        gTextEditor.stopCurrentEdit()
        gSelecting.ungrabAll(retaining: rubberbandPreGrabs)
    }


    func dragDropMaybe(_ iGesture: ZGestureRecognizer?) -> Bool {
        if  let draggedZone       = gDraggedZone {
            if  draggedZone.userCanMove,
                let (isThought, dropNearest, location) = widgetNearest(iGesture) {
                var      dropZone = dropNearest.widgetZone
                let dropIsGrabbed = gSelecting.currentGrabs.contains(dropZone!)
                let     dropIndex = dropZone?.siblingIndex
                let          here = isThought ? gHere : gFavoritesRoot
                let      dropHere = dropZone == here
                let      relation = relationOf(location, to: dropNearest.textWidget)
                let useDropParent = relation != .upon && !dropHere
                ;        dropZone = dropIsGrabbed ? nil : useDropParent ? dropZone?.parentZone : dropZone
                let lastDropIndex = dropZone == nil ? 0 : dropZone!.count
                var         index = (useDropParent && dropIndex != nil) ? (dropIndex! + relation.rawValue) : ((!gListsGrowDown || dropIsGrabbed) ? 0 : lastDropIndex)
                ;           index = !dropHere ? index : relation != .below ? 0 : lastDropIndex
                let     dragIndex = draggedZone.siblingIndex
                let     sameIndex = dragIndex == index || dragIndex == index - 1
                let  dropIsParent = dropZone?.children.contains(draggedZone) ?? false
                let    spawnCycle = dropZone?.spawnCycle ?? false
                let        isNoop = dropIsGrabbed || spawnCycle || (sameIndex && dropIsParent) || index < 0
                let         prior = gDragDropZone?.widget
                let       dropNow = isDoneGesture(iGesture)
                gDragDropIndices  = isNoop || dropNow ? nil : NSMutableIndexSet(index: index)
                gDragDropZone     = isNoop || dropNow ? nil : dropZone
                gDragRelation     = isNoop || dropNow ? nil : relation
                gDragPoint        = isNoop || dropNow ? nil : location

                if !isNoop && !dropNow && !dropHere && index > 0 {
                    gDragDropIndices?.add(index - 1)
                }

                prior?           .displayForDrag() // erase  child lines
                dropZone?.widget?.displayForDrag() // relayout child lines
                dragView?        .setNeedsDisplay() // relayout drag: line and dot

                if !isNoop,     dropNow,
					let         drop = dropZone {
                    let   toBookmark = drop.isBookmark
                    var dropAt: Int? = index

                    if toBookmark {
                        dropAt       = gListsGrowDown ? nil : 0
                    } else if dragIndex != nil && dragIndex! <= index && dropIsParent {
                        dropAt!     -= 1
                    }

                    if  let gesture = iGesture as? ZKeyPanGestureRecognizer,
                        let CONTROL = gesture.modifiers?.isControl {
                        gGraphEditor.moveGrabbedZones(into: drop, at: dropAt, CONTROL) {
                            gSelecting.updateBrowsingLevel()
                            gSelecting.updateCousinList()
                            self.restartGestureRecognition()
                            self.redrawAndSync()
                        }
                    }
                }

                return dropNow
            }
        }

        return true
    }


    // MARK:- large indicators
    // MARK:-

//    func showSpinner(_ show: Bool) {
//		spinnerView?.isHidden = !show
//
//		if  show {
//			spinner?.startAnimating()
//		} else {
//			spinner?.stopAnimating()
//		}
//    }

    
    // MARK:- internals
    // MARK:-


    func widgetNearest(_ iGesture: ZGestureRecognizer?, isThought: Bool = true) -> (Bool, ZoneWidget, CGPoint)? {
        let           rootWidget = isThought ? thoughtsRootWidget : favoritesRootWidget
        if  let thoughtsLocation = iGesture?.location(in: dragView),
            let thoughtsZone     = rootWidget?.widgetNearestTo(thoughtsLocation, in: dragView, gHereMaybe) {
            if  isThought, !kIsPhone,

                // /////////////////////////////////////
				// recurse once: with isThought false //
                // /////////////////////////////////////

                let (_, favoritesZone, favoritesLocation) = widgetNearest(iGesture, isThought: false) {

                // ////////////////////////////////////////////
                //     target zone found in both graphs      //
                // deterimine which zone is closer to cursor //
                // ////////////////////////////////////////////

				let locationT =  thoughtsZone.dragDot
                let locationF = favoritesZone.dragDot
                let twoSidesT = locationT.convert(locationT.bounds.center, to: view) - thoughtsLocation
                let twoSidesF = locationF.convert(locationF.bounds.center, to: view) - thoughtsLocation
                let   scalarT = twoSidesT.hypontenuse
                let   scalarF = twoSidesF.hypontenuse

                if  scalarT > scalarF {
                    return (false, favoritesZone, favoritesLocation)
                }
            }

            return (true, thoughtsZone, thoughtsLocation)
        }

        return nil
    }

    
    func isEditingText(at location: CGPoint) -> Bool {
        if  gIsEditIdeaMode, let textWidget = gCurrentlyEditingWidget {
            let rect = textWidget.convert(textWidget.bounds, to: dragView)

            return rect.contains(location)
        }

        return false
    }


    func cleanupAfterDrag() {
        rubberbandStart  = CGPoint.zero

        // cursor exited view, remove drag cruft

        let          dot = gDragDropZone?.widget?.revealDot.innerDot // drag view does not "un"draw this
        gDragDropIndices = nil
        gDragDropZone    = nil
        gDragRelation    = nil
        gDragPoint       = nil

        favoritesRootWidget?.setNeedsDisplay()
        thoughtsRootWidget? .setNeedsDisplay()
        dragView?           .setNeedsDisplay() // erase drag: line and dot
        dot?                .setNeedsDisplay()
    }


    func relationOf(_ iPoint: CGPoint, to iView: ZView?) -> ZRelation {
        var relation: ZRelation = .upon

        if  iView     != nil {
            let margin = CGFloat(5.0)
            let  point = dragView!.convert(iPoint, to: iView)
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


    // MARK:- detect
    // MARK:-


    func detectWidget(_ iGesture: ZGestureRecognizer?) -> ZoneWidget? {
        var hit: ZoneWidget?
        if  let        d = dragView,
            let location = iGesture?.location(in: d),
            d.bounds.contains(location) {
			for zone in [gHere, gFavoritesRoot] {
				zone!.traverseProgeny { child -> (ZTraverseStatus) in
					if  let widget = child.widget {
						let   rect = widget.convert(widget.outerHitRect, to: d)

						if  rect.contains(location) {
							hit    = widget

							printDebug(.edit, "[hit]     \(child)")

							return .eStop
						}
					}

					return child.isVisible ? .eContinue : .eSkip
				}
			}
        }

        return hit
    }

    func detectDotIn(_ widget: ZoneWidget, _ iGesture: ZGestureRecognizer?) -> ZoneDot? {
        var hit:        ZoneDot?

        if  let                d = dragView,
            let         location = iGesture?.location(in: d) {
            let isIn: DotClosure = { iDot in
                let         rect = iDot.convert(iDot.bounds, to: d)

                if  rect.contains(location) {
                    hit = iDot
                }
            }

            isIn(widget.dragDot)
            isIn(widget.revealDot)
        }

        return hit
    }

    func detectDot(_ iGesture: ZGestureRecognizer?) -> ZoneDot? {
        if  let widget = detectWidget(iGesture) {
            return detectDotIn(widget, iGesture)
        }

        return nil
    }

}

