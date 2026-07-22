// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit

public struct Lucide {
	
}

public extension UIImage {
	convenience init?(lucideId: String) {
		self.init(named: lucideId, in: Bundle.module, compatibleWith: nil)
	}
}
