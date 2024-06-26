/*
 * LocValueTransformerRegionDelimitersReplacement.swift
 * LocMapper
 *
 * Created by François Lamboley on 2018-02-03.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import XibLoc



class LocValueTransformerRegionDelimitersReplacement : LocValueTransformer {
	
	override class var serializedType: String {return "region_delimiters_replacement"}
	
	override var isValid: Bool {
		return true
	}
	
	let replacement: String
	let openDelim: String
	let closeDelim: String
	
	let escapeToken: String?
	
	init(replacement r: String, openDelim od: String, closeDelim cd: String, escapeToken e: String? = "~") {
		replacement = r
		openDelim = od
		closeDelim = cd
		
		escapeToken = e
	}
	
	init(serialization: [String: Any?]) throws {
		guard let r = serialization["replacement"] as? String else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid or missing open_delimiter, close_delimiter or replacement."])
		}
		
		replacement = r
		
		if let d = serialization["open_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty open delimiter, which is invalid."])}
			openDelim = d
		} else {openDelim = "|"}
		
		if let d = serialization["close_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty close delimiter, which is invalid."])}
			closeDelim = d
		} else {closeDelim = "|"}
		
		if let e = serialization["escape_token"] as? String, !e.isEmpty {escapeToken = e}
		else                                                            {escapeToken = "~"}
		
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any?] {
		return [
			"open_delimiter": openDelim,
			"close_delimiter": closeDelim,
			"replacement": replacement,
			"escape_token": escapeToken
		]
	}
	
	override func apply(toValue value: String, withLanguage: String) throws -> String {
		guard let xibLocInfo = Str2StrXibLocInfo(
			defaultPluralityDefinition: PluralityDefinition(matchingNothing: ()), escapeToken: escapeToken,
			simpleSourceTypeReplacements: [OneWordTokens(leftToken: openDelim, rightToken: closeDelim): { str in self.replacement.replacingOccurrences(of: "__DELIMITED_VALUE__", with: str) }],
			identityReplacement: { $0 }
		) else {
			throw MappingResolvingError.invalidXibLocTokens
		}
		return value.applying(xibLocInfo: xibLocInfo)
	}
	
}
