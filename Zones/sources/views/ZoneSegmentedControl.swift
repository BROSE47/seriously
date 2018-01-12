//
//  ZoneSegmentedControl.swift
//  Zones
//
//  Created by Jonathan Sand on 9/25/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import UIKit


class ZoneSegmentedControl : ZSegmentedControl {


    override func awakeFromNib() {
        super.awakeFromNib()

        let image = ZImage(named: "segmented control divider.jpg")

        setDividerImage(image, forLeftSegmentState:   .normal, rightSegmentState:   .normal, barMetrics: .default)
        setDividerImage(image, forLeftSegmentState:   .normal, rightSegmentState: .selected, barMetrics: .default)
        setDividerImage(image, forLeftSegmentState: .selected, rightSegmentState:   .normal, barMetrics: .default)

        setTitleTextAttributes([NSFontAttributeName : gWidgetFont], for: .normal)
    }

}
