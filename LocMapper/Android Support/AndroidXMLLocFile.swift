/*
 * AndroidXMLLocFile.swift
 * LocMapper
 *
 * Created by François Lamboley on 11/14/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation
import os.log



protocol AndroidLocComponent {
	
	var stringValue: String { get }
	
}

private extension String {
	
	var xmlTextValue: String {
		var v = self
//		v = v.stringByReplacingOccurrencesOfString("\\", withString: "\\\\", options: NSStringCompareOptions.LiteralSearch)
		v = v.replacingOccurrences(of: "'", with: "\\'", options: NSString.CompareOptions.literal)
		v = v.replacingOccurrences(of: "&", with: "&amp;", options: NSString.CompareOptions.literal)
		v = v.replacingOccurrences(of: "<", with: "&lt;", options: NSString.CompareOptions.literal)
		v = v.replacingOccurrences(of: ">", with: "&gt;", options: NSString.CompareOptions.literal) /* Shouldn't be needed... */
		return v
	}
	var valueFromXMLText: String {
		var v = self
		v = v.replacingOccurrences(of: "\\'", with: "'", options: NSString.CompareOptions.literal)
		v = v.replacingOccurrences(of: "\\\\", with: "\\", options: NSString.CompareOptions.literal)
		return v
	}
	
}

public class AndroidXMLLocFile: TextOutputStreamable {
	
	let filepath: String
	let components: [AndroidLocComponent]
	
	class GenericGroupOpening: AndroidLocComponent {
		let fullString: String
		let groupNameAndAttr: (String, [String: String])?
		
		var stringValue: String {
			return fullString
		}
		
		init(fullString str: String) {
			groupNameAndAttr = nil
			fullString = str
		}
		
		init(groupName: String, attributes: [String: String]) {
			groupNameAndAttr = (groupName, attributes)
			
			var ret = "<\(groupName)"
			for attr in attributes {
				ret += " \(attr.0)=\"\(attr.1)\""
			}
			ret += ">"
			fullString = ret
		}
	}
	
	class GenericGroupClosing: AndroidLocComponent {
		let groupName: String
		let nameAttr: String?
		
		var stringValue: String {
			return "</\(groupName)>"
		}
		
		convenience init(groupName: String) {
			self.init(groupName: groupName, nameAttributeValue: nil)
		}
		
		init(groupName grpName: String, nameAttributeValue: String?) {
			groupName = grpName
			nameAttr = nameAttributeValue
		}
	}
	
	class WhiteSpace: AndroidLocComponent {
		let content: String
		
		var stringValue: String {return content}
		
		init(_ c: String) {
			assert(c.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted) == nil, "Invalid white space string")
			content = c
		}
	}
	
	class Comment: AndroidLocComponent {
		let content: String
		
		var stringValue: String {return "<!--\(content)-->"}
		
		init(_ c: String) {
			assert(c.range(of: "-->") == nil, "Invalid comment string")
			content = c
		}
	}
	
	class StringValue: AndroidLocComponent {
		let key: String
		let value: String
		let isCDATA: Bool
		
		var stringValue: String {
			if value.xmlTextValue.isEmpty {
				return "<string name=\"\(key)\"/>"
			}
			if !isCDATA {return "<string name=\"\(key)\">\(value.xmlTextValue)</string>"}
			else        {return "<string name=\"\(key)\"><![CDATA[\(value)]]></string>"}
		}
		
		init(key k: String, value v: String) {
			key = k
			value = v
			isCDATA = false
		}
		
		init(key k: String, cDATAValue v: String) {
			key = k
			value = v
			isCDATA = true
		}
	}
	
	class ArrayItem: AndroidLocComponent {
		let idx: Int
		let value: String
		let parentName: String
		
		var stringValue: String {
			return "<item>\(value.xmlTextValue)</item>"
		}
		
		init(value v: String, index: Int, parentName pn: String) {
			value = v
			idx = index
			parentName = pn
		}
	}
	
	class PluralGroup: AndroidLocComponent {
		class PluralItem: AndroidLocComponent {
			let quantity: String
			let value: String
			let isCDATA: Bool
			
			var stringValue: String {
				if value.xmlTextValue.isEmpty {
					return "<item quantity=\"\(quantity)\"/>"
				}
				if !isCDATA {return "<item quantity=\"\(quantity)\">\(value.xmlTextValue)</item>"}
				else        {return "<item quantity=\"\(quantity)\"><![CDATA[\(value)]]></item>"}
			}
			
			init(quantity q: String, value v: String) {
				quantity = q
				value = v
				isCDATA = false
			}
			
			init(quantity q: String, cDATAValue v: String) {
				quantity = q
				value = v
				isCDATA = true
			}
		}
		
		let name: String
		let attributes: [String: String]
		let values: [String /* Quantity */: (comments: [AndroidLocComponent], value: PluralItem)?]
		
		var stringValue: String {
			var ret = "<plurals name=\"\(name)\""
			for (key, val) in attributes {
				ret += " \(key)=\"\(val.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
			}
			ret += ">"
			for (quantity, value) in values where value != nil {
				let (spaces, pluralItem) = value!
				assert(pluralItem.quantity == quantity)
				
				for component in spaces {ret += component.stringValue}
				ret += pluralItem.stringValue
			}
			return ret
		}
		
		init(name n: String, attributes attr: [String: String], values v: [String /* Quantity */: (comments: [AndroidLocComponent], value: PluralItem)?]) {
			name = n
			attributes = attr
			values = v
		}
	}
	
	class ParserDelegate: NSObject, XMLParserDelegate {
		/* Equality comparison does not compare argument values for cases with
		 * arguments */
		enum Status: Equatable {
			case outStart
			case inResources
			case inString(String /* key */)
			case inArray(String /* key */), inArrayItem
			case inPlurals(String /* key */), inPluralItem(String /* quantity */)
			case outEnd
			
			case error
			
			func numericId() -> Int {
				switch self {
					case .outStart:     return 0
					case .inResources:  return 1
					case .inString:     return 2
					case .inArray:      return 3
					case .inArrayItem:  return 4
					case .inPlurals:    return 5
					case .inPluralItem: return 6
					case .outEnd:       return 7
					case .error:        return 8
				}
			}
		}
		
		var currentArrayIdx = 0
		var currentChars = String()
		var currentGroupName: String?
		var isCurrentCharsCDATA = false
		var previousStatus = Status.error
		var status: Status = .outStart {
			willSet {
				previousStatus = status
			}
		}
		var components = [AndroidLocComponent]()
		
		var currentPluralAttributes = [String: String]()
		var currentPluralSpaces = [AndroidLocComponent]()
		var currentPluralValues: [String /* Quantity */: ([AndroidLocComponent], PluralGroup.PluralItem)?]?
		
		private var addingSpacesToPlural = false
		private func addSpaceComponent(_ space: AndroidLocComponent) {
			assert(space is WhiteSpace || space is Comment)
			if !addingSpacesToPlural {components.append(space)}
			else                     {currentPluralSpaces.append(space)}
		}
		
		func parserDidStartDocument(_ parser: XMLParser) {
			assert(status == .outStart)
		}
		
		func parserDidEndDocument(_ parser: XMLParser) {
			if status != Status.outEnd {
				parser.abortParsing()
			}
		}
		
		func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
//			if #available(OSX 10.12, *) {di.log.flatMap{ os_log("didStartElement %@ namespaceURI %@ qualifiedName %@ attributes %@", log: $0, type: .debug, elementName, String(describing: namespaceURI), String(describing: qName), attributeDict) }}
//			else                        {NSLog("didStartElement %@ namespaceURI %@ qualifiedName %@ attributes %@", elementName, String(describing: namespaceURI), String(describing: qName), attributeDict)}
			let attrs = attributeDict
			
			switch (status, elementName) {
				case (.outStart, "resources"):
					status = .inResources
				
				case (.inResources, "string"):
					if let name = attrs["name"] {status = .inString(name)}
					else                        {status = .error}
				
				case (.inResources, "string-array"):
					if let name = attrs["name"] {status = .inArray(name); currentGroupName = name}
					else                        {status = .error}
				
				case (.inResources, "plurals"):
					var attrsCopy = attributeDict
					attrsCopy.removeValue(forKey: "name")
					currentPluralAttributes = attrsCopy
					if let name = attrs["name"] {status = .inPlurals(name); currentGroupName = name; currentPluralValues = [:]}
					else                        {status = .error}
				
				case (.inArray, "item"):
					status = .inArrayItem
				
				case (.inPlurals, "item"):
					if let quantity = attrs["quantity"] {status = .inPluralItem(quantity)}
					else                                {status = .error}
				
				default:
					/* We used to fail here. Instead we simply ignore the tag and add
					 * it to the current chars */
					let attributesStr = attrs.reduce("") { $0 + " " + $1.key + "=\"" + $1.value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"" }
					currentChars += "<" + elementName + attributesStr + ">"
					return
			}
			
			guard status != .error else {
				parser.abortParsing()
				return
			}
			
			if !currentChars.isEmpty {
				addSpaceComponent(WhiteSpace(currentChars))
				currentChars = ""
			}
			addingSpacesToPlural = (addingSpacesToPlural || elementName == "plurals")
			
			if elementName != "string" && elementName != "plurals" && elementName != "item" {
				components.append(GenericGroupOpening(groupName: elementName, attributes: attrs))
			}
		}
		
		func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
//			if #available(OSX 10.12, *) {di.log.flatMap{ os_log("didEndElement %@ namespaceURI %@ qualifiedName %@", log: $0, type: .debug, elementName, String(describing: namespaceURI), String(describing: qName)) }}
//			else                        {NSLog("didEndElement %@ namespaceURI %@ qualifiedName %@", elementName, String(describing: namespaceURI), String(describing: qName))}
			switch (status, elementName) {
				case (.inResources, "resources"):
					if !currentChars.isEmpty {addSpaceComponent(WhiteSpace(currentChars))}
					components.append(GenericGroupClosing(groupName: elementName))
					status = .outEnd
				
				case (.inString(let name), "string"):
					let stringValue: StringValue
					if !isCurrentCharsCDATA {stringValue = StringValue(key: name, value: currentChars.valueFromXMLText)}
					else                    {stringValue = StringValue(key: name, cDATAValue: currentChars)}
					components.append(stringValue)
					status = .inResources
				
				case (.inArray, "string-array"):
					currentArrayIdx = 0
					if !currentChars.isEmpty {addSpaceComponent(WhiteSpace(currentChars))}
					components.append(GenericGroupClosing(groupName: elementName, nameAttributeValue: currentGroupName))
					currentGroupName = nil
					status = .inResources
				
				case (.inPlurals(let pluralsName), "plurals"):
					components.append(PluralGroup(name: pluralsName, attributes: currentPluralAttributes, values: currentPluralValues!))
					addingSpacesToPlural = false
					currentPluralAttributes = [:]
					currentPluralValues = nil
					
					if !currentChars.isEmpty {addSpaceComponent(WhiteSpace(currentChars))}
					components.append(GenericGroupClosing(groupName: elementName, nameAttributeValue: currentGroupName))
					currentGroupName = nil
					status = .inResources
				
				case (.inArrayItem, "item"):
					switch previousStatus {
					case .inArray(let arrayName):
						components.append(ArrayItem(value: currentChars.valueFromXMLText, index: currentArrayIdx, parentName: arrayName))
						status = previousStatus
						currentArrayIdx += 1
						
					default:
						status = .error
					}
				
				case (.inPluralItem(let quantity), "item"):
					switch previousStatus {
					case .inPlurals(let pluralsName):
						if currentPluralValues![quantity] != nil {
							if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got more than one value for quantity %{public}@ of plurals named %{public}@... Choosing the latest one found.", log: $0, type: .info, quantity, pluralsName) }}
							else                        {NSLog("Got more than one value for quantity %@ of plurals named %@... Choosing the latest one found.", quantity, pluralsName)}
						}
						currentPluralValues![quantity] = (
							currentPluralSpaces,
							isCurrentCharsCDATA ?
								PluralGroup.PluralItem(quantity: quantity, cDATAValue: currentChars) :
								PluralGroup.PluralItem(quantity: quantity, value: currentChars.valueFromXMLText)
						)
						currentPluralSpaces.removeAll()
						status = previousStatus
						
					default:
						status = .error
					}
				
				default:
					/* Ignoring unknown tags when building current chars... */
					currentChars += "</\(elementName)>"
					return
			}
			
			currentChars = ""
			isCurrentCharsCDATA = false
			
			if status == .error {
				parser.abortParsing()
				return
			}
		}
		
		func parser(_ parser: XMLParser, foundCharacters string: String) {
//			if #available(OSX 10.12, *) {di.log.flatMap{ os_log("foundCharacters %@", log: $0, type: .debug, string) }}
//			else                        {NSLog("foundCharacters %@", string)}
			if isCurrentCharsCDATA && !currentChars.isEmpty {
				if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Warning while parsing XML file: found non-CDATA character, but I also have CDATA characters.", log: $0) }}
				else                        {NSLog("Warning while parsing XML file: found non-CDATA character, but I also have CDATA characters.")}
				/* We used to fail parsing here. Now if a CDATA block is mixed with
				 * non-CDATA value, we consider the whole value to be a CDATA block
				 * and we continue. */
			}
			
			currentChars += string
		}
		
		func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) {
			if #available(OSX 10.12, *) {di.log.flatMap{ os_log("foundIgnorableWhitespace %@", log: $0, type: .info, whitespaceString) }}
			else                        {NSLog("foundIgnorableWhitespace %@", whitespaceString)}
		}
		
		func parser(_ parser: XMLParser, foundComment comment: String) {
//			if #available(OSX 10.12, *) {di.log.flatMap{ os_log("foundComment %@", log: $0, type: .debug, comment) }}
//			else                        {NSLog("foundComment %@", comment)}
			
			switch status {
				case .inResources: fallthrough
				case .inArray:     fallthrough
				case .inPlurals:
					if !currentChars.isEmpty {
						addSpaceComponent(WhiteSpace(currentChars))
						currentChars = ""
					}
					addSpaceComponent(Comment(comment))
				default:
					parser.abortParsing()
					status = .error
			}
		}
		
		func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
			if !isCurrentCharsCDATA && !currentChars.isEmpty {
				if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Warning while parsing XML file: found CDATA block, but I also have non-CDATA characters.", log: $0) }}
				else                        {NSLog("Warning while parsing XML file: found CDATA block, but I also have non-CDATA characters.")}
				/* We used to fail parsing here. Now if a CDATA block is mixed with
				 * non-CDATA value, we consider the whole value to be a CDATA block
				 * and we continue. */
			}
			
			isCurrentCharsCDATA = true
			if let str = String(data: CDATABlock, encoding: .utf8) {currentChars += str}
		}
		
		func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
			if #available(OSX 10.12, *) {di.log.flatMap{ os_log("parseErrorOccurred: %@", log: $0, type: .info, String(describing: parseError)) }}
			else                        {NSLog("parseErrorOccurred: %@", String(describing: parseError))}
		}
	}
	
	public static func locFilesInProject(_ root_folder: String, resFolder: String, stringsFilenames: [String], languageFolderNames: [String]) throws -> [AndroidXMLLocFile] {
		var parsed_loc_files = [AndroidXMLLocFile]()
		for languageFolder in languageFolderNames {
			for stringsFilename in stringsFilenames {
				var err: NSError?
				let cur_file = ((resFolder as NSString).appendingPathComponent(languageFolder) as NSString).appendingPathComponent(stringsFilename)
				do {
					let locFile = try AndroidXMLLocFile(fromPath: cur_file, relativeToProjectPath: root_folder)
					parsed_loc_files.append(locFile)
				} catch let error as NSError {
					err = error
					if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got error while parsing strings file %@: %@", log: $0, type: .info, cur_file, String(describing: err)) }}
					else                        {NSLog("Got error while parsing strings file %@: %@", cur_file, String(describing: err))}
				}
			}
		}
		return parsed_loc_files
	}
	
	public convenience init(fromPath path: String, relativeToProjectPath projectPath: String) throws {
		assert(!path.hasPrefix("/"))
		let url = URL(fileURLWithPath: path, relativeTo: URL(fileURLWithPath: projectPath))
		try self.init(pathRelativeToProject: path, fileURL: url)
	}
	
	convenience init(pathRelativeToProject: String, fileURL url: URL) throws {
		let error: NSError! = NSError(domain: "Migrator", code: 4, userInfo: nil)
		let xmlParser: XMLParser! = XMLParser(contentsOf: url)
		if xmlParser == nil {
			/* Must init before failing */
			self.init(pathRelativeToProject: pathRelativeToProject, components: [])
			throw error
		}
		
		let parserDelegate = ParserDelegate()
		xmlParser.delegate = parserDelegate
		xmlParser.parse()
		if parserDelegate.status != .outEnd {
			self.init(pathRelativeToProject: pathRelativeToProject, components: [])
			throw error
		}
		
		self.init(pathRelativeToProject: pathRelativeToProject, components: parserDelegate.components)
	}
	
	init(pathRelativeToProject: String, components c: [AndroidLocComponent]) {
		filepath   = pathRelativeToProject
		components = c
	}
	
	public func write<Target: TextOutputStream>(to target: inout Target) {
		"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n".write(to: &target)
		for component in components {
			component.stringValue.write(to: &target)
		}
	}
	
}

func ==(val1: AndroidXMLLocFile.ParserDelegate.Status, val2: AndroidXMLLocFile.ParserDelegate.Status) -> Bool {
	return val1.numericId() == val2.numericId()
}