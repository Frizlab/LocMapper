/*
 * LocFile+Android.swift
 * LocMapper
 *
 * Created by François Lamboley on 2018-02-03.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
import os.log
#endif

import Logging



extension LocFile {
	
	public func mergeAndroidXMLLocStringsFiles(_ locFiles: [AndroidXMLLocFile], folderNameToLanguageName: [String: String]) {
		var index = 0
		
		let originalEntries = entries
		entries = [:]
		
		let env = "Android"
		var keys = [LineKey]()
		for locFile in locFiles {
			let (filenameNoLanguage, languageName) = getLanguageAgnosticFilenameAndAddLanguageToList(locFile.filepath, withMapping: folderNameToLanguageName)
			
			var currentComment = ""
			var currentUserReadableComment = ""
			var currentUserReadableGroupComment = ""
			
			func handleWhiteSpace(_ whiteSpace: AndroidXMLLocFile.WhiteSpace) {
				if whiteSpace.stringValue.range(of: "\n\n", options: NSString.CompareOptions.literal) != nil && !currentUserReadableComment.isEmpty {
					if !currentUserReadableGroupComment.isEmpty {
						currentUserReadableGroupComment += "\n\n\n"
					}
					currentUserReadableGroupComment += currentUserReadableComment
					currentUserReadableComment = ""
				}
				currentComment += whiteSpace.stringValue
			}
			
			func handleComment(_ comment: AndroidXMLLocFile.Comment) {
				if !currentUserReadableComment.isEmpty {currentUserReadableComment += "\n"}
				currentUserReadableComment += comment.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
				currentComment += comment.stringValue
			}
			
			for component in locFile.components {
				switch component {
					case let whiteSpace as AndroidXMLLocFile.WhiteSpace:
						handleWhiteSpace(whiteSpace)
						
					case let comment as AndroidXMLLocFile.Comment:
						handleComment(comment)
						
					case let groupOpening as AndroidXMLLocFile.GenericGroupOpening:
						let refKey = LineKey(
							locKey: "o"+groupOpening.fullString, env: env, filename: filenameNoLanguage, index: index, comment: currentComment, userInfo: [:],
							userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
						)
						let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
						if setValue("---", forKey: key, withLanguage: languageName) {index += 1}
						currentComment = ""
						currentUserReadableComment = ""
						currentUserReadableGroupComment = ""
						
					case let groupClosing as AndroidXMLLocFile.GenericGroupClosing:
						let refKey = LineKey(
							locKey: "c"+groupClosing.groupName+(groupClosing.nameAttr.map{ " " + $0 } ?? ""),
							env: env, filename: filenameNoLanguage, index: index, comment: currentComment, userInfo: [:],
							userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
						)
						let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
						if setValue("---", forKey: key, withLanguage: languageName) {index += 1}
						currentComment = ""
						currentUserReadableComment = ""
						currentUserReadableGroupComment = ""
						
					case let locString as AndroidXMLLocFile.StringValue:
						let refKey = LineKey(
							locKey: "k"+locString.key, env: env, filename: filenameNoLanguage, index: index, comment: currentComment, userInfo: ["DTA": locString.isCDATA ? "1" : "0"],
							userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
						)
						let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
						if setValue(locString.value, forKey: key, withLanguage: languageName) {index += 1}
						currentComment = ""
						currentUserReadableComment = ""
						currentUserReadableGroupComment = ""
						
					case let arrayItem as AndroidXMLLocFile.ArrayItem:
						let refKey = LineKey(
							locKey: "a"+arrayItem.parentName+"\""+String(arrayItem.idx), env: env, filename: filenameNoLanguage, index: index, comment: currentComment, userInfo: [:],
							userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
						)
						let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
						if setValue(arrayItem.value, forKey: key, withLanguage: languageName) {index += 1}
						currentComment = ""
						currentUserReadableComment = ""
						currentUserReadableGroupComment = ""
						
					case let pluralGroup as AndroidXMLLocFile.PluralGroup:
						let refKey = LineKey(
							locKey: "s"+pluralGroup.name, env: env, filename: filenameNoLanguage, index: index, comment: currentComment, userInfo: [:],
							userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
						)
						let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
						if setValue("---".byPrepending(userInfo: pluralGroup.attributes, sortKeys: true), forKey: key, withLanguage: languageName) {index += 1}
						currentComment = ""
						currentUserReadableComment = ""
						currentUserReadableGroupComment = ""
						for quantity in ["zero", "one", "two", "few", "many", "other"] {
							if let info = pluralGroup.values[quantity], let (spaces, _) = info {
								for space in spaces {
									switch space {
										case let whiteSpace as AndroidXMLLocFile.WhiteSpace:
											handleWhiteSpace(whiteSpace)
										case let comment as AndroidXMLLocFile.Comment:
											handleComment(comment)
										default:
											fatalError("Invalid space: \(space)")
									}
								}
							}
							let pluralItem = pluralGroup.values[quantity]??.1
							let refKey = LineKey(
								locKey: "p"+pluralGroup.name+"\""+quantity, env: env, filename: filenameNoLanguage, index: index, comment: currentComment, userInfo: ["DTA": (pluralItem.flatMap{ $0.isCDATA } ?? false) ? "1" : "0"],
								userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
							)
							let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: true, withListOfKeys: &keys)
							if setValue((pluralItem?.value ?? "---"), forKey: key, withLanguage: languageName) {index += 1}
							currentComment = ""
							currentUserReadableComment = ""
							currentUserReadableGroupComment = ""
						}
						
					default:
#if canImport(os)
						Conf.oslog.flatMap{ os_log("Got unknown AndroidXMLLocFile component %@", log: $0, type: .info, String(describing: component)) }
#endif
						Conf.logger?.warning("Got unknown AndroidXMLLocFile component \(String(describing: component))")
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
	
	public func exportToAndroidProjectWithRoot(_ rootPath: String, folderNameToLanguageName: [String: String]) {
		var filenameToComponents = [String: [AndroidLocComponent]]()
		var spaces = [AndroidLocComponent /* Only WhiteSpace and Comment */]()
		var currentPluralsUserInfoByFilename: [String /* Language */: [String: String]] = [:]
		var currentPluralsValueByFilename: [String /* Language */: [String /* Quantity */: ([AndroidLocComponent /* Only WhiteSpace and Comment */], AndroidXMLLocFile.PluralGroup.PluralItem)?]] = [:]
		for entry_key in entries.keys.sorted() {
			guard entry_key.env == "Android" else {continue}
			
			if !entry_key.comment.isEmpty {
				let scanner = Scanner(string: entry_key.comment)
				scanner.charactersToBeSkipped = CharacterSet()
				if let white = scanner.lm_scanCharacters(from: CharacterSet.whitespacesAndNewlines) {
					spaces.append(AndroidXMLLocFile.WhiteSpace(white))
				}
				var error = false
				while scanner.lm_scanString("<!--") != nil {
					if let comment = scanner.lm_scanUpToString("-->"), !scanner.isAtEnd {
						spaces.append(AndroidXMLLocFile.Comment(comment))
						_ = scanner.lm_scanString("-->")
						if let white = scanner.lm_scanCharacters(from: CharacterSet.whitespacesAndNewlines) {
							spaces.append(AndroidXMLLocFile.WhiteSpace(white))
						}
					} else {
						error = true
						break
					}
				}
				if error || !scanner.isAtEnd {
#if canImport(os)
					Conf.oslog.flatMap{ os_log("Got invalid comment \"%@\"", log: $0, type: .info, entry_key.comment) }
#endif
					Conf.logger?.warning("Got invalid comment \"\(entry_key.comment)\"")
				}
			}
			
			for (folderName, languageName) in folderNameToLanguageName {
				let filename = entry_key.filename.replacingOccurrences(of: "//LANGUAGE//", with: "/"+folderName+"/")
				if filenameToComponents[filename] == nil {
					filenameToComponents[filename] = [AndroidLocComponent]()
				}
				
				switch entry_key.locKey {
					case let k where k.hasPrefix("o"):
						/* We're treating a group opening. */
						filenameToComponents[filename]!.append(contentsOf: spaces)
						filenameToComponents[filename]!.append(AndroidXMLLocFile.GenericGroupOpening(fullString: String(k.dropFirst())))
						
					case let k where k.hasPrefix("s"):
						/* We're treating a plural group opening. */
						filenameToComponents[filename]!.append(contentsOf: spaces)
						if let userInfo = exportedValueForKey(entry_key, withLanguage: languageName)?.splitPrependedUserInfo().userInfo {
							currentPluralsUserInfoByFilename[filename] = userInfo
						}
						currentPluralsValueByFilename[filename] = [:]
						
					case let k where k.hasPrefix("c"):
						/* We're treating a group closing. */
						let noC = k.dropFirst()
						let sepBySpace = noC.components(separatedBy: " ")
						if let plurals = currentPluralsValueByFilename[filename] {
							/* We have a plural group being contructed.
							 * We've reached it’s closing component: let's add the finished plural to the components. */
							if sepBySpace.count == 2 && sepBySpace[0] == "plurals" {
								filenameToComponents[filename]!.append(AndroidXMLLocFile.PluralGroup(name: sepBySpace[1], attributes: currentPluralsUserInfoByFilename[filename] ?? [:], values: plurals))
							} else {
#if canImport(os)
								Conf.oslog.flatMap{ os_log("Got invalid plural closing key %@. Dropping whole plurals group.", log: $0, type: .info, k) }
#endif
								Conf.logger?.warning("Got invalid plural closing key \(k). Dropping whole plurals group.")
							}
							currentPluralsValueByFilename.removeValue(forKey: filename)
						}
						filenameToComponents[filename]!.append(contentsOf: spaces)
						if sepBySpace.count > 0 && sepBySpace.count <= 2 {
							filenameToComponents[filename]!.append(AndroidXMLLocFile.GenericGroupClosing(groupName: sepBySpace[0], nameAttributeValue: (sepBySpace.count > 1 ? sepBySpace[1] : nil)))
						} else {
#if canImport(os)
							Conf.oslog.flatMap{ os_log("Got invalid closing key %@", log: $0, type: .info, k) }
#endif
							Conf.logger?.warning("Got invalid closing key \(k)")
						}
						
					case let k where k.hasPrefix("k"):
						/* We’re treating a string item. */
						if let v = exportedValueForKey(entry_key, withLanguage: languageName) {
							let stringValue: AndroidXMLLocFile.StringValue
							if (entry_key.userInfo["DTA"] != "1") {stringValue = AndroidXMLLocFile.StringValue(key: String(k.dropFirst()), value: v)}
							else                                  {stringValue = AndroidXMLLocFile.StringValue(key: String(k.dropFirst()), cDATAValue: v)}
							filenameToComponents[filename]!.append(contentsOf: spaces)
							filenameToComponents[filename]!.append(stringValue)
						}
						
					case let k where k.hasPrefix("a"):
						/* We’re treating an array item. */
						if let v = exportedValueForKey(entry_key, withLanguage: languageName) {
							filenameToComponents[filename]!.append(contentsOf: spaces)
							let noA = k.dropFirst()
							let sepByQuote = noA.components(separatedBy: "\"")
							if sepByQuote.count == 2 {
								if let idx = Int(sepByQuote[1]) {
									filenameToComponents[filename]!.append(AndroidXMLLocFile.ArrayItem(value: v, index: idx, parentName: sepByQuote[0]))
								} else {
#if canImport(os)
									Conf.oslog.flatMap{ os_log("Invalid key '%@': cannot find idx", log: $0, type: .info, k) }
#endif
									Conf.logger?.warning("Invalid key '\(k)': cannot find idx")
								}
							} else {
#if canImport(os)
								Conf.oslog.flatMap{ os_log("Got invalid array item key '%@'", log: $0, type: .info, k) }
#endif
								Conf.logger?.warning("Got invalid array item key '\(k)'")
							}
						}
						
					case let k where k.hasPrefix("p"):
						let isCData = (entry_key.userInfo["DTA"] == "1")
						/* We’re treating a plural item. */
						if currentPluralsValueByFilename[filename] != nil, let v = exportedValueForKey(entry_key, withLanguage: languageName) {
							let noP = k.dropFirst()
							let sepByQuote = noP.components(separatedBy: "\"")
							if sepByQuote.count == 2 {
								let quantity = sepByQuote[1]
								let p = isCData ?
								AndroidXMLLocFile.PluralGroup.PluralItem(quantity: quantity, cDATAValue: v) :
								AndroidXMLLocFile.PluralGroup.PluralItem(quantity: quantity, value: v)
								
								if currentPluralsValueByFilename[filename]![quantity] != nil {
#if canImport(os)
									Conf.oslog.flatMap{ os_log("Got multiple plurals value for quantity '%@' (key: '%@')", log: $0, type: .info, quantity, k) }
#endif
									Conf.logger?.warning("Got multiple plurals value for quantity '\(quantity)' (key: '\(k)')")
								}
								currentPluralsValueByFilename[filename]![quantity] = (spaces, p)
							} else {
#if canImport(os)
								Conf.oslog.flatMap{ os_log("Got invalid plural key '%@' (either malformed or misplaced)", log: $0, type: .info, k) }
#endif
								Conf.logger?.warning("Got invalid plural key '\(k)' (either malformed or misplaced)")
							}
						}
						
					default:
#if canImport(os)
						Conf.oslog.flatMap{ os_log("Got invalid key %@", log: $0, type: .info, entry_key.locKey) }
#endif
						Conf.logger?.warning("Got invalid key \(entry_key.locKey)")
				}
			}
			
			spaces.removeAll()
		}
		for (filename, components) in filenameToComponents {
			let locFile = AndroidXMLLocFile(pathRelativeToProject: filename, components: components)
			let fullOutputPath = (rootPath as NSString).appendingPathComponent(locFile.filepath)
			
			var xmlText = ""
			print(locFile, terminator: "", to: &xmlText)
			var err: NSError?
			do {
				try writeText(xmlText, toFile: fullOutputPath, usingEncoding: .utf8)
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
