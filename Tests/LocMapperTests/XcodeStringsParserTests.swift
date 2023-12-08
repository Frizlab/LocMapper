/*
 * XcodeStringsParserTests.swift
 * LocMapperTests
 *
 * Created by François Lamboley on 2018-02-03.
 * Copyright © 2018 happn. All rights reserved.
 */

import XCTest
@testable import LocMapper



final class XcodeStringsParserTests : XCTestCase {
	
	func testFail1() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "\""))
	}
	
	func testFail2() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "abc=def"))
	}
	
	func testFail3() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "abc"))
	}
	
	func testFail4() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "=a;"))
	}
	
	func testFail5() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "/=//;"))
	}
	
	func testFail6() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "/*"))
	}
	
	func testFail7() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "/* yoyo *"))
	}
	
	func testFail8() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "abc=/*yo* def;"))
	}
	
	func testFail9() {
		XCTAssertThrowsError(try XcodeStringsFile(filepath: "whatever.strings", filecontent: "a=  ;"))
	}
	
	func testEmpty() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: "")
		XCTAssertTrue(parsed.components.isEmpty)
	}
	
	func testNoValues1() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: "  \n")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.WhiteSpace("  \n")].map{ $0.stringValue }
		)
	}
	
	func testNoValues2() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: "  \n/*comment1*///comment2\n")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			([XcodeStringsFile.WhiteSpace("  \n"),
			  XcodeStringsFile.Comment("comment1", doubleSlashed: false),
			  XcodeStringsFile.Comment("comment2", doubleSlashed: true)] as [XcodeStringsComponent])
				.map{ $0.stringValue }
		)
	}
	
	func testNoValues3() throws {
		/* Note: If the file is a non-trailing whiteline file ending with a //-styled comment,
		 *       the output file on re-export _will_ contain a trailing whiteline.
		 *       I don't feel too bad about it though :) */
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: "  \n/*comment1*///comment2")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			([XcodeStringsFile.WhiteSpace("  \n"),
			  XcodeStringsFile.Comment("comment1", doubleSlashed: false),
			  XcodeStringsFile.Comment("comment2", doubleSlashed: true)] as [XcodeStringsComponent])
				.map{ $0.stringValue }
		)
	}
	
	func testStarInComment() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: "/* * */")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.Comment(" * ", doubleSlashed: false)].map{ $0.stringValue }
		)
	}
	
	func testStarAtEndOfComment() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: "/* **/")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.Comment(" *", doubleSlashed: false)].map{ $0.stringValue }
		)
	}
	
	func testDoubleStarAtEndOfComment() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: "/* ***/")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.Comment(" **", doubleSlashed: false)].map{ $0.stringValue }
		)
	}
	
	func testParseSimpleXcodeStringsFile1() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: #""hello" = "Hello!";"#)
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "hello", keyHasQuotes: true, equalSign: " = ", value: "Hello!", valueHasQuotes: true, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseSimpleXcodeStringsFile2() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: #"hello = "Hello!";"#)
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "hello", keyHasQuotes: false, equalSign: " = ", value: "Hello!", valueHasQuotes: true, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseSimpleXcodeStringsFile3() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: #""hello"=/*comment*/"Hello!";"#)
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "hello", keyHasQuotes: true, equalSign: "=/*comment*/", value: "Hello!", valueHasQuotes: true, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseSimpleXcodeStringsFile4() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			"hello"/*yeay*//*super happy*/=//oneline comment
			"Hello!";
			""")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "hello", keyHasQuotes: true, equalSign: "/*yeay*//*super happy*/=//oneline comment\n", value: "Hello!", valueHasQuotes: true, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseSimpleXcodeStringsFile5() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: #""\"hello" = "Hello!";"#)
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: #""hello"#, keyHasQuotes: true, equalSign: " = ", value: "Hello!", valueHasQuotes: true, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseTwoValuesXcodeStringsFile() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			"key1" = "Value 1";
			"key2" = "Value 2";
			""")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			([XcodeStringsFile.LocalizedString(key: "key1", keyHasQuotes: true, equalSign: " = ", value: "Value 1", valueHasQuotes: true, semicolon: ";"),
			  XcodeStringsFile.WhiteSpace("\n"),
			  XcodeStringsFile.LocalizedString(key: "key2", keyHasQuotes: true, equalSign: " = ", value: "Value 2", valueHasQuotes: true, semicolon: ";")] as [XcodeStringsComponent])
				.map{ $0.stringValue }
		)
	}
	
	func testWhiteAfterValues() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: "key=value;  \n")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			([XcodeStringsFile.LocalizedString(key: "key", keyHasQuotes: false, equalSign: "=", value: "value", valueHasQuotes: false, semicolon: ";"),
			  XcodeStringsFile.WhiteSpace("  \n")] as [XcodeStringsComponent])
				.map{ $0.stringValue }
		)
	}
	
	func testParseWeirdXcodeStringsFile1() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			1//_$:.-2_NA2 //
			=/*hehe*/
			N/A;
			""")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "1//_$:.-2_NA2", keyHasQuotes: false, equalSign: " //\n=/*hehe*/\n", value: "N/A", valueHasQuotes: false, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseWeirdXcodeStringsFile2() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: "/=/;")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "/", keyHasQuotes: false, equalSign: "=", value: "/", valueHasQuotes: false, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testParseWeirdXcodeStringsFile3() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: "/=/ /**/;")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "/", keyHasQuotes: false, equalSign: "=", value: "/", valueHasQuotes: false, semicolon: " /**/;")].map{ $0.stringValue }
		)
	}
	
	func testParseWeirdXcodeStringsFile4() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: """
			1//_$:.-2_NA2 //
			=/*hehe*/
			N/A;/=/;
			/=/ /**/;
			""")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			([XcodeStringsFile.LocalizedString(key: "1//_$:.-2_NA2", keyHasQuotes: false, equalSign: " //\n=/*hehe*/\n", value: "N/A", valueHasQuotes: false, semicolon: ";"),
			  XcodeStringsFile.LocalizedString(key: "/", keyHasQuotes: false, equalSign: "=", value: "/", valueHasQuotes: false, semicolon: ";"),
			  XcodeStringsFile.WhiteSpace("\n"),
			  XcodeStringsFile.LocalizedString(key: "/", keyHasQuotes: false, equalSign: "=", value: "/", valueHasQuotes: false, semicolon: " /**/;")] as [XcodeStringsComponent])
				.map{ $0.stringValue }
		)
	}
	
	func testKeyButNotValues() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: "this_is_weird_but_valid;")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "this_is_weird_but_valid", keyHasQuotes: false, equalSign: "", value: "", valueHasQuotes: false, semicolon: ";")].map{ $0.stringValue }
		)
	}
	
	func testKeyButNotValues2() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: "this_is_weird_but_valid  ;")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "this_is_weird_but_valid", keyHasQuotes: false, equalSign: "", value: "", valueHasQuotes: false, semicolon: "  ;")].map{ $0.stringValue }
		)
	}
	
	func testKeyButNotValues3() throws {
		let parsed = try XcodeStringsFile(filepath: "whatever.strings", filecontent: "\"this_is_weird_but_valid\"  ;")
		XCTAssertEqual(
			parsed.components.map{ $0.stringValue },
			[XcodeStringsFile.LocalizedString(key: "this_is_weird_but_valid", keyHasQuotes: true, equalSign: "", value: "", valueHasQuotes: false, semicolon: "  ;")].map{ $0.stringValue }
		)
	}
	
}
