import Foundation
@testable import App
@testable import Vapor
import XCTest
import Testing
import FluentProvider

extension Droplet {
    static func testable() throws -> Droplet {
        let config = try Config(arguments: ["vapor", "--env=test"])
        try config.setup()
        let drop = try Droplet(config)
        try drop.setup()
        return drop
    }
    func serveInBackground() throws {
        background {
            try! self.run()
        }
        console.wait(seconds: 0.5)
    }
}

class TestCase: XCTestCase {
    override func setUp() {
        Node.fuzzy = [Row.self, JSON.self, Node.self]
        Testing.onFail = XCTFail
    }
}
