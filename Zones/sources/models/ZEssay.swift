//
//  ZEssay.swift
//  Zones
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

class ZEssay: ZEssayPart {
	var children = [ZEssayPart]()

	func setupChildren() {
		zone?.traverseAllProgeny {   iChild in
			if  iChild.hasTrait(for: .eEssay) {
				self.children.append(iChild.essay)
			}
		}
	}

	override var essayText: NSMutableAttributedString? {
		var result: NSMutableAttributedString?
		var count  = children.count
		var offset = 0

		for child in children.reversed() {
			count         -= 1

			if  let   text = child.partialText {
				result     = NSMutableAttributedString()
				result?.insert(text, at: 0)

				if  count != 0 {
					result?.insert(blankLine, at: 0)
				}
			}
		}

		if  result == nil {    // detect when no partial text has been added
			let   e = ZEssayPart(zone)

			if  let text = e.partialText {
				result?.insert(text, at: 0)
			}
		}

		for child in children {	// update essayIndices
			child.partOffset = offset
			offset          += child.textRange.upperBound
		}

		return result
	}

	override func save(_ attributedString: NSAttributedString?) {
		if  let  attributed = attributedString {
			for child in children {
				let sub = attributed.attributedSubstring(from: child.partRange)

				if  child == self {
					super.save(sub)
				} else {
					child.save(sub)
				}
			}
		}
	}

	override func update(_ range:NSRange, length: Int) -> ZAlterationType {
		var result = ZAlterationType.eAlter
		let equal  = range.inclusiveIntersection(partRange) == partRange

		for child in children {
			if  equal {
				child.delete()
			} else {
				var alter = ZAlterationType.eAlter

				if  self == child {
					alter = super.updatePart(range, length: length)
				} else {
					alter = child.updatePart(range, length: length)
				}

				if  alter == .eLock {
					result = .eLock

					break
				}
			}
		}

		if  equal {
			result = .eDelete
			gEssayEditor.swapGraphAndEssay()
		}

		return 	result
	}

}
