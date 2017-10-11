import XCTest
import Testing
import HTTP
import Sockets
@testable import Vapor
@testable import App

/// This file shows an example of testing an
/// individual controller without initializing
/// a Droplet.

class PostControllerTests: TestCase {
    let initialMessage = "I'm a post"
    let updatedMessage = "I have been updated \(Date())"

    /// For these tests, we won't be spinning up a live
    /// server, and instead we'll be passing our constructed
    /// requests programmatically
    /// this is usually an effective way to test your 
    /// application in a convenient and safe manner
    /// See RouteTests for an example of a live server test
    let controller = PostController()
    
    func testPostRoutes() throws {        
        guard let postOne = try storeNewPost(), let idOne = postOne.id?.int else {
            XCTFail()
            return
        }

        try fetchOne(id: idOne)
        try fetchAll(expectCount: 1)
        try patch(id: idOne)
        try put(id: idOne)

        guard let postTwo = try storeNewPost(), let idTwo = postTwo.id?.int else {
            XCTFail()
            return
        }

        try fetchAll(expectCount: 2)

        try deleteOne(id: idOne)
        try fetchAll(expectCount: 1)

        try deleteOne(id: idTwo)
        try fetchAll(expectCount: 0)

        for _ in 1...5 {
            _ = try storeNewPost()
        }
        try fetchAll(expectCount: 5)
        try deleteAll()
        try fetchAll(expectCount: 0)
    }

    func storeNewPost() throws -> Post? {
        let req = Request.makeTest(method: .post)
        req.json = try JSON(node: ["content": initialMessage])
        let res = try controller.store(req).makeResponse()
        
        let json = res.json
        XCTAssertNotNil(json)
        let newId: Int? = try json?.get("id")
        XCTAssertNotNil(newId)
        XCTAssertNotNil(json?["content"])
        XCTAssertEqual(json?["content"], req.json?["content"])
        return try Post.find(newId)
    }

    func fetchOne(id: Int) throws {
        let req = Request.makeTest(method: .get)
        let post = try Post.find(id)!
        let res = try controller.show(req, post: post).makeResponse()

        let json = res.json
        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["content"])
        XCTAssertNotNil(json?["id"])
        XCTAssertEqual(json?["id"]?.int, id)
        XCTAssertEqual(json?["content"]?.string, initialMessage)
    }

    func fetchAll(expectCount count: Int) throws {
        let req = Request.makeTest(method: .get)
        let res = try controller.index(req).makeResponse()

        let json = res.json
        XCTAssertNotNil(json?.array)
        XCTAssertEqual(json?.array?.count, count)
    }

    func patch(id: Int) throws {
        let req = Request.makeTest(method: .patch)
        req.json = try JSON(node: ["content": updatedMessage])
        let post = try Post.find(id)!
        let res = try controller.update(req, post: post).makeResponse()
        
        let json = res.json
        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["content"])
        XCTAssertNotNil(json?["id"])
        XCTAssertEqual(json?["id"]?.int, id)
        XCTAssertEqual(json?["content"]?.string, updatedMessage)
    }

    func put(id: Int) throws {
        let req = Request.makeTest(method: .put)
        req.json = try JSON(node: ["content": updatedMessage])
        let post = try Post.find(id)!
        let res = try controller.replace(req, post: post).makeResponse()

        let json = res.json
        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["content"])
        XCTAssertNotNil(json?["id"])
        XCTAssertEqual(json?["id"]?.int, id)
        XCTAssertEqual(json?["content"]?.string, updatedMessage)
    }

    func deleteOne(id: Int) throws {
        let req = Request.makeTest(method: .delete)
        
        let post = try Post.find(id)!
        _ = try controller.delete(req, post: post)
    }

    func deleteAll() throws {
        let req = Request.makeTest(method: .delete)
        _ = try controller.clear(req)
    }
}

// MARK: Manifest

extension PostControllerTests {
    /// This is a requirement for XCTest on Linux
    /// to function properly.
    /// See ./Tests/LinuxMain.swift for examples
    static let allTests = [
        ("testPostRoutes", testPostRoutes),
    ]
}
