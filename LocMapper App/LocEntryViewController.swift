/*
 * LocEntryViewController.swift
 * LocMapper App
 *
 * Created by François Lamboley on 2015-12-02.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa

import LocMapper



class LocEntryViewController: NSTabViewController {
	
	class LocEntry {
		let lineKey: LocFile.LineKey
		let lineValue: LocFile.LineValue
		
		init(lineKey k: LocFile.LineKey, lineValue v: LocFile.LineValue) {
			lineKey = k
			lineValue = v
		}
	}
	
	var dirty: Bool {
		return locEntryMappingViewController.dirty || locEntryAdvancedMappingViewController.dirty
	}
	
	@IBOutlet var tabViewItemContext: NSTabViewItem!
	@IBOutlet var tabViewItemMapping: NSTabViewItem!
	@IBOutlet var tabViewItemAdvancedMapping: NSTabViewItem!
	
	var uiState: [String: Any] {
		/* Todo: See if we need to save UI state for sub-controllers…
		 *       (Too lazy to add them right now.) */
		return ["EntryViewController Selected Tab Index": tabView.selectedTabViewItem.flatMap{ tabView.indexOfTabViewItem($0) } ?? -1]
	}
	
	func restoreUIState(with uiState: [String: Any]) {
		if let idx = uiState["EntryViewController Selected Tab Index"] as? Int, idx >= 0 {
			tabView.selectTabViewItem(at: idx)
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	/* *********************************************************************
	   MARK: - Doc Modification Actions & Handlers
	           Handlers notify the doc object the doc has been modified
	           Actions are called to notify you of a modification of the doc
	   ********************************************************************* */
	
	override var representedObject: Any? {
		didSet {
			locEntryContextViewController.representedObject = representedObject
			locEntryMappingViewController.representedObject = (representedObject as? LocEntry)?.lineValue
			locEntryAdvancedMappingViewController.representedObject = (representedObject as? LocEntry)?.lineValue
		}
	}
	
	var handlerSearchMappingKey: ((_ inputString: String) -> [LocFile.LineKey])? {
		didSet {
			locEntryMappingViewController.handlerSearchMappingKey = handlerSearchMappingKey
		}
	}
	
	var handlerLineKeyToString: ((_ lineKey: LocFile.LineKey) -> String)? {
		didSet {
			locEntryMappingViewController.handlerLineKeyToString = handlerLineKeyToString
		}
	}
	
	var handlerNotifyLineValueModification: (() -> Void)? {
		didSet {
			locEntryMappingViewController.handlerNotifyLineValueModification = { [weak self] in
				guard let strongSelf = self else {return}
				guard let currentLocEntry = strongSelf.representedObject as? LocEntry else {return}
				guard let newLineValue = strongSelf.locEntryMappingViewController.representedObject as? LocFile.LineValue else {return}
				strongSelf.representedObject = LocEntry(lineKey: currentLocEntry.lineKey, lineValue: newLineValue)
				strongSelf.handlerNotifyLineValueModification?()
			}
			locEntryAdvancedMappingViewController.handlerNotifyLineValueModification = { [weak self] in
				guard let strongSelf = self else {return}
				guard let currentLocEntry = strongSelf.representedObject as? LocEntry else {return}
				guard let newLineValue = strongSelf.locEntryAdvancedMappingViewController.representedObject as? LocFile.LineValue else {return}
				strongSelf.representedObject = LocEntry(lineKey: currentLocEntry.lineKey, lineValue: newLineValue)
				strongSelf.handlerNotifyLineValueModification?()
			}
		}
	}
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	override func discardEditing() {
		super.discardEditing()
		
		locEntryMappingViewController.discardEditing()
		locEntryAdvancedMappingViewController.discardEditing()
	}
	
	/* **************************
	   MARK: - NSTabView Delegate
	   ************************** */
	
	override func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
		guard !dirty else {
			if let window = view.window {
				if AppSettings.shared.showAlertForTabChangeDiscardMappingEdition {
					let alert = NSAlert()
					alert.messageText = "Unsaved Changes"
					alert.informativeText = "Your changes will be lost if you change the selected tab."
					alert.addButton(withTitle: "Cancel")
					alert.addButton(withTitle: "Change Anyway")
					alert.showsSuppressionButton = true
					alert.beginSheetModal(for: window) { response in
						switch response {
							case .alertFirstButtonReturn:
								(/*nop (cancel)*/)
								
							case .alertSecondButtonReturn:
								self.discardEditing()
								
								tabView.selectTabViewItem(tabViewItem)
								
								/* Let's check if the user asked not to be bothered by this alert anymore. */
								if (alert.suppressionButton?.state ?? .off) == .on {
									AppSettings.shared.showAlertForTabChangeDiscardMappingEdition = false
								}
								
							default:
								NSLog("%@", "Unknown button response \(response)")
						}
					}
				} else {
					self.discardEditing()
					return super.tabView(tabView, shouldSelect: tabViewItem)
				}
			}
			return false
		}
		return super.tabView(tabView, shouldSelect: tabViewItem)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var locEntryContextViewController: LocEntryContextViewController! {
		return tabViewItemContext.viewController as? LocEntryContextViewController
	}
	
	private var locEntryMappingViewController: LocEntryMappingViewController! {
		return tabViewItemMapping.viewController as? LocEntryMappingViewController
	}
	
	private var locEntryAdvancedMappingViewController: LocEntryAdvancedMappingViewController! {
		return tabViewItemAdvancedMapping.viewController as? LocEntryAdvancedMappingViewController
	}
	
}
