//
//  ZGenericController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

class ZGenericController: ZController {

	var controllerID    : ZControllerID { return .idUndefined }
    var backgroundColor : CGColor       { return kClearColor.cgColor }
    func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {}
	func setup() {}

    override func viewDidLoad() {
        super.viewDidLoad()

        gControllers.setSignalHandler(for: self, iID: controllerID) { object, kind in
			self.view.zlayer.backgroundColor = self.backgroundColor

            if  kind != .eError && gIsReadyToShowUI {
                self.handleSignal(object, kind: kind)
            }
        }

        setup()
    }

#if os(OSX)

    override func viewDidAppear() {
        super.viewDidAppear()
        setup()
    }

#elseif os(iOS)

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setup()
    }

#endif

}
