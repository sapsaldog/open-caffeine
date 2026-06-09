@testable import OpenCaffeine
import XCTest

final class FeedbackTransportTests: XCTestCase {
    private var url: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        url = try XCTUnwrap(URL(string: "https://example.test/feedback"))
    }

    private func body(_ request: URLRequest) -> [String: Any] {
        guard let data = request.httpBody,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return json
    }

    private func http(_ status: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status,
                                      httpVersion: nil, headerFields: nil))
    }

    // MARK: feedback request
    func testFeedbackRequestFullBody() throws {
        let shot = ScreenshotRef(fileName: "f.png", url: "https://u/f.png",
                                 fileSize: 9, width: 2, height: 2, mimeType: "image/png")
        let request = try FeedbackRequest.feedback(
            url: url, clientId: "client_x", rating: 3, comment: "great",
            email: "a@b.com", environment: "debug",
            metadata: ["appVersion": "1.0"], screenshots: [shot])
        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let json = body(request)
        XCTAssertEqual(json["clientId"] as? String, "client_x")
        XCTAssertEqual(json["rating"] as? Int, 3)
        XCTAssertEqual(json["comment"] as? String, "great")
        XCTAssertEqual(json["userEmail"] as? String, "a@b.com")
        XCTAssertEqual(json["environment"] as? String, "debug")
        XCTAssertNotNil(json["metadata"])
        XCTAssertNotNil(json["screenshots"])
    }

    func testFeedbackRequestOmitsNilAndEmptyFields() throws {
        let request = try FeedbackRequest.feedback(
            url: url, clientId: "client_x", rating: nil, comment: "hi",
            email: nil, environment: "production", metadata: [:], screenshots: [])
        let json = body(request)
        XCTAssertEqual(json["comment"] as? String, "hi")
        XCTAssertNil(json["rating"])
        XCTAssertNil(json["userEmail"])
        XCTAssertNil(json["metadata"])
        XCTAssertNil(json["screenshots"])
    }

    // MARK: screenshot request
    func testScreenshotRequestMultipart() throws {
        let shot = PendingScreenshot(data: Data("PNGBYTES".utf8),
                                     fileName: "shot.png", mimeType: "image/png")
        let request = FeedbackRequest.screenshot(
            url: url, clientId: "client_x", screenshot: shot, boundary: "BND")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"),
                       "multipart/form-data; boundary=BND")
        let text = try XCTUnwrap(String(bytes: request.httpBody ?? Data(), encoding: .utf8))
        XCTAssertTrue(text.contains("--BND"))
        XCTAssertTrue(text.contains("name=\"clientId\""))
        XCTAssertTrue(text.contains("client_x"))
        XCTAssertTrue(text.contains("name=\"screenshot\"; filename=\"shot.png\""))
        XCTAssertTrue(text.contains("Content-Type: image/png"))
        XCTAssertTrue(text.contains("PNGBYTES"))
        XCTAssertTrue(text.contains("--BND--"))
    }

    // MARK: response parsers
    func testFeedbackIdSuccess() throws {
        let data = Data(#"{"success":true,"feedbackId":"abc123"}"#.utf8)
        let feedbackId = try FeedbackResponse.feedbackId(data: data, response: try http(200))
        XCTAssertEqual(feedbackId, "abc123")
    }

    func testScreenshotSuccess() throws {
        let data = Data(#"""
        {"success":true,"screenshot":{"fileName":"a.png","url":"https://u/a.png",
        "fileSize":48211,"width":1280,"height":800,"mimeType":"image/png"}}
        """#.utf8)
        let ref = try FeedbackResponse.screenshot(data: data, response: try http(200))
        XCTAssertEqual(ref.fileName, "a.png")
        XCTAssertEqual(ref.fileSize, 48211)
        XCTAssertEqual(ref.width, 1280)
        XCTAssertEqual(ref.mimeType, "image/png")
    }

    func testValidationErrorWithDetail() throws {
        let response = try http(400)
        let data = Data(#"{"error":"Invalid data provided"}"#.utf8)
        XCTAssertThrowsError(try FeedbackResponse.feedbackId(data: data, response: response)) {
            XCTAssertEqual($0 as? FeedbackError, .validation("Invalid data provided"))
        }
    }

    func testValidationErrorWithoutDetail() throws {
        let response = try http(400)
        XCTAssertThrowsError(try FeedbackResponse.feedbackId(data: Data("x".utf8), response: response)) {
            XCTAssertEqual($0 as? FeedbackError, .validation(nil))
        }
    }

    func testDomainBlocked() throws {
        let response = try http(403)
        XCTAssertThrowsError(try FeedbackResponse.feedbackId(data: Data(), response: response)) {
            XCTAssertEqual($0 as? FeedbackError, .domainBlocked)
        }
    }

    func testServerError() throws {
        let response = try http(500)
        XCTAssertThrowsError(try FeedbackResponse.feedbackId(data: Data(), response: response)) {
            XCTAssertEqual($0 as? FeedbackError, .server)
        }
    }

    func testUnexpectedStatus() throws {
        let response = try http(418)
        XCTAssertThrowsError(try FeedbackResponse.feedbackId(data: Data(), response: response)) {
            XCTAssertEqual($0 as? FeedbackError, .unexpected(418))
        }
    }

    func testNonHTTPResponseIsNetworkError() {
        let response = URLResponse(url: url, mimeType: nil,
                                   expectedContentLength: 0, textEncodingName: nil)
        XCTAssertThrowsError(try FeedbackResponse.feedbackId(data: Data(), response: response)) {
            XCTAssertEqual($0 as? FeedbackError, .network)
        }
    }

    func testMalformedSuccessIsDecodingError() throws {
        let response = try http(200)
        XCTAssertThrowsError(try FeedbackResponse.feedbackId(data: Data("{}".utf8), response: response)) {
            XCTAssertEqual($0 as? FeedbackError, .decoding)
        }
    }

    func testScreenshotResponseNetworkError() {
        let response = URLResponse(url: url, mimeType: nil,
                                   expectedContentLength: 0, textEncodingName: nil)
        XCTAssertThrowsError(try FeedbackResponse.screenshot(data: Data(), response: response)) {
            XCTAssertEqual($0 as? FeedbackError, .network)
        }
    }

    func testValidationErrorWithEmptyJSONBody() throws {
        let response = try http(400)
        XCTAssertThrowsError(
            try FeedbackResponse.feedbackId(data: Data("{}".utf8), response: response)
        ) {
            XCTAssertEqual($0 as? FeedbackError, .validation(nil))
        }
    }
}
