/*
 * ColorFixedTextFieldCell.swift
 * Lokalise Project Migration
 *
 * Created by François Lamboley on 2018-08-27.
 * Copyright © 2018 happn. All rights reserved.
 */

import Cocoa
import Foundation



/* Would be great to have an extender for that… */
class ColorFixedTextFieldCell : NSTextFieldCell {
	
	var expectedTextColor: NSColor?
	private var internalSet = false
	
	override var textColor: NSColor? {
		didSet {
			guard !internalSet else {return}
			expectedTextColor = textColor
			updateTextColor()
		}
	}
	
	override var backgroundStyle: NSView.BackgroundStyle {
		didSet {
			updateTextColor()
		}
	}
	
	private func updateTextColor() {
		internalSet = true
		switch backgroundStyle {
			case .lowered, .normal:    textColor = expectedTextColor
			case .raised, .emphasized: textColor = .white
			@unknown default:          textColor = expectedTextColor
		}
		internalSet = false
	}
	
}
