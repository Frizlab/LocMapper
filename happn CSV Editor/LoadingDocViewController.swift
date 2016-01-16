/*
 * LoadingDocViewController.swift
 * Localizer
 *
 * Created by François Lamboley on 12/8/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



class LoadingDocViewController : NSViewController {
	
	@IBOutlet var activityIndicator: NSProgressIndicator!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		activityIndicator.startAnimation(nil)
	}
	
}