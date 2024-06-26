/*
 * LocFile+LineKey.swift
 * LocMapper
 *
 * Created by François Lamboley on 2018-02-04.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



extension LocFile {
	
	/** The key for each entries in a LocFile. */
	public struct LineKey : Equatable, Hashable, Comparable {
		
		public let locKey: String
		public let env: String
		public let filename: String
		
		/* Used when comparing for lt or gt, but not for equality */
		public let index: Int
		
		/* Not used when comparing line keys.
		 * Both values are store in the "__UserInfo" column.
		 * We could (should!) use a json in its own column for the userInfo… but why go simple when there is a complicated way? */
		public let comment: String
		public let userInfo: [String: String]
		
		/* Not used when comparing line keys. */
		public let userReadableGroupComment: String
		public let userReadableComment: String
		
		public init(locKey k: String, env e: String, filename f: String, index i: Int = 0, comment c: String = "", userInfo ui: [String: String] = [:], userReadableGroupComment urgc: String = "", userReadableComment urc: String = "") {
			locKey = k
			env = e
			filename = f
			index = i
			comment = c
			userInfo = ui
			userReadableGroupComment = urgc
			userReadableComment = urc
		}
		
		public init(copying source: LineKey, newLocKey: String) {
			self.init(
				locKey: newLocKey, env: source.env, filename: source.filename,
				index: source.index, comment: source.comment, userInfo: source.userInfo,
				userReadableGroupComment: source.userReadableGroupComment, userReadableComment: source.userReadableComment
			)
		}
		
		static func parse(attributedComment: String) -> (comment: String, userInfo: [String: String]) {
			let (str, optionalUserInfo) = attributedComment.splitPrependedUserInfo()
			guard let userInfo = optionalUserInfo else {
				return (comment: attributedComment, userInfo: [:])
			}
			return (comment: str, userInfo: userInfo)
		}
		
		public var fullComment: String {
			return comment.byPrepending(userInfo: userInfo, sortKeys: true)
		}
		
		public func hash(into hasher: inout Hasher) {
			hasher.combine(locKey)
			hasher.combine(env)
			hasher.combine(filename)
		}
		
		public static func ==(k1: LocFile.LineKey, k2: LocFile.LineKey) -> Bool {
			return k1.locKey == k2.locKey && k1.env == k2.env && k1.filename == k2.filename
		}
		
		public static func <=(k1: LocFile.LineKey, k2: LocFile.LineKey) -> Bool {
			if k1.env      > k2.env      {return true}
			if k1.env      < k2.env      {return false}
			if k1.filename < k2.filename {return true}
			if k1.filename > k2.filename {return false}
			if k1.index    < k2.index    {return true}
			if k1.index    > k2.index    {return false}
			return k1.locKey <= k2.locKey
		}
		
		public static func >=(k1: LocFile.LineKey, k2: LocFile.LineKey) -> Bool {
			if k1.env      < k2.env      {return true}
			if k1.env      > k2.env      {return false}
			if k1.filename > k2.filename {return true}
			if k1.filename < k2.filename {return false}
			if k1.index    > k2.index    {return true}
			if k1.index    < k2.index    {return false}
			return k1.locKey >= k2.locKey
		}
		
		public static func <(k1: LocFile.LineKey, k2: LocFile.LineKey) -> Bool {
			if k1.env      > k2.env      {return true}
			if k1.env      < k2.env      {return false}
			if k1.filename < k2.filename {return true}
			if k1.filename > k2.filename {return false}
			if k1.index    < k2.index    {return true}
			if k1.index    > k2.index    {return false}
			return k1.locKey < k2.locKey
		}
		
		public static func >(k1: LocFile.LineKey, k2: LocFile.LineKey) -> Bool {
			if k1.env      < k2.env      {return true}
			if k1.env      > k2.env      {return false}
			if k1.filename > k2.filename {return true}
			if k1.filename < k2.filename {return false}
			if k1.index    > k2.index    {return true}
			if k1.index    < k2.index    {return false}
			return k1.locKey > k2.locKey
		}
		
	}
	
}
