/*
 * LocFileDocTabViewController.swift
 * LocMapper App
 *
 * Created by François Lamboley on 2015-12-08.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



class LocFileDocTabViewController : NSTabViewController {
	
	@IBOutlet var tabViewItemDocContent: NSTabViewItem!
	
	var uiState: [String: Any] {
		return optionsSplitViewController.uiState /* No custom UI state for us, we return the UI state of the options split view controller */
	}
	
	func restoreUIState(with uiState: [String: Any]) {
		optionsSplitViewController.restoreUIState(with: uiState)
	}
	
	/* *********************************************************************
	   MARK: - Doc Modification Actions & Handlers
	           Handlers notify the doc object the doc has been modified
	           Actions are called to notify you of a modification of the doc
	   ********************************************************************* */
	
	override var representedObject: Any? {
		didSet {
			optionsSplitViewController.representedObject = representedObject
			if representedObject == nil {self.selectedTabViewItemIndex = 0}
			else                        {self.selectedTabViewItemIndex = 1}
		}
	}
	
	/** Changes after view did load are ignored. */
	var handlerNotifyDocumentModification: (() -> Void)? {
		didSet {
			optionsSplitViewController.handlerNotifyDocumentModification = handlerNotifyDocumentModification
		}
	}
	
	func noteContentHasChanged() {
		optionsSplitViewController.noteContentHasChanged()
	}
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	@IBAction func showFilters(_ sender: AnyObject!) {
		optionsSplitViewController.showFilters(sender)
	}
	
	@IBAction func showEntryDetails(_ sender: AnyObject!) {
		optionsSplitViewController.showEntryDetails(sender)
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var optionsSplitViewController: LocFileDocFiltersSplitViewController! {
		return tabViewItemDocContent.viewController as? LocFileDocFiltersSplitViewController
	}
	
}
