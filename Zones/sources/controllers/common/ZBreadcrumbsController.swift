//
//  ZBreadcrumbsController.swift
//  Zones
//
//  Created by Jonathan Sand on 2/14/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

var gBreadcrumbsController: ZBreadcrumbsController? { return gControllers.controllerForID(.idCrumbs) as? ZBreadcrumbsController }

class ZBreadcrumbsController: ZGenericController {

	@IBOutlet var  crumbsLabel : ZBreadcrumbsView?
	override  var controllerID : ZControllerID { return .idCrumbs     }

	override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
		crumbsLabel?.updateAndRedraw()
	}

}
