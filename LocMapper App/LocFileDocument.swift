/*
 * LocFileDocument.swift
 * LocMapper App
 *
 * Created by François Lamboley on 2015-12-02.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa
import os.log

import LocMapper



private extension NSStoryboard.Name {
	
	static let main = "Main"
	
}

private extension NSStoryboard.SceneIdentifier {
	
	static let documentWindowController = "Document Window Controller"
	
}

private extension NSNib.Name {
	
	static let accessoryViewForImportReferenceTranslations = "AccessoryViewForImportReferenceTranslations"
	static let accessoryViewForImportKeyStructure = "AccessoryViewForImportKeyStructure"
	
}

class LocFileDocument: NSDocument, NSTokenFieldDelegate {
	
	/** If nil, the file is loading. */
	var csvLocFile: LocFile? {
		didSet {
			sendRepresentedObjectToSubControllers(csvLocFile)
		}
	}
	
	override init() {
		csvLocFile = LocFile()
		super.init()
	}
	
	override func windowControllerDidLoadNib(_ aController: NSWindowController) {
		super.windowControllerDidLoadNib(aController)
	}
	
	override class var autosavesInPlace: Bool {
		return false
	}
	
	override func makeWindowControllers() {
		let storyboard = NSStoryboard(name: .main, bundle: nil)
		let windowController = storyboard.instantiateController(withIdentifier: .documentWindowController) as! NSWindowController
		addWindowController(windowController)
		
		mainViewController.handlerNotifyDocumentModification = { [weak self] in
			self?.updateChangeCount(.changeDone)
		}
		
		sendRepresentedObjectToSubControllers(csvLocFile)
		
		if let windowFrame = windowFrameToRestore {
			windowController.window?.setFrame(from: windowFrame)
			windowFrameToRestore = nil
		}
		if let uiState = uiStateToRestore {
			mainViewController.restoreUIState(with: uiState)
		}
	}
	
	override func write(to url: URL, ofType typeName: String) throws {
		/* Let's save the UI state */
		if let frameStr = mainWindowController?.window?.frameDescriptor {csvLocFile?.setMetadataValue(frameStr, forKey: "UIWindowFrame")}
		else                                                            {csvLocFile?.removeMetadata(forKey: "UIWindowFrame")}
		do {try csvLocFile?.setMetadataValue(mainViewController.uiState, forKey: "UIState")}
		catch {
			os_log("Cannot save UIState metadata", type: .info)
		}
		
		/* We ask super to write the file.
		 * In effect this will call the method below to get the data to write in the file, then write those data. */
		try super.write(to: url, ofType: typeName)
		
		/* We still need to save the metadata which are not saved in the data (anymore; we used to save them along the data). */
		guard let metadata = csvLocFile?.serializedMetadata() else {return}
		metadata.withUnsafeBytes{ (ptr: UnsafeRawBufferPointer) -> Void in
			setxattr(url.absoluteURL.path, xattrMetadataName, ptr.baseAddress!, metadata.count, 0 /* Reserved, should be 0 */, 0 /* No options */)
		}
	}
	
	override func data(ofType typeName: String) throws -> Data {
		guard let csvLocFile = csvLocFile else {
			return Data()
		}
		
		var strData = ""
		csvLocFile.serializationStyle = .gitFriendly
		Swift.print(csvLocFile, terminator: "", to: &strData)
		return Data(strData.utf8)
	}
	
	override func read(from url: URL, ofType typeName: String) throws {
		assert(unserializedMetadata == nil)
		
		if url.isFileURL {
			let s = getxattr(url.absoluteURL.path, xattrMetadataName, nil, 0 /* Size */, 0 /* Reserved, should be 0 */, 0 /* No options */)
			if s >= 0 {
				/* We have the size of the xattr we want to read. Let's read it. */
				var serializedMetadata = Data(count: s)
				let s2 = serializedMetadata.withUnsafeMutableBytes{ (ptr: UnsafeMutableRawBufferPointer) -> Int in
					return getxattr(url.absoluteURL.path, xattrMetadataName, ptr.baseAddress!, s, 0 /* Reserved, should be 0 */, 0 /* No options */)
				}
				if s2 >= 0 {
					/* We have read the xattr. Let's unserialize them! */
					unserializedMetadata = LocFile.unserializedMetadata(from: serializedMetadata)
				}
			}
			
			windowFrameToRestore = (unserializedMetadata as? [String: Any?])?["UIWindowFrame"] as? String
			
			let uiState = (unserializedMetadata as? [String: Any?])?["UIState"] as? String
			uiStateToRestore = uiState.flatMap{ (try? JSONSerialization.jsonObject(with: Data($0.utf8), options: [])) as? [String: Any] }
		}
		
		try super.read(from: url, ofType: typeName)
	}
	
	override func read(from data: Data, ofType typeName: String) throws {
		/* Note: We may wanna move this in the read from url method (above) so
		 *       the reading of the file is also done asynchronously to
		 *       avoid blocking when big files or files on slow networks are opened. */
		let metadata = unserializedMetadata
		unserializedMetadata = nil
		csvLocFile = nil
		DispatchQueue.global(qos: .userInitiated).async{
			do {
				let locFile = try LocFile(filecontent: data, csvSeparator: ",", metadata: metadata)
				DispatchQueue.main.async{ self.csvLocFile = locFile }
			} catch {
				DispatchQueue.main.async{
					let alert = NSAlert(error: error as NSError)
					alert.runModal()
					self.close()
				}
			}
		}
	}
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	@IBAction func importReferenceTranslations(sender: AnyObject) {
		guard currentOpenPanel == nil, let csvLocFile = csvLocFile else {
			NSSound.beep()
			return
		}
		
		/* Getting accessory view. */
		var objects: NSArray?
		Bundle.main.loadNibNamed(.accessoryViewForImportReferenceTranslations, owner: nil, topLevelObjects: &objects)
		let accessoryView = (objects ?? []).compactMap{ $0 as? NSView }.first!
		let tokenField = accessoryView.viewWithTag(1) as! NSTokenField
		
		tokenField.delegate = self
		tokenField.stringValue = csvLocFile.languages.joined(separator: ",")
		
		let openPanel = NSOpenPanel()
		currentOpenPanel = openPanel
		
		openPanel.canChooseFiles = true
		openPanel.allowedFileTypes = ["csv"]
		openPanel.canChooseDirectories = false
		if let u = latestURLToRefLocDir {openPanel.directoryURL = u}
		
		configureAccessoryView(accessoryView, forOpenPanel: openPanel)
		
		openPanel.beginSheetModal(for: windowForSheet!){ response in
			self.currentOpenPanel = nil
			guard response == .OK, let url = openPanel.url else {return}
			
			if url != self.latestURLToRefLocDir {
				self.latestURLToRefLocDir = url
				self.updateChangeCount(.changeDone)
			}
			
			let loadingWindow = UINavigationUtilities.createLoadingWindow()
			self.windowForSheet?.beginSheet(loadingWindow, completionHandler: nil)
			
			let languages = tokenField.stringValue.split(separator: ",").map(String.init)
			DispatchQueue.global().async {
				defer {
					DispatchQueue.main.async {
						self.mainViewController.noteContentHasChanged()
						self.windowForSheet?.endSheet(loadingWindow)
						self.updateChangeCount(.changeDone)
					}
				}
				
				do {
					let referenceTranslations = try XibRefLocFile(fromURL: url, languages: languages, csvSeparator: ",")
					csvLocFile.mergeRefLocsWithXibRefLocFile(referenceTranslations, mergeStyle: .add)
				} catch let error {
					DispatchQueue.main.async {
						NSAlert(error: error as NSError).beginSheetModal(for: self.windowForSheet!, completionHandler: nil)
					}
				}
			}
		}
	}
	
	@IBAction func importKeyStructure(sender: AnyObject) {
		guard currentOpenPanel == nil, let csvLocFile = csvLocFile else {
			NSSound.beep()
			return
		}
		
		let openPanel = NSOpenPanel()
		if let u = latestURLToKeyStructureImport {openPanel.directoryURL = u}
		
		/* Getting accessory view. */
		let controller = ImportKeyStructurePanelController(nibName: .accessoryViewForImportKeyStructure, bundle: nil, csvLocFile: csvLocFile, openPanel: openPanel)!
		
		currentOpenPanel = openPanel
		configureAccessoryView(controller.view, forOpenPanel: openPanel)
		
		openPanel.beginSheetModal(for: windowForSheet!){ response in
			assert(Thread.isMainThread)
			
			openPanel.accessoryView = nil /* Fixes a crash... (macOS 10.12 (16A239j) */
			self.currentOpenPanel = nil
			
			guard response == .OK else {return}
			
			if let url = openPanel.url {self.latestURLToKeyStructureImport = url}
			controller.saveImportSettings()
			self.updateChangeCount(.changeDone)
			
			/* Let's fetch all the data from the controller before dispatching async as we want the controller to be released on the main thread. */
			let selectedImportType = controller.selectedImportType
			let excludedPaths = controller.excludedPaths
			let languageName = controller.importedLanguageName
			let importedFolder = controller.importedFolderForXcode
			
			let loadingWindow = UINavigationUtilities.createLoadingWindow()
			self.windowForSheet?.beginSheet(loadingWindow, completionHandler: nil)
			
			let url = openPanel.url
			let urls = openPanel.urls
			
			DispatchQueue.global().async{
				defer {
					DispatchQueue.main.async{
						self.mainViewController.noteContentHasChanged()
						self.windowForSheet?.endSheet(loadingWindow)
						self.updateChangeCount(.changeDone)
					}
				}
				
				do {
					switch selectedImportType {
						case .Xcode:
							guard let url = url else {return}
							let stringsFiles = try XcodeStringsFile.stringsFilesInProject(url.absoluteURL.path, excludedPaths: excludedPaths, includedPaths: ["/"+importedFolder+"/"])
							csvLocFile.mergeXcodeStringsFiles(stringsFiles, folderNameToLanguageName: [importedFolder: languageName])
							
						case .Android:
							for url in urls {
								let urlPath = url.absoluteURL.path
								let noFilename = url.deletingLastPathComponent()
								let folderName = noFilename.lastPathComponent
								let noFolderName = noFilename.deletingLastPathComponent()
								let relativePath = "./" + urlPath.dropFirst(noFolderName.absoluteURL.path.count + 1)
								if let androidXMLLocFile = try? AndroidXMLLocFile(fromPath: relativePath, relativeToProjectPath: noFolderName.absoluteURL.path) {
									csvLocFile.mergeAndroidXMLLocStringsFiles([androidXMLLocFile], folderNameToLanguageName: [folderName: languageName])
								}
							}
					}
				} catch {
					DispatchQueue.main.async{
						NSAlert(error: error as NSError).beginSheetModal(for: self.windowForSheet!, completionHandler: nil)
					}
				}
			}
		}
	}
	
	@IBAction func exportTranslations(sender: AnyObject) {
		let alert = NSAlert()
		alert.messageText = "Unimplemented"
		alert.informativeText = "This feature has not yet been implemented. Please check with the dev!"
		alert.addButton(withTitle: "OK")
		alert.beginSheetModal(for: windowForSheet!, completionHandler: nil)
	}
	
	/* ****************************
	   MARK: - Token Field Delegate
	   **************************** */
	
	/* Implementing this method disables the whitespace-trimming behavior. */
	func tokenField(_ tokenField: NSTokenField, representedObjectForEditing editingString: String) -> Any? {
		return editingString
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let xattrMetadataName = "fr.ftw-and-co.LocMapperApp.LocFile.doc-metadata"
	private var uiStateToRestore: [String: Any]?
	private var windowFrameToRestore: String?
	private var unserializedMetadata: Any?
	
	private var currentOpenPanel: NSOpenPanel?
	
	private var latestURLToKeyStructureImport: URL? {
		get {return csvLocFile?.urlMetadataValueForKey("Key Structure Import — Latest Dir")}
		set {
			if let v = newValue {csvLocFile?.setMetadataValue(v, forKey: "Key Structure Import — Latest Dir")}
			else                {csvLocFile?.removeMetadata(forKey: "Key Structure Import — Latest Dir")}
		}
	}
	private var latestURLToRefLocDir: URL? {
		get {return csvLocFile?.urlMetadataValueForKey("RefLoc Import — Latest Dir")}
		set {
			if let v = newValue {csvLocFile?.setMetadataValue(v, forKey: "RefLoc Import — Latest Dir")}
			else                {csvLocFile?.removeMetadata(forKey: "RefLoc Import — Latest Dir")}
		}
	}
	
	private func sendRepresentedObjectToSubControllers(_ object: AnyObject?) {
		for w in windowControllers {
			w.contentViewController?.representedObject = csvLocFile
		}
	}
	
	private func configureAccessoryView(_ accessoryView: NSView, forOpenPanel openPanel: NSOpenPanel) {
		openPanel.accessoryView = accessoryView
		openPanel.isAccessoryViewDisclosed = true
		if let superview = accessoryView.superview {
			/* Adjust size of accessory view. */
			accessoryView.frame.origin.x = superview.bounds.minX
			accessoryView.frame.size.width = superview.bounds.width
			accessoryView.autoresizingMask = [.width] /* Doesn't work though :( */
		}
	}
	
	/* **********
	   MARK: → UI
	   ********** */
	
	/* Root Window Controller */
	
	private var mainWindowController: NSWindowController! {
		return windowControllers.first
	}
	
	/* Document Root & Loading UI */
	
	private var mainViewController: LocFileDocTabViewController! {
		return mainWindowController.contentViewController as? LocFileDocTabViewController
	}
	
	/* Left Pane (Filters) */
	
	private var filtersSplitViewController: LocFileDocFiltersSplitViewController! {
		return mainViewController.tabViewItemDocContent.viewController as? LocFileDocFiltersSplitViewController
	}
	
	private var filtersViewController: LocFileDocFiltersViewController! {
		return filtersSplitViewController.splitItemFilters.viewController as? LocFileDocFiltersViewController
	}
	
	/* Top-Right Pane (Translations) */
	
	private var contentSplitViewController: LocFileDocContentSplitViewController! {
		return filtersSplitViewController.splitItemContent.viewController as? LocFileDocContentSplitViewController
	}
	
	private var tableViewController: LocFileDocTableViewController! {
		return contentSplitViewController.splitItemTableView.viewController as? LocFileDocTableViewController
	}
	
	/* Bottom-Right Pane (Details) */
	
	private var locEntrySplitViewController: LocEntryViewController! {
		return contentSplitViewController.splitItemLocEntry.viewController as? LocEntryViewController
	}
	
	private var locEntryContextViewController: LocEntryContextViewController! {
		return locEntrySplitViewController.tabViewItemContext.viewController as? LocEntryContextViewController
	}
	
	private var locEntryMappingViewController: LocEntryMappingViewController! {
		return locEntrySplitViewController.tabViewItemMapping.viewController as? LocEntryMappingViewController
	}
	
	private var locEntryAdvancedMappingViewController: LocEntryAdvancedMappingViewController! {
		return locEntrySplitViewController.tabViewItemAdvancedMapping.viewController as? LocEntryAdvancedMappingViewController
	}
	
}
