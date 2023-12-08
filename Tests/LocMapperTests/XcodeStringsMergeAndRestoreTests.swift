/*
 * XcodeStringsMergeAndRestoreTests.swift
 * LocMapperTests
 *
 * Created by François Lamboley on 2023-12-08.
 * Copyright © 2023 François Lamboley. All rights reserved.
 */

import XCTest
@testable import LocMapper



final class XcodeStringsMergeAndRestoreTests : XCTestCase {
	
	func testStandardCase() throws {
		let filename = "./whatever.strings"
		let filecontent = """
			"hello"/*yeay*//*super happy*/=//oneline comment
			"Hello!";
			"""
		let expectedFilecontent = """
			"hello"/*yeay*//*super happy*/=//oneline comment
			"!¡!TODOLOC!¡!";
			
			"""
		let parsed = try XcodeStringsFile(filepath: filename, filecontent: filecontent)
		let locFile = LocFile()
		locFile.mergeXcodeStringsFiles([parsed], folderNameToLanguageName: [:])
		let files = try exportXcodeAndGetFilesContent(locFile)
		XCTAssertEqual(files, [filename: expectedFilecontent])
	}
	
	func testKeyButNotValues() throws {
		let filename = "./whatever.strings"
		let filecontent = "this_is_weird_but_valid;"
		let expectedFilecontent = #"this_is_weird_but_valid = "!¡!TODOLOC!¡!";\#n"#
		let parsed = try XcodeStringsFile(filepath: filename, filecontent: filecontent)
		let locFile = LocFile()
		locFile.mergeXcodeStringsFiles([parsed], folderNameToLanguageName: [:])
		let files = try exportXcodeAndGetFilesContent(locFile)
		XCTAssertEqual(files, [filename: expectedFilecontent])
	}
	
	func testKeyButNotValues2() throws {
		let filename = "./whatever.strings"
		let filecontent = "this_is_weird_but_valid  ;"
		let expectedFilecontent = #"this_is_weird_but_valid = "!¡!TODOLOC!¡!"  ;\#n"#
		let parsed = try XcodeStringsFile(filepath: filename, filecontent: filecontent)
		let locFile = LocFile()
		locFile.mergeXcodeStringsFiles([parsed], folderNameToLanguageName: [:])
		let files = try exportXcodeAndGetFilesContent(locFile)
		XCTAssertEqual(files, [filename: expectedFilecontent])
	}
	
	func testKeyButNotValues3() throws {
		let filename = "./whatever.strings"
		let filecontent = #""this_is_weird_but_valid"  ;"#
		let expectedFilecontent = #""this_is_weird_but_valid" = "!¡!TODOLOC!¡!"  ;\#n"#
		let parsed = try XcodeStringsFile(filepath: filename, filecontent: filecontent)
		let locFile = LocFile()
		locFile.mergeXcodeStringsFiles([parsed], folderNameToLanguageName: [:])
		let files = try exportXcodeAndGetFilesContent(locFile)
		XCTAssertEqual(files, [filename: expectedFilecontent])
	}
	
	func testKeyButNotValues4() throws {
		let filename = "./dummy.lproj/whatever.strings"
		let filecontent = "this_is_weird_but_valid  ;"
		let expectedFilecontent = "this_is_weird_but_valid  ;\n"
		let parsed = try XcodeStringsFile(filepath: filename, filecontent: filecontent)
		let locFile = LocFile()
		locFile.mergeXcodeStringsFiles([parsed], folderNameToLanguageName: ["dummy.lproj": "dummy"])
		let files = try exportXcodeAndGetFilesContent(locFile)
		XCTAssertEqual(files, [filename: expectedFilecontent])
	}
	
	private func exportXcodeAndGetFilesContent(_ locFile: LocFile) throws -> [String: String] {
		let fm = FileManager.default
		let outputFolder = fm.temporaryDirectory.appendingPathComponent("LocMapperTest\(UUID().uuidString))")
		guard !fm.fileExists(atPath: outputFolder.path) else {
			struct UUIDCollisionYouShouldPlayLotoError : Error {}
			throw UUIDCollisionYouShouldPlayLotoError()
		}
		try fm.createDirectory(at: outputFolder, withIntermediateDirectories: false)
		defer {
			if (try? fm.removeItem(at: outputFolder)) == nil {
				NSLog("%@", "Failed to remove temporary folder: \(outputFolder.path)")
			}
		}
		try fm.createDirectory(at: outputFolder.appendingPathComponent("dummy.lproj"), withIntermediateDirectories: true)
		locFile.exportToXcodeProjectWithRoot(outputFolder.path, folderNameToLanguageName: ["dummy.lproj": "dummy"])
		var res = [String: String]()
		for file in try fm.subpathsOfDirectory(atPath: outputFolder.path) {
			let url = outputFolder.appendingPathComponent(file)
			
			var isDir = ObjCBool(false)
			guard fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {continue}
			res["./" + file] = try String(contentsOf: url)
		}
		return res
	}
	
}
