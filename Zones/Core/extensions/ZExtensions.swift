//
//  ZExtensions.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


#if os(iOS)
    import UIKit


    extension ZApplication {
        func presentError(_ error: NSError) -> Void {

        }

        
        func clearBadge() {
            self.applicationIconBadgeNumber += 1
            self.applicationIconBadgeNumber  = 0

            self.cancelAllLocalNotifications()
        }
    }

#elseif os(OSX)
    import Cocoa


    extension ZoneTextField {
        var text: String? {
            get { return stringValue }
            set { stringValue = newValue! }
        }
    }


    extension ZSegmentedControl {
        var selectedSegmentIndex: Int {
            get { return selectedSegment }
            set { selectedSegment = newValue }
        }

    }


    extension String {
        func size(attributes attrs: [String : Any]? = nil) -> NSSize {
            return size(withAttributes:attrs)
        }
    }


    extension ZApplication {
        func clearBadge() {
            self.dockTile.badgeLabel = ""
        }
    }

#endif


typealias ZStorageDict = [String : NSObject]


extension String {

    func sizeWithFont(_ font: ZFont) -> CGSize {
        return self.size(attributes: [NSFontAttributeName: font])
    }


    func heightForFont(_ font: ZFont) -> CGFloat {
        return sizeWithFont(font).height
    }


    func widthForFont(_ font: ZFont) -> CGFloat {
        return sizeWithFont(font).width
    }
}


//extension NSAttributedString {
//    func heightWithConstrainedWidth(width: CGFloat) -> CGFloat {
//        let constraint = CGSize(width: width, height: .greatestFiniteMagnitude)
//        let boundingBox = self.boundingRect(with: constraint, options: .usesLineFragmentOrigin, context: nil)
//
//        return boundingBox.height
//    }
//
//    func widthWithConstrainedHeight(height: CGFloat) -> CGFloat {
//        let constraint = CGSize(width: .greatestFiniteMagnitude, height: height)
//        let boundingBox = self.boundingRect(with: constraint, options: .usesLineFragmentOrigin, context: nil)
//
//        return boundingBox.width
//    }
//}
