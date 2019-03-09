//
//  ZDetailsController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


var gDetailsController : ZDetailsController? { return gControllers.controllerForID(.details) as? ZDetailsController }


class ZDetailsController: ZGenericController {


    @IBOutlet var stackView: ZStackView?
    var viewsByID = [Int: ZStackableView]()
    override  var controllerID: ZControllerID { return .details }


    override func setup() {
        useDefaultBackgroundColor = false
    }
    
    
    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        update()
    }

    
    func register(id: ZDetailsViewID, for view: ZStackableView) {
        viewsByID[id.rawValue] = view
    }
    

    func update() {
        let ids: [ZDetailsViewID] = [.Tools, .Debug, .Preferences, .Information]

        for id in ids {
            view(for: id)?.update()
        }
    }
    
    
    func view(for id: ZDetailsViewID) -> ZStackableView? {
        return viewsByID[id.rawValue]
    }
    
    
    func toggleViewsFor(ids: [ZDetailsViewID]) {
        for id in ids {
            if  let v = view(for: id) {
                v.toggleHideableVisibility()
            }
        }
        
        update()
    }

    
    func displayViewsFor(ids: [ZDetailsViewID]) {
        for id in ids {
            gHiddenDetailViewIDs.remove(id)
        }

        update()
    }
}
