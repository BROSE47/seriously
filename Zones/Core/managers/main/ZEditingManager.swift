//
//  ZEditingManager.swift
//  Zones
//
//  Created by Jonathan Sand on 10/29/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


enum ZArrowKey: CChar {
    case up    = -128
    case down
    case left
    case right
}


class ZEditingManager: NSObject {


    var previousEvent: ZEvent?
    var asTask: Bool { get { return editMode == .task } }


    // MARK:- API
    // MARK:-


    @discardableResult func handleKey(_ event: ZEvent, isWindow: Bool) -> Bool {
        if event == previousEvent || !operationsManager.isReady {
            return true
        } else {
            previousEvent = event
            let     flags = event.modifierFlags
            let   isShift = flags.contains(.shift)
            let  isOption = flags.contains(.option)
            let isCommand = flags.contains(.command)
            let   isArrow = flags.contains(.numericPad) && flags.contains(.function)

            if let widget = widgetsManager.currentMovableWidget {
                if let string = event.charactersIgnoringModifiers {
                    let key   = string[string.startIndex].description

                    if isArrow {
                        if isWindow {
                            let arrow = ZArrowKey(rawValue: key.utf8CString[2])!

                            if isShift {
                                if let zone = selectionManager.firstGrabbableZone {

                                    switch arrow {
                                    case .right: setChildrenVisibilityTo(true,  zone: zone, recursively: isCommand);                                            break
                                    case .left:  setChildrenVisibilityTo(false, zone: zone, recursively: isCommand); selectionManager.deselectDragWithin(zone); break
                                    default: return true
                                    }

                                    controllersManager.saveAndUpdateFor(nil)
                                }
                            } else {
                                switch arrow {
                                case .right: moveInto(     selectionOnly: !isOption, extreme: isCommand, persist: true); break
                                case .left:  moveOut(      selectionOnly: !isOption, extreme: isCommand, persist: true); break
                                case .down:  moveUp(false, selectionOnly: !isOption, extreme: isCommand, persist: true); break
                                case .up:    moveUp(true,  selectionOnly: !isOption, extreme: isCommand, persist: true); break
                                }
                            }

                            return true
                        }
                    } else {
                        switch key {
                        case "\t":
                            widget.textField.resignFirstResponder()

                            if let parent = widget.widgetZone.parentZone {
                                addZoneTo(parent)
                            } else {
                                selectionManager.currentlyEditingZone = nil

                                controllersManager.signal(nil, regarding: .data)
                            }

                            return true
                        case " ":
                            if isWindow || isOption {
                                addZoneTo(widget.widgetZone)

                                return true
                            }

                            break
                        case "\u{7F}":
                            if isWindow || isOption {
                                delete()

                                return true
                            }

                            break
                        case "\r":
                            if selectionManager.currentlyGrabbedZones.count != 0 {
                                if isShift {
                                    addParentTo(selectionManager.firstGrabbableZone)
                                } else {
                                    widget.textField.becomeFirstResponder()
                                }

                                return true
                            } else if selectionManager.currentlyEditingZone != nil {
                                widget.textField.resignFirstResponder()
                                
                                return true
                            }
                            
                            break
                        default:
                            
                            break
                        }
                    }
                }
            }
        }
        
        return false
    }


    // MARK:- layout
    // MARK:-


    func setChildrenVisibilityTo(_ show: Bool, zone: Zone?, recursively: Bool) {
        if zone != nil {
            let noVisibleChildren = !(zone?.showChildren)! || ((zone?.children.count)! == 0)

            if !show && noVisibleChildren && selectionManager.isGrabbed(zone!), let parent = zone?.parentZone {
                selectionManager.currentlyGrabbedZones = [parent]
                zone?.showChildren                     = false

                setChildrenVisibilityTo(show, zone: parent, recursively: recursively)
            } else {
                zone?.showChildren = show

                if recursively {
                    for child: Zone in (zone?.children)! {
                        setChildrenVisibilityTo(show, zone: child, recursively: recursively)
                    }
                }
            }
        }
    }


    func toggleChildrenVisibility(_ zone: Zone?) {
        if zone != nil {
            let show = zone?.showChildren == false

            setChildrenVisibilityTo(show, zone: zone, recursively: false)

            if !show {
                selectionManager.deselectDragWithin(zone!)
            }

            controllersManager.saveAndUpdateFor(nil)
        }
    }


    // MARK:- creation
    // MARK:-


    func addZoneTo(_ parentZone: Zone?) {
        addZoneTo(parentZone) { (object) -> (Void) in
            controllersManager.saveAndUpdateFor(parentZone, onCompletion: { () -> (Void) in
                operationsManager.isReady = true

                widgetsManager.widgetForZone(object as? Zone)?.textField.becomeFirstResponder()
                controllersManager.signal(parentZone, regarding: .data)
            })
        }
    }


    func addParentTo(_ zone: Zone?) {
        if let grandParentZone = zone?.parentZone {
            addZoneTo(grandParentZone, onCompletion: { (parent) -> (Void) in
                selectionManager.currentlyGrabbedZones = [zone!]

                self.moveInto(selectionOnly: false, extreme: false, persist: false)
                self.dispatchAsyncInForegroundAfter(0.5, closure: { () -> (Void) in
                    operationsManager.isReady = true
                    
                    widgetsManager.widgetForZone(parent as? Zone)?.textField.becomeFirstResponder()
                    controllersManager.signal(grandParentZone, regarding: .data)
                })
            })
        }
    }


    func addZoneTo(_ parentZone: Zone?, onCompletion: ObjectClosure?) {
        if parentZone != nil && travelManager.storageMode != .bookmarks {
            let record = CKRecord(recordType: zoneTypeKey)
            let   zone = Zone(record: record, storageMode: travelManager.storageMode)
            let insert = asTask ? 0 : (parentZone?.children.count)!

            widgetsManager.widgetForZone(parentZone!)?.textField.resignFirstResponder()

            if asTask {
                parentZone?.children.insert(zone, at: 0)
            } else {
                parentZone?.children.append(zone)
            }

            zone.parentZone          = parentZone
            parentZone?.showChildren = true

            parentZone?.recomputeOrderingUponInsertionAt(insert)
            onCompletion?(zone)
        }
    }


    func delete() {
        var last: Zone? = nil

        if let zone: Zone = selectionManager.currentlyEditingZone {
            last = deleteZone(zone)

            selectionManager.currentlyEditingZone = nil
        } else {
            last = deleteZones(selectionManager.currentlyGrabbedZones)

            selectionManager.currentlyGrabbedZones = []
        }

        if last != nil {
            selectionManager.currentlyGrabbedZones = [last!]
        }

        controllersManager.saveAndUpdateFor(nil)
    }


    @discardableResult private func deleteZones(_ zones: [Zone]) -> Zone? {
        var last: Zone? = nil

        for zone in zones {
            last = deleteZone(zone)
        }

        return last
    }


    private func deleteZone(_ zone: Zone) -> Zone? {
        zone.recordState  = .needsDelete

        deleteZones(zone.children)

        if let parentZone = zone.parentZone {
            if var  index = parentZone.children.index(of: zone) {
                cloudManager.records.removeValue(forKey: zone.record.recordID)
                parentZone.children.remove(at: index)

                index = max(0, index - 1)

                if parentZone.children.count > 0 {
                    return parentZone.children[index]
                } else  {
                    return parentZone
                }
            }
        }

        return nil
    }


    // MARK:- movement
    // MARK:-


    //    if beyond end, search for uncles aunts whose children or email


    func nextUpward(_ moveUp: Bool, extreme: Bool,  zone: Zone?) -> (Zone?, Int, Int) {
        if let siblings = zone?.parentZone?.children {
            if siblings.count > 0 {
                if let     index = siblings.index(of: zone!)  {
                    var newIndex = index + (moveUp ? -1 : 1)

                    if extreme {
                        newIndex = moveUp ? 0 : siblings.count - 1
                    }

                    if newIndex >= 0 && newIndex < siblings.count {
                        return (siblings[newIndex], index, newIndex)
                    }
                }
            }
        }

        return (nil, 0, 0)
    }


    func newmoveUp(_ moveUp: Bool, selectionOnly: Bool, extreme: Bool) {
        if let        zone: Zone = selectionManager.firstGrabbableZone {
            if let    parentZone = zone.parentZone {
                let (next, index, newIndex) = nextUpward(moveUp, extreme: extreme, zone: parentZone)

                if selectionOnly {
                    if next != nil {
                        selectionManager.currentlyGrabbedZones = [next!]
                    }
                } else if travelManager.storageMode != .bookmarks {
                    parentZone.children.remove(at: index)
                    parentZone.children.insert(zone, at:newIndex)
                }
                
                controllersManager.signal(parentZone, regarding: .data)
            }
        }
    }


    func moveUp(_ moveUp: Bool, selectionOnly: Bool, extreme: Bool, persist: Bool) {
        if let        zone: Zone = selectionManager.firstGrabbableZone {
            if let    parentZone = zone.parentZone {
                if let     index = parentZone.children.index(of: zone) {
                    var newIndex = index + (moveUp ? -1 : 1)

                    if extreme {
                        newIndex = moveUp ? 0 : parentZone.children.count - 1
                    }

                    if newIndex >= 0 && newIndex < parentZone.children.count {
                        if selectionOnly {
                            selectionManager.currentlyGrabbedZones = [parentZone.children[newIndex]]

                            controllersManager.signal(parentZone, regarding: .data)
                        } else if travelManager.storageMode != .bookmarks {
                            parentZone.children.remove(at: index)
                            parentZone.children.insert(zone, at:newIndex)
                            parentZone.recomputeOrderingUponInsertionAt(newIndex)

                            if persist {
                                controllersManager.saveAndUpdateFor(parentZone)
                            } else {
                                controllersManager.signal(parentZone, regarding: .data)
                            }
                        }
                    }
                }
            }
        }
    }


    func moveInto(selectionOnly: Bool, extreme: Bool, persist: Bool) {
        if let                                  zone: Zone = selectionManager.firstGrabbableZone {
            if selectionOnly {
                if zone.children.count > 0 {
                    let                           saveThis = !zone.showChildren
                    selectionManager.currentlyGrabbedZones = [asTask ? zone.children.first! : zone.children.last!]
                    zone.showChildren                      = true

                    if saveThis {
                        controllersManager.saveAndUpdateFor(nil)
                    } else {
                        controllersManager.signal(zone.parentZone, regarding: .data)
                    }
                } else if travelManager.storageMode == .bookmarks && zone.cloudZone != nil {
                    travelManager.travelWhereThisZonePoints(zone, atArrival: { (object, kind) -> (Void) in
                        if let _: Zone = object as? Zone {
                            selectionManager.currentlyGrabbedZones = [zone]

                            controllersManager.signal(nil, regarding: .data)
                        }
                    })
                }
            } else if travelManager.storageMode != .bookmarks, let parentZone = zone.parentZone {
                if let                               index = parentZone.children.index(of: zone) {
                    let                       siblingIndex = index == 0 ? 1 : index - 1

                    if siblingIndex                       >= 0 {
                        let                    siblingZone = parentZone.children[siblingIndex]
                        siblingZone.showChildren           = true
                        var                         insert = 0

                        parentZone.children.remove(at: index)
                        parentZone .needsSave()
                        zone       .needsSave()
                        siblingZone.needsSave()

                        if asTask {
                            siblingZone.children.insert(zone, at: 0)
                        } else {
                            insert = siblingZone.children.count
                            
                            siblingZone.children.append(zone)
                        }

                        zone.parentZone                    = siblingZone

                        siblingZone.recomputeOrderingUponInsertionAt(insert)

                        if persist {
                            controllersManager.saveAndUpdateFor(parentZone)
                        } else {
                            controllersManager.signal(parentZone, regarding: .data)
                        }
                    }
                }
            }
        }
    }


    func moveOut(selectionOnly: Bool, extreme: Bool, persist: Bool) {
        if let                              zone: Zone = selectionManager.firstGrabbableZone {
            var                             parentZone = zone.parentZone

            if selectionOnly {
                if parentZone == nil {
                    travelManager.travelWhereThisZonePoints(zone) { object, kind in
                        if let zone: Zone = object as? Zone {
                            selectionManager.currentlyGrabbedZones = [zone]

                            controllersManager.signal(nil, regarding: .data)
                        }
                    }

                    return
                } else if extreme {
                    parentZone                         = travelManager.hereZone
                }

                selectionManager.currentlyGrabbedZones = [parentZone!]

                controllersManager.signal(parentZone, regarding: .data)
            } else if travelManager.storageMode != .bookmarks, let grandParentZone = parentZone?.parentZone {
                let                              index = parentZone?.children.index(of: zone)
                let                             insert = asTask ? 0 : grandParentZone.children.count
                zone.parentZone                        = grandParentZone

                grandParentZone.needsSave()
                parentZone?    .needsSave()
                zone           .needsSave()

                if asTask {
                    grandParentZone.children.insert(zone, at: 0)
                } else {
                    grandParentZone.children.append(zone)
                }

                parentZone?.children.remove(at: index!)
                grandParentZone.recomputeOrderingUponInsertionAt(insert)

                if persist {
                    controllersManager.saveAndUpdateFor(grandParentZone)
                } else {
                    controllersManager.signal(grandParentZone, regarding: .data)
                }
            }
        }
    }
}
