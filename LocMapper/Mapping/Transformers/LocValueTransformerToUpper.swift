/*
 * LocValueTransformerToUpper.swift
 * LocMapper
 *
 * Created by François Lamboley on 2018-02-03.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



class LocValueTransformerToUpper : LocValueTransformer {
	
	override class var serializedType: String {return "to_upper"}
	
	override var isValid: Bool {
		return true
	}
	
	init(serialization: [String: Any?]) throws {
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any?] {
		return [:]
	}
	
	override func apply(toValue value: String, withLanguage: String) throws -> String {
		return value.uppercased()
	}
	
}
