//
//  ZoneWidget.swift
//  Zones
//
//  Created by Jonathan Sand on 10/7/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneWidget: ZView, ZoneTextFieldDelegate {


    @IBOutlet weak var wConstraint: NSLayoutConstraint?
    @IBOutlet weak var hConstraint: NSLayoutConstraint?
    private var         _textField: ZoneTextField!
    var                 widgetZone: Zone!
    private var      _childrenView: ZView!
    let                       font: ZFont = ZFont.userFont(ofSize: 17.0)!


    var hasChildren: Bool {
        get { return widgetZone.children.count > 0 }
    }



    var textField: ZoneTextField {
        get {
            if _textField == nil {
                _textField                      = ZoneTextField()
                _textField.font                 = font
                _textField.delegate             = self
                _textField.alignment            = .center
                _textField.isBordered           = false
                _textField.backgroundColor      = NSColor(cgColor: CGColor.clear)
                _textField.maximumNumberOfLines = 1

                addSubview(_textField)

                _textField.snp.makeConstraints { (make) -> Void in
                    make.width.equalTo(200.0).labeled("text size")
                    make.centerY.left.equalTo(self).labeled("text center and size")
                }
            }

            return _textField
        }
    }


    var childrenView: ZView {
        get {
            if _childrenView == nil && hasChildren {
                _childrenView = ZView()

                addSubview(_childrenView)

                _childrenView.snp.makeConstraints { (make) -> Void in
                    make.height.equalTo(400.0).labeled("children height")
                }

                snp.makeConstraints { (make) -> Void in
                    make.centerY.height.right.equalTo(_childrenView).labeled("children centerY height right")
                }
            }

            return _childrenView
        }
    }


    func captureText() {
        widgetZone.zoneName = textField.text!
    }


    func updateInView(_ inView: ZView) -> CGRect {
        if !inView.subviews.contains(self) {
            inView.addSubview(self)

            snp.remakeConstraints { (make) -> Void in
                make.center.equalTo(inView).labeled("view center")
            }
        }

        if hConstraint != nil {
            removeConstraint(hConstraint!)
        }

        if wConstraint != nil {
            removeConstraint(wConstraint!)
        }

        layoutWithText(widgetZone.zoneName)

        return frame
    }


    func layoutWithText(_ value: String?) {
        if value != nil {
            textField.text = value

            updateLayout()
        }
    }


    func updateLayout() {
        textField.snp.removeConstraints()
        textField.snp.makeConstraints { (make) -> Void in
            let width = textField.text!.widthForFont(font) + 10.0

            make.width.equalTo(width).labeled("text width")
            make.centerY.left.equalTo(self).labeled("text center and size")

            if hasChildren {
                make.right.equalTo(childrenView.snp.left).offset(-stateManager.genericOffset.width)
            }
        }

        updateConstraints()
        textField.addBorder(thickness: 5.0, fractionalRadius: 0.5, color: CGColor.black)
        childrenView.addBorder(thickness: 1.0, fractionalRadius: 0.5, color: CGColor.black)
    }

    // MARK:- delegates
    // MARK:-


#if os(OSX)

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        captureText()

        return true
    }


    override func controlTextDidChange(_ obj: Notification) {
        updateLayout()
    }

#elseif os(iOS)

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        captureText()

        return true
    }


//    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
//        updateLayout()
//
//        return true
//    }

#endif
}
