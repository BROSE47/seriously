//
//  ZEssay.swift
//  Zones
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

class ZEssay: ZParagraph {
	var essayRange: NSRange { return NSRange(location: 0, length: essayLength) }
	override var lastTextIsDefault: Bool { return children.last?.lastTextIsDefault ?? false }

	override var lastTextRange: NSRange? {
		if  let    last = children.last {
			return last.textRange.offsetBy(last.paragraphOffset)
		}

		return nil
	}

	func setupChildren() {
		if  gCreateMultipleEssay {
			zone?.traverseAllProgeny {   iChild in
				if  iChild.hasTrait(for: .eEssay) { // do not use essayMaybe as it may not yet be initialized
					self.children.append(iChild.essay)
				}
			}
		}
	}

	override var essayText: NSMutableAttributedString? {
		var result: NSMutableAttributedString?
		var count  = children.count

		if  count == 0 {    // the first time
			let        e = ZParagraph(zone)

			if  let text = e.paragraphText {
				result?.insert(text, at: 0)
			}
		} else {
			for child in children.reversed() {
				count         -= 1

				if  let   text = child.paragraphText {
					result     = result ?? NSMutableAttributedString()
					result?.insert(gBlankLine, at: 0)
					result?.insert(text,       at: 0)
				}
			}

			var offset = 0

			for child in children {	// update essayIndices
				child.paragraphOffset = offset
				offset               += child.textRange.upperBound + gBlankLine.length

				if  let     z = child.zone, z.colorized,
					let color = z.color?.lighter(by: 20.0) {

					result?.addAttribute(.backgroundColor, value: color, range: child.fullTitleRange)
				}
			}
		}

		essayLength = result?.length ?? 0

		result?.fixAllAttributes()

		return result
	}

	override func saveEssay(_ attributedString: NSAttributedString?) {
		if  let attributed  = attributedString {
			for child in children {
				let range   = child.paragraphRange

				if  range.upperBound <= attributed.length {
					let sub = attributed.attributedSubstring(from: range)

					child.saveParagraph(sub)
				}
			}
		}

		gControllers.syncAndRedraw()
	}

	override func updateEssay(_ range:NSRange, length: Int) -> (ZAlterationType, Int) {
		let equal  = range.inclusiveIntersection(essayRange) == essayRange
		var result = ZAlterationType.eLock
		var adjust = 0
		var offset : Int?

		for child in children {
			if  equal {
				adjust    -= child.paragraphRange.length

				child.delete()
			} else {
				let (alter,  delta) = child.updateParagraph(range, length: length, adjustment: adjust)
				adjust    += delta

				if  alter != .eLock {
					result = .eAlter

					if  alter == .eDelete {
						offset = child.paragraphOffset
					}
				}
			}
		}

		if  equal {
			result = .eExit
		} else if let o = offset {
			result = .eDelete
			adjust = o
		}

		return (result, adjust)
	}

	override func updateFontSize(_ increment: Bool) -> Bool {
		var updated = false

		for child in children {
		    updated = child.updateTraitFontSize(increment) || updated
		}

		return updated
	}

}
