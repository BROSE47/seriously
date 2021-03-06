//
//  ZEssay.swift
//  Zones
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

class ZEssay: ZNote {
	var essayRange: NSRange { return NSRange(location: 0, length: essayLength) }
	override var lastTextIsDefault: Bool { return children.last?.lastTextIsDefault ?? false }
	override var prefix: String { return "essay" }

	override var lastTextRange: NSRange? {
		if  let    last = children.last {
			return last.textRange.offsetBy(last.noteOffset)
		}

		return nil
	}

	override var essayText: NSMutableAttributedString? {
		gCreateCombinedEssay = true

		setupChildren()

		var result: NSMutableAttributedString?
		var index  = children.count

		if  index == 0 {    // the first time
			let     note = ZNote(zone)

			if  let text = note.noteText {
				result?.insert(text, at: 0)
			}
		} else {
			for child in children.reversed() {
				index        -= 1
				let 	 bump = gBlankLine.length

				if  let  text = child.noteText {
					result    = result ?? NSMutableAttributedString()
					result?.insert(gBlankLine, at: 0)
					result?.insert(text,       at: 0)

					if  index > 0 {
						result?.insert(gBlankLine, at: 0)
						child.bumpOffsets(by: bump)
					}
				}
			}

			updateOffsets()
		}

		essayLength = result?.length ?? 0

		result?.fixAllAttributes()

		return result
	}

	static func swobject(for id: String) -> NSObject? {
		if  let       zone = gRemoteStorage.maybeZoneForRecordName(id),
			zone.hasTrait(for: .tNote) {
			let       note = ZNote(zone)
			zone.noteMaybe = note

			return note
		}

		return nil
	}

	override func setupChildren() {
		if  gCreateCombinedEssay {
			children.removeAll()

			zone?.traverseAllProgeny { iChild in
				if  iChild.hasTrait(for: .tNote) {
					let essay = iChild.note

					if !self.children.contains(essay) {
						self.children.append(essay)	// do not use essayMaybe as it may not yet be initialized
					}
				}
			}
		}
	}

	override func updateOffsets() {
		var offset = 0

		for child in children {				// update note offsets
			child.noteOffset = offset
			offset           = child.offsetTextRange.upperBound + gBlankLine.length
		}
	}

	override func saveEssay(_ attributedString: NSAttributedString?) {
		if  let attributed  = attributedString {
			for child in children {
				let range   = child.noteRange

				if  range.upperBound <= attributed.length {
					let sub = attributed.attributedSubstring(from: range)

					child.saveNote(sub)
				}
			}
		}

		gControllers.redrawAndSync()
	}

	override func shouldAlterEssay(_ range:NSRange, length: Int) -> (ZAlterationType, Int) {
		let equal  = range.inclusiveIntersection(essayRange) == essayRange
		var result = ZAlterationType.eLock
		var adjust = 0
		var offset : Int?

		for child in children {
			if  equal {
				adjust    -= child.noteRange.length

				child.delete()
			} else {
				let (alter,  delta) = child.shouldAlterNote(range, length: length, adjustment: adjust)
				adjust    += delta

				if  alter != .eLock {
					result = .eAlter

					if  alter == .eDelete {
						offset = child.noteOffset
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
