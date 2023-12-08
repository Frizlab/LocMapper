/*
 * LocFile+Xcode.swift
 * LocMapper
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
import os.log
#endif

import Logging



extension LocFile {
	
	public func mergeXcodeStringsFiles(_ stringsFiles: [XcodeStringsFile], folderNameToLanguageName: [String: String]) {
		var index = 0
		
		let originalEntries = entries
		entries = [:]
		
		let env = "Xcode"
		var keys = [LineKey]()
		for stringsFile in stringsFiles {
			let (filenameNoLproj, languageName) = getLanguageAgnosticFilenameAndAddLanguageToList(stringsFile.filepath, withMapping: folderNameToLanguageName)
			
			var currentComment = ""
			var currentUserReadableComment = ""
			var currentUserReadableGroupComment = ""
			for component in stringsFile.components {
				switch component {
					case let whiteSpace as XcodeStringsFile.WhiteSpace:
						if whiteSpace.stringValue.range(of: "\n\n", options: NSString.CompareOptions.literal) != nil && !currentUserReadableComment.isEmpty {
							if !currentUserReadableGroupComment.isEmpty {
								currentUserReadableGroupComment += "\n\n\n"
							}
							currentUserReadableGroupComment += currentUserReadableComment
							currentUserReadableComment = ""
						}
						currentComment += whiteSpace.stringValue
						
					case let comment as XcodeStringsFile.Comment:
						if !currentUserReadableComment.isEmpty {currentUserReadableComment += "\n"}
						currentUserReadableComment += comment.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).replacingOccurrences(of: "\n * ", with: "\n", options: NSString.CompareOptions.literal)
						currentComment += comment.stringValue
						
					case let locString as XcodeStringsFile.LocalizedString:
						let refKey = LineKey(
							locKey: locString.key, env: env, filename: filenameNoLproj, index: index, comment: currentComment,
							userInfo: ["=": locString.equal, ";": locString.semicolon, "k'¿": locString.keyHasQuotes ? "0": "1", "v'¿": locString.valueHasQuotes ? "0": "1"],
							userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
						)
						let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
						if setValue(locString.effectiveValue, forKey: key, withLanguage: languageName) {index += 1}
						currentComment = ""
						currentUserReadableComment = ""
						currentUserReadableGroupComment = ""
						
					default:
#if canImport(os)
						Conf.oslog.flatMap{ os_log("Got unknown XcodeStringsFile component %@", log: $0, type: .info, String(describing: component)) }
#endif
						Conf.logger?.warning("Got unknown XcodeStringsFile component \(String(describing: component))")
				}
			}
		}
		
		for (refKey, val) in originalEntries {
			/* Dropping keys not in given strings files. */
			guard refKey.env != env || keys.contains(refKey) else {continue}
			
			let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
			entries[key] = val
		}
	}
	
	public func exportToXcodeProjectWithRoot(_ rootPath: String, folderNameToLanguageName: [String: String], encoding: String.Encoding = .utf16) {
		var filenameToComponents = [String: [XcodeStringsComponent]]()
		for entryKey in entries.keys.sorted() {
			guard entryKey.env == "Xcode" else {continue}
			
			let keyHasNoQuotes   = (entryKey.userInfo["k'¿"] == "1" || entryKey.userInfo["'?"] == "0")
			let equalString      = (entryKey.userInfo["="] ?? " = ")
			let valueHasNoQuotes = (entryKey.userInfo["v'¿"] == "1")
			let semicolonString  = (entryKey.userInfo[";"] ?? ";")
			
			/* Now let's parse the comment to separate the WhiteSpace and the Comment components. */
			var commentComponents = [XcodeStringsComponent]()
			let commentScanner = Scanner(string: entryKey.comment)
			commentScanner.charactersToBeSkipped = CharacterSet() /* No characters should be skipped. */
			while !commentScanner.isAtEnd {
				if let white = commentScanner.lm_scanCharacters(from: CharacterSet.whitespacesAndNewlines) {
					commentComponents.append(XcodeStringsFile.WhiteSpace(white))
				}
				if commentScanner.lm_scanString("/*") != nil {
					if let comment = commentScanner.lm_scanUpToString("*/"), !commentScanner.isAtEnd {
						commentComponents.append(XcodeStringsFile.Comment(comment, doubleSlashed: false))
						_ = commentScanner.lm_scanString("*/")
					}
				}
				if commentScanner.lm_scanString("//") != nil {
					if let comment = commentScanner.lm_scanUpToString("\n"), !commentScanner.isAtEnd {
						commentComponents.append(XcodeStringsFile.Comment(comment, doubleSlashed: true))
						_ = commentScanner.lm_scanString("\n")
					}
				}
				if let invalid = commentScanner.lm_scanUpToCharacters(from: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "/"))) {
#if canImport(os)
					Conf.oslog.flatMap{ os_log("Found invalid string in comment; ignoring: “%@”", log: $0, type: .info, invalid) }
#endif
					Conf.logger?.warning("Found invalid string in comment; ignoring: “\(invalid)”")
				}
			}
			
			for (folderName, languageName) in folderNameToLanguageName {
				let filename = entryKey.filename.replacingOccurrences(of: "//LANGUAGE//", with: "/"+folderName+"/")
				if filenameToComponents[filename] == nil {
					filenameToComponents[filename] = [XcodeStringsComponent]()
				}
				
				filenameToComponents[filename]! += commentComponents
				
				if let v = exportedValueForKey(entryKey, withLanguage: languageName) {
					if !equalString.isEmpty {
						filenameToComponents[filename]!.append(XcodeStringsFile.LocalizedString(
							key: entryKey.locKey,
							keyHasQuotes: !keyHasNoQuotes,
							equalSign: equalString,
							value: v,
							valueHasQuotes: !valueHasNoQuotes,
							semicolon: semicolonString
						))
					} else {
						/* If the equal sign is empty, we’re in a weird case where the original strings file had this weird syntax where the value is ommited.
						 * The only value possible to keep this would be to have the value equal to the key, so we set an arbitrary equal sign if it’s not. */
						let keyEqualValue = (entryKey.locKey == v)
						filenameToComponents[filename]!.append(XcodeStringsFile.LocalizedString(
							key: entryKey.locKey,
							keyHasQuotes: !keyHasNoQuotes,
							equalSign: (keyEqualValue ? equalString/*""*/ : " = "),
							value: (keyEqualValue ? "" : v),
							valueHasQuotes: !valueHasNoQuotes,
							semicolon: semicolonString
						))
					}
				}
			}
		}
		
		for (filename, components) in filenameToComponents {
			let locFile = XcodeStringsFile(filepath: filename, components: components)
			let fullOutputPath = (rootPath as NSString).appendingPathComponent(locFile.filepath)
			
			var stringsText = ""
			print(locFile, terminator: "", to: &stringsText)
			var err: NSError?
			do {
				try writeText(stringsText, toFile: fullOutputPath, usingEncoding: encoding)
			} catch let error as NSError {
				err = error
#if canImport(os)
				Conf.oslog.flatMap{ os_log("Cannot write file to path %@, got error %@", log: $0, type: .error, fullOutputPath, String(describing: err)) }
#endif
				Conf.logger?.error("Cannot write file to path \(fullOutputPath), got error \(String(describing: err))")
			}
		}
	}
	
}
