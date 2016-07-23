/*
 * happnLocCSVDocTableViewController.swift
 * Localizer
 *
 * Created by François Lamboley on 12/8/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



class happnLocCSVDocTableViewController : NSViewController, NSTableViewDataSource, NSTableViewDelegate {
	
	@IBOutlet var tableView: NSTableView!
	
	private var tableColumnsCreated = false
	
	private var csvLocFile: happnCSVLocFile? {
		return representedObject as? happnCSVLocFile
	}
	
	private var sortedKeys: [happnCSVLocFile.LineKey]?
	private let cachedRowsHeights = Cache<NSString, NSNumber>()
	
	override var representedObject: AnyObject? {
		didSet {
			if let csvLocFile = csvLocFile {sortedKeys = csvLocFile.entryKeys.sorted()}
			else                           {sortedKeys = nil}
			
			tableColumnsCreated = false
			createTableViewColumnsIfNeeded()
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		createTableViewColumnsIfNeeded()
	}
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		precondition(tableView == self.tableView)
		
		if let sortedKeys = sortedKeys {return sortedKeys.count}
		return 0
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
		guard let tableColumn = tableColumn else {return nil}
		guard let csvLocFile = csvLocFile, let key = sortedKeys?[row] else {return nil}
		return csvLocFile.resolvedValueForKey(key, withLanguage: tableColumn.identifier).replacingOccurrences(of: "\\n", with: "\n")
	}
	
	func tableView(_ tableView: NSTableView, setObjectValue object: AnyObject?, for tableColumn: NSTableColumn?, row: Int) {
		guard let csvLocFile = csvLocFile, let key = sortedKeys?[row] else {return}
		guard let tableColumn = tableColumn else {return}
		
		guard let strValue = (object as? String)?.replacingOccurrences(of: "\n", with: "\\n") else {return}
		_ = csvLocFile.setValue(strValue, forKey: key, withLanguage: tableColumn.identifier)
		
		DispatchQueue.main.async {
			tableView.beginUpdates()
			self.cachedRowsHeights.removeObject(forKey: key.filename + key.locKey)
			tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
			tableView.endUpdates()
		}
	}
	
	func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
		/* Based on https://gist.github.com/billymeltdown/9084884 */
		let minimumHeight = CGFloat(3)
		guard let csvLocFile = csvLocFile, let key = sortedKeys?[row] else {return minimumHeight}
		
		/* Check the cache to avoid unnecessary recalculation */
		if let cachedRowHeight = cachedRowsHeights.object(forKey: key.filename + key.locKey) as? CGFloat {
			return cachedRowHeight
		}
		
		var height = minimumHeight
		for column in tableView.tableColumns {
			let str = csvLocFile.resolvedValueForKey(key, withLanguage: column.identifier).replacingOccurrences(of: "\\n", with: "\n")
			let cell = column.dataCell as! NSCell
			cell.stringValue = str
			let rect = NSMakeRect(0, 0, column.width, CGFloat.greatestFiniteMagnitude)
			height = max(height, cell.cellSize(forBounds: rect).height)
		}
		/* To have height being a multiple of minimum height, use this:
		if (height > minimumHeight) {
			let remainder = fmod(height, minimumHeight);
			height -= remainder;
			if remainder > 0 {height += minimumHeight}
		}*/
		
		/* Add small margin to make things a little more beautiful. */
		height += 2*2
		
		/* Let’s cache the result. */
		cachedRowsHeights.setObject(height, forKey: key.filename + key.locKey)
		
		return height
	}
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		print("hello")
	}
	
	/* If we were view-based... but we're not (cell-based is still faster). */
//	func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
//		guard let tableColumn = tableColumn else {return nil}
//		guard let csvLocFile = csvLocFile, key = sortedKeys?[row] else {return nil}
//		
//		let identifier = "LocEntryCell"
//		
//		let result: NSTextField
//		if let r = tableView.makeViewWithIdentifier(identifier, owner: self) as? NSTextField {result = r}
//		else {
//			result = NSTextField(frame: NSZeroRect)
//			result.bordered = false
//			result.drawsBackground = false
//			result.identifier = identifier
//		}
//		
//		result.stringValue = csvLocFile.entries[key]?[tableColumn.identifier] ?? "TODOLOC"
//		return result
//	}
	
	private func createTableViewColumnsIfNeeded() {
		guard !tableColumnsCreated else {return}
		guard let tableView = tableView else {return}
		
		for tc in tableView.tableColumns {
			tableView.removeTableColumn(tc)
		}
		
		guard let csvLocFile = csvLocFile else {return}
		
		for l in csvLocFile.languages {
			let tc = NSTableColumn(identifier: l)
			tc.title = l
			let tfc = NSTextFieldCell(textCell: "TODOLOC")
			tfc.isEditable = true
			tfc.wraps = true
			tc.dataCell = tfc
			tc.width = 350
			tc.resizingMask = .userResizingMask
			tableView.addTableColumn(tc)
		}
		
		tableColumnsCreated = true
		tableView.reloadData()
	}
	
}
