/*
 * LocKeyMappingComponentInvalid.swift
 * LocMapper
 *
 * Created by François Lamboley on 2018-02-03.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



class LocKeyMappingComponentInvalid : LocKeyMappingComponent {
	
	override class var serializedType: String {return "__invalid__"}
	
	override var isValid: Bool {
		return false
	}
	
	override var linkedKeys: [LocFile.LineKey] {
		return []
	}
	
	let invalidSerialization: [String: Any?]
	
	init(serialization: [String: Any?]) {
		invalidSerialization = serialization
	}
	
	override func serializePrivateData() -> [String: Any?] {
		return invalidSerialization
	}
	
	override func apply(forLanguage language: String, entries: [LocFile.LineKey: LocFile.LineValue]) throws -> String {
		throw MappingResolvingError.invalidMapping
	}
	
}
