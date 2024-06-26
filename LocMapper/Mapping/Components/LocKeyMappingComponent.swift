/*
 * LocKeyMappingComponent.swift
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



public class LocKeyMappingComponent {
	
	class var serializedType: String {
		fatalError("serializedType is abstract.")
	}
	
	/**
	 Instantiate the correct subclass for the given serialization.
	 
	 Cannot fail because if the serialization is invalid, will return a `LocKeyMappingComponentInvalid` that will simply hold the serialization and will not do any transform.
	 This allows storing the given invalid transform so it is not lost when the transform is serialized back. */
	static func createCSVLocKeyMappingFromSerialization(_ serialization: [String: Any?]) -> LocKeyMappingComponent {
		do {
			guard let type = serialization["__type"] as? String else {
				throw NSError(domain: "MigratorInternal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got invalid mapping component: Key __type is undefined or not a string."])
			}
			
			let c: LocKeyMappingComponent
			
			switch type {
				case LocKeyMappingComponentToConstant.serializedType:      c = try LocKeyMappingComponentToConstant(serialization: serialization)
				case LocKeyMappingComponentValueTransforms.serializedType: c = try LocKeyMappingComponentValueTransforms(serialization: serialization)
				case LocKeyMappingComponentStdToXibLoc.serializedType:     c = try LocKeyMappingComponentStdToXibLoc(serialization: serialization)
				default:
					throw NSError(domain: "MigratorInternal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got invalid mapping component: Unknown __type value \"\(type)\"."])
			}
			
			return c
		} catch {
#if canImport(os)
			Conf.oslog.flatMap{ os_log("Got error: %@", log: $0, type: .info, String(describing: error)) }
#endif
			Conf.logger?.warning("Got error: \(String(describing: error))")
			return LocKeyMappingComponentInvalid(serialization: serialization)
		}
	}
	
	/**
	 Subclasses must implement to check if mapping is syntactically valid (do not check if resolving component is possible). */
	public var isValid: Bool {
		fatalError("This computed property is abstract.")
	}
	
	public var linkedKeys: [LocFile.LineKey] {
		fatalError("This function is abstract.")
	}
	
	final func serialize() -> [String: Any?] {
		var serializedData = self.serializePrivateData()
		if !(self is LocKeyMappingComponentInvalid) {serializedData["__type"] = type(of: self).serializedType}
		return serializedData
	}
	
	func serializePrivateData() -> [String: Any?] {
		preconditionFailure("This method is abstract")
	}
	
	func apply(forLanguage language: String, entries: [LocFile.LineKey: LocFile.LineValue]) throws -> String {
		preconditionFailure("This method is abstract")
	}
	
}
