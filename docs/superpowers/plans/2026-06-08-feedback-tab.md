# Feedback Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Feedback tab to Settings that lets users rate Open Caffeine (1–4 faces), comment, share an email, and attach screenshots, submitting to the Usero API.

**Architecture:** Pure value types + pure request builders/response parsers (100% unit-tested) sit under a thin `FeedbackService` URLSession shell and an `@MainActor FeedbackViewModel` state machine. A SwiftUI `FeedbackSettingsView` (view shell) reuses the existing Tahoe settings primitives and is wired into `PreferencesScene`. Faces are drawn from the mockup's exact SVG geometry.

**Tech Stack:** Swift 5.10, SwiftUI, AppKit (`NSOpenPanel`, `NSWorkspace`), XCTest, XcodeGen, SwiftLint.

**Conventions (must follow):**
- SwiftLint: no force-unwrap / `try!`; `sorted_imports` (order by module name, ignoring `@testable`); file ≤400 lines; function body ≤40 lines; line ≤120.
- Coverage gate (`Scripts/coverage-gate.sh`): every non-excluded file under `OpenCaffeine/` must be **100% line-covered**. View/IO shells go in `Scripts/coverage_check.py`'s `EXCLUDE`.
- After adding any source/test file, run `xcodegen generate` before building or testing.
- Each commit message ends with the `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` trailer.
- Client identifier (public, not a secret): `client_8b1cc88ed71c4090`.

**Commands:**
- Generate project: `xcodegen generate`
- Run one test class: `xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' -only-testing:OpenCaffeineTests/<Class> test`
- Build: `xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build`
- Lint: `swiftlint`
- Coverage gate: `Scripts/coverage-gate.sh`

---

## File Structure

**Create (logic — 100% tested):**
- `OpenCaffeine/Services/FeedbackModels.swift` — `ScreenshotRef`, `PendingScreenshot` (+ `imageMimeType`), `FeedbackError`, `FeedbackDraft`.
- `OpenCaffeine/Services/FeedbackTransport.swift` — wire DTOs, `FeedbackRequest` builders, `FeedbackResponse` parsers.
- `OpenCaffeine/Settings/FeedbackViewModel.swift` — `@MainActor` state machine.

**Create (shells — added to coverage `EXCLUDE`):**
- `OpenCaffeine/Services/FeedbackService.swift` — `FeedbackSubmitting` protocol + URLSession orchestration.
- `OpenCaffeine/Settings/RatingFace.swift` — `RatingFace` + `FaceRatingRow` (Canvas drawing).
- `OpenCaffeine/Settings/FeedbackSettingsView.swift` — the tab view + `NSOpenPanel`.

**Create (tests):**
- `OpenCaffeineTests/FeedbackModelsTests.swift`
- `OpenCaffeineTests/FeedbackTransportTests.swift`
- `OpenCaffeineTests/FeedbackViewModelTests.swift`
- `OpenCaffeineTests/Mocks/MockFeedbackService.swift`

**Modify:**
- `OpenCaffeine/Settings/PreferencesScene.swift` — add the `.feedback` tab (already in `EXCLUDE`).
- `Scripts/coverage_check.py` — add the three shell paths to `EXCLUDE`.

---

## Task 1: Feedback models (validation, errors, mime)

**Files:**
- Create: `OpenCaffeine/Services/FeedbackModels.swift`
- Test: `OpenCaffeineTests/FeedbackModelsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `OpenCaffeineTests/FeedbackModelsTests.swift`:

```swift
@testable import OpenCaffeine
import XCTest

final class FeedbackModelsTests: XCTestCase {

    // MARK: FeedbackDraft.isSendable
    func testSendableWithRatingOnly() {
        XCTAssertTrue(FeedbackDraft(rating: 3).isSendable)
    }
    func testSendableWithCommentOnly() {
        XCTAssertTrue(FeedbackDraft(comment: "nice").isSendable)
    }
    func testSendableWithBoth() {
        XCTAssertTrue(FeedbackDraft(rating: 1, comment: "x").isSendable)
    }
    func testNotSendableWhenEmpty() {
        XCTAssertFalse(FeedbackDraft().isSendable)
    }
    func testNotSendableWithWhitespaceCommentOnly() {
        XCTAssertFalse(FeedbackDraft(comment: "   \n").isSendable)
    }

    // MARK: FeedbackDraft.emailIsValid
    func testEmptyEmailIsValid() {
        XCTAssertTrue(FeedbackDraft(email: "  ").emailIsValid)
    }
    func testValidEmail() {
        XCTAssertTrue(FeedbackDraft(email: "user@example.com").emailIsValid)
    }
    func testEmailWithSpaceInvalid() {
        XCTAssertFalse(FeedbackDraft(email: "a b@c.com").emailIsValid)
    }
    func testEmailWithoutAtInvalid() {
        XCTAssertFalse(FeedbackDraft(email: "abc").emailIsValid)
    }
    func testEmailAtStartInvalid() {
        XCTAssertFalse(FeedbackDraft(email: "@b.com").emailIsValid)
    }
    func testEmailWithTwoAtsInvalid() {
        XCTAssertFalse(FeedbackDraft(email: "a@b@c.com").emailIsValid)
    }
    func testEmailDomainWithoutDotInvalid() {
        XCTAssertFalse(FeedbackDraft(email: "a@b").emailIsValid)
    }
    func testEmailDomainLeadingDotInvalid() {
        XCTAssertFalse(FeedbackDraft(email: "a@.com").emailIsValid)
    }
    func testEmailDomainTrailingDotInvalid() {
        XCTAssertFalse(FeedbackDraft(email: "a@b.").emailIsValid)
    }

    // MARK: FeedbackDraft.canSend
    func testCanSendTrueWhenSendableValidEmailFewScreenshots() {
        XCTAssertTrue(FeedbackDraft(rating: 4, email: "a@b.com").canSend)
    }
    func testCanSendFalseWhenNotSendable() {
        XCTAssertFalse(FeedbackDraft(email: "a@b.com").canSend)
    }
    func testCanSendFalseWhenEmailInvalid() {
        XCTAssertFalse(FeedbackDraft(rating: 4, email: "bad").canSend)
    }
    func testTrimmedCommentAndEmail() {
        let draft = FeedbackDraft(comment: "  hi  ", email: "  a@b.com ")
        XCTAssertEqual(draft.trimmedComment, "hi")
        XCTAssertEqual(draft.trimmedEmail, "a@b.com")
    }

    // MARK: FeedbackError.errorDescription
    func testErrorDescriptions() {
        XCTAssertEqual(FeedbackError.validation("rating").errorDescription,
                       "Some details look off: rating")
        XCTAssertEqual(FeedbackError.validation(nil).errorDescription,
                       "Some details look off. Please check and try again.")
        XCTAssertNotNil(FeedbackError.domainBlocked.errorDescription)
        XCTAssertNotNil(FeedbackError.server.errorDescription)
        XCTAssertEqual(FeedbackError.unexpected(418).errorDescription,
                       "Unexpected response (418). Please try again.")
        XCTAssertNotNil(FeedbackError.network.errorDescription)
        XCTAssertNotNil(FeedbackError.decoding.errorDescription)
    }

    // MARK: PendingScreenshot.imageMimeType + default id
    func testMimeTypes() {
        XCTAssertEqual(PendingScreenshot.imageMimeType(forPathExtension: "PNG"), "image/png")
        XCTAssertEqual(PendingScreenshot.imageMimeType(forPathExtension: "jpg"), "image/jpeg")
        XCTAssertEqual(PendingScreenshot.imageMimeType(forPathExtension: "jpeg"), "image/jpeg")
        XCTAssertEqual(PendingScreenshot.imageMimeType(forPathExtension: "gif"), "image/gif")
        XCTAssertEqual(PendingScreenshot.imageMimeType(forPathExtension: "heic"), "image/heic")
        XCTAssertEqual(PendingScreenshot.imageMimeType(forPathExtension: "tiff"), "image/tiff")
        XCTAssertEqual(PendingScreenshot.imageMimeType(forPathExtension: "tif"), "image/tiff")
        XCTAssertNil(PendingScreenshot.imageMimeType(forPathExtension: "txt"))
    }
    func testPendingScreenshotDefaultIdIsUnique() {
        let a = PendingScreenshot(data: Data([0x1]), fileName: "a.png", mimeType: "image/png")
        let b = PendingScreenshot(data: Data([0x1]), fileName: "a.png", mimeType: "image/png")
        XCTAssertNotEqual(a.id, b.id)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodegen generate && xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' -only-testing:OpenCaffeineTests/FeedbackModelsTests test`
Expected: FAIL — `cannot find 'FeedbackDraft' / 'FeedbackError' / 'PendingScreenshot' in scope`.

- [ ] **Step 3: Write the models**

Create `OpenCaffeine/Services/FeedbackModels.swift`:

```swift
import Foundation

/// A screenshot already uploaded to Usero (POST /api/screenshots), attached
/// verbatim to a feedback submission's `screenshots` array.
struct ScreenshotRef: Codable, Equatable {
    let fileName: String
    let url: String
    let fileSize: Int
    let width: Int?
    let height: Int?
    let mimeType: String
}

/// A locally-chosen image awaiting upload when the user taps Send.
struct PendingScreenshot: Identifiable, Equatable {
    let id: UUID
    let data: Data
    let fileName: String
    let mimeType: String

    init(id: UUID = UUID(), data: Data, fileName: String, mimeType: String) {
        self.id = id
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }

    /// Maps a file extension to an `image/*` MIME type, or nil if unsupported.
    static func imageMimeType(forPathExtension ext: String) -> String? {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "heic": return "image/heic"
        case "tiff", "tif": return "image/tiff"
        default: return nil
        }
    }
}

/// User-facing feedback errors with friendly messages.
enum FeedbackError: LocalizedError, Equatable {
    case validation(String?)
    case domainBlocked
    case server
    case unexpected(Int)
    case network
    case decoding

    var errorDescription: String? {
        switch self {
        case .validation(let detail):
            if let detail {
                return "Some details look off: \(detail)"
            }
            return "Some details look off. Please check and try again."
        case .domainBlocked:
            return "Feedback isn’t accepted from this app right now."
        case .server:
            return "Usero ran into a problem. Please try again in a bit."
        case .unexpected(let code):
            return "Unexpected response (\(code)). Please try again."
        case .network:
            return "Couldn’t reach Usero. Check your connection and try again."
        case .decoding:
            return "Usero sent back something unexpected."
        }
    }
}

/// The user's in-progress feedback. Owns validation; the UI binds to it.
struct FeedbackDraft {
    static let maxScreenshots = 3

    var rating: Int?
    var comment: String
    var email: String
    var screenshots: [PendingScreenshot]

    init(rating: Int? = nil, comment: String = "", email: String = "",
         screenshots: [PendingScreenshot] = []) {
        self.rating = rating
        self.comment = comment
        self.email = email
        self.screenshots = screenshots
    }

    var trimmedComment: String {
        comment.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Usero requires at least one of rating or comment.
    var isSendable: Bool {
        rating != nil || !trimmedComment.isEmpty
    }

    /// Empty is allowed (optional); otherwise it must look like an email.
    var emailIsValid: Bool {
        let value = trimmedEmail
        if value.isEmpty { return true }
        if value.contains(" ") { return false }
        guard let at = value.firstIndex(of: "@"), at != value.startIndex else {
            return false
        }
        guard value.firstIndex(of: "@") == value.lastIndex(of: "@") else {
            return false
        }
        let domain = value[value.index(after: at)...]
        guard !domain.isEmpty, domain.contains(".") else { return false }
        return domain.first != "." && domain.last != "."
    }

    var canSend: Bool {
        isSendable && emailIsValid && screenshots.count <= FeedbackDraft.maxScreenshots
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' -only-testing:OpenCaffeineTests/FeedbackModelsTests test`
Expected: PASS (all FeedbackModelsTests green).

- [ ] **Step 5: Lint then commit**

Run: `swiftlint --path OpenCaffeine/Services/FeedbackModels.swift` → Expected: no violations.

```bash
git add OpenCaffeine/Services/FeedbackModels.swift OpenCaffeineTests/FeedbackModelsTests.swift
git commit -m "feat: add feedback draft, errors, and screenshot models

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Request builders & response parsers

**Files:**
- Create: `OpenCaffeine/Services/FeedbackTransport.swift`
- Test: `OpenCaffeineTests/FeedbackTransportTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `OpenCaffeineTests/FeedbackTransportTests.swift`:

```swift
@testable import OpenCaffeine
import XCTest

final class FeedbackTransportTests: XCTestCase {
    private let url = URL(string: "https://example.test/feedback")!

    private func body(_ request: URLRequest) -> [String: Any] {
        guard let data = request.httpBody,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return json
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
    func testScreenshotRequestMultipart() {
        let shot = PendingScreenshot(data: Data("PNGBYTES".utf8),
                                     fileName: "shot.png", mimeType: "image/png")
        let request = FeedbackRequest.screenshot(
            url: url, clientId: "client_x", screenshot: shot, boundary: "BND")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"),
                       "multipart/form-data; boundary=BND")
        let text = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
        XCTAssertTrue(text.contains("--BND"))
        XCTAssertTrue(text.contains("name=\"clientId\""))
        XCTAssertTrue(text.contains("client_x"))
        XCTAssertTrue(text.contains("name=\"screenshot\"; filename=\"shot.png\""))
        XCTAssertTrue(text.contains("Content-Type: image/png"))
        XCTAssertTrue(text.contains("PNGBYTES"))
        XCTAssertTrue(text.contains("--BND--"))
    }

    // MARK: response parsers
    private func http(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    func testFeedbackIdSuccess() throws {
        let data = Data(#"{"success":true,"feedbackId":"abc123"}"#.utf8)
        let id = try FeedbackResponse.feedbackId(data: data, response: http(200))
        XCTAssertEqual(id, "abc123")
    }

    func testScreenshotSuccess() throws {
        let data = Data(#"""
        {"success":true,"screenshot":{"fileName":"a.png","url":"https://u/a.png",
        "fileSize":48211,"width":1280,"height":800,"mimeType":"image/png"}}
        """#.utf8)
        let ref = try FeedbackResponse.screenshot(data: data, response: http(200))
        XCTAssertEqual(ref.fileName, "a.png")
        XCTAssertEqual(ref.fileSize, 48211)
        XCTAssertEqual(ref.width, 1280)
        XCTAssertEqual(ref.mimeType, "image/png")
    }

    func testValidationErrorWithDetail() {
        let data = Data(#"{"error":"Invalid data provided"}"#.utf8)
        XCTAssertThrowsError(try FeedbackResponse.feedbackId(data: data, response: http(400))) {
            XCTAssertEqual($0 as? FeedbackError, .validation("Invalid data provided"))
        }
    }

    func testValidationErrorWithoutDetail() {
        XCTAssertThrowsError(try FeedbackResponse.feedbackId(data: Data("x".utf8), response: http(400))) {
            XCTAssertEqual($0 as? FeedbackError, .validation(nil))
        }
    }

    func testDomainBlocked() {
        XCTAssertThrowsError(try FeedbackResponse.feedbackId(data: Data(), response: http(403))) {
            XCTAssertEqual($0 as? FeedbackError, .domainBlocked)
        }
    }

    func testServerError() {
        XCTAssertThrowsError(try FeedbackResponse.feedbackId(data: Data(), response: http(500))) {
            XCTAssertEqual($0 as? FeedbackError, .server)
        }
    }

    func testUnexpectedStatus() {
        XCTAssertThrowsError(try FeedbackResponse.feedbackId(data: Data(), response: http(418))) {
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

    func testMalformedSuccessIsDecodingError() {
        XCTAssertThrowsError(try FeedbackResponse.feedbackId(data: Data("{}".utf8), response: http(200))) {
            XCTAssertEqual($0 as? FeedbackError, .decoding)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodegen generate && xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' -only-testing:OpenCaffeineTests/FeedbackTransportTests test`
Expected: FAIL — `cannot find 'FeedbackRequest' / 'FeedbackResponse' in scope`.

- [ ] **Step 3: Write the transport**

Create `OpenCaffeine/Services/FeedbackTransport.swift`:

```swift
import Foundation

// Wire DTOs (Usero JSON shapes). Optionals are omitted by the synthesized
// `encodeIfPresent`, so only provided fields are sent.
private struct FeedbackPayload: Encodable {
    let clientId: String
    let rating: Int?
    let comment: String?
    let userEmail: String?
    let environment: String?
    let metadata: [String: String]?
    let screenshots: [ScreenshotRef]?
}

private struct FeedbackSuccess: Decodable {
    let feedbackId: String
}

private struct ScreenshotUploadSuccess: Decodable {
    let screenshot: ScreenshotRef
}

private struct APIErrorBody: Decodable {
    let error: String?
}

/// Pure builders for the two Usero endpoints. URLs are injected so this file
/// stays free of un-coverable string-to-URL fallbacks.
enum FeedbackRequest {
    static func feedback(
        url: URL,
        clientId: String,
        rating: Int?,
        comment: String?,
        email: String?,
        environment: String,
        metadata: [String: String],
        screenshots: [ScreenshotRef]
    ) throws -> URLRequest {
        let payload = FeedbackPayload(
            clientId: clientId,
            rating: rating,
            comment: comment,
            userEmail: email,
            environment: environment,
            metadata: metadata.isEmpty ? nil : metadata,
            screenshots: screenshots.isEmpty ? nil : screenshots
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    static func screenshot(
        url: URL,
        clientId: String,
        screenshot: PendingScreenshot,
        boundary: String
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(clientId: clientId,
                                         screenshot: screenshot, boundary: boundary)
        return request
    }

    static func multipartBody(
        clientId: String, screenshot: PendingScreenshot, boundary: String
    ) -> Data {
        var body = Data()
        func append(_ string: String) {
            if let data = string.data(using: .utf8) { body.append(data) }
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"clientId\"\r\n\r\n")
        append("\(clientId)\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"screenshot\"; "
               + "filename=\"\(screenshot.fileName)\"\r\n")
        append("Content-Type: \(screenshot.mimeType)\r\n\r\n")
        body.append(screenshot.data)
        append("\r\n")
        append("--\(boundary)--\r\n")
        return body
    }
}

/// Pure parsers mapping HTTP status + body to a value or a `FeedbackError`.
enum FeedbackResponse {
    static func feedbackId(data: Data, response: URLResponse) throws -> String {
        try decode(FeedbackSuccess.self, data: data, response: response).feedbackId
    }

    static func screenshot(data: Data, response: URLResponse) throws -> ScreenshotRef {
        try decode(ScreenshotUploadSuccess.self, data: data, response: response).screenshot
    }

    private static func decode<T: Decodable>(
        _ type: T.Type, data: Data, response: URLResponse
    ) throws -> T {
        guard let http = response as? HTTPURLResponse else {
            throw FeedbackError.network
        }
        switch http.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw FeedbackError.decoding
            }
        case 400:
            throw FeedbackError.validation(errorDetail(from: data))
        case 403:
            throw FeedbackError.domainBlocked
        case 500:
            throw FeedbackError.server
        default:
            throw FeedbackError.unexpected(http.statusCode)
        }
    }

    private static func errorDetail(from data: Data) -> String? {
        (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' -only-testing:OpenCaffeineTests/FeedbackTransportTests test`
Expected: PASS (all FeedbackTransportTests green).

- [ ] **Step 5: Lint then commit**

Run: `swiftlint --path OpenCaffeine/Services/FeedbackTransport.swift` → Expected: no violations.

```bash
git add OpenCaffeine/Services/FeedbackTransport.swift OpenCaffeineTests/FeedbackTransportTests.swift
git commit -m "feat: add feedback request builders and response parsers

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: FeedbackService (URLSession shell)

**Files:**
- Create: `OpenCaffeine/Services/FeedbackService.swift`
- Modify: `Scripts/coverage_check.py`

- [ ] **Step 1: Write the service**

Create `OpenCaffeine/Services/FeedbackService.swift`:

```swift
import Foundation

/// Submits feedback to Usero. Implemented by the live `FeedbackService` and by
/// test mocks.
protocol FeedbackSubmitting {
    func uploadScreenshot(_ screenshot: PendingScreenshot) async throws -> ScreenshotRef
    func submit(rating: Int?, comment: String?, email: String?,
                screenshots: [ScreenshotRef]) async throws -> String
}

/// Thin URLSession orchestration over the pure `FeedbackTransport` builders and
/// parsers. Endpoint URLs and runtime metadata live here (the coverage shell).
final class FeedbackService: FeedbackSubmitting {
    static let clientId = "client_8b1cc88ed71c4090"

    private let session: URLSession
    private let feedbackURL = URL(staticString: "https://usero.io/api/feedback")
    private let screenshotURL = URL(staticString: "https://usero.io/api/screenshots")

    init(session: URLSession = .shared) {
        self.session = session
    }

    func uploadScreenshot(_ screenshot: PendingScreenshot) async throws -> ScreenshotRef {
        let request = FeedbackRequest.screenshot(
            url: screenshotURL,
            clientId: Self.clientId,
            screenshot: screenshot,
            boundary: "Boundary-\(UUID().uuidString)"
        )
        do {
            let (data, response) = try await session.data(for: request)
            return try FeedbackResponse.screenshot(data: data, response: response)
        } catch let error as FeedbackError {
            throw error
        } catch {
            throw FeedbackError.network
        }
    }

    func submit(rating: Int?, comment: String?, email: String?,
                screenshots: [ScreenshotRef]) async throws -> String {
        let request = try FeedbackRequest.feedback(
            url: feedbackURL,
            clientId: Self.clientId,
            rating: rating,
            comment: comment,
            email: email,
            environment: Self.environment,
            metadata: Self.metadata(),
            screenshots: screenshots
        )
        do {
            let (data, response) = try await session.data(for: request)
            return try FeedbackResponse.feedbackId(data: data, response: response)
        } catch let error as FeedbackError {
            throw error
        } catch {
            throw FeedbackError.network
        }
    }

    private static var environment: String {
        #if DEBUG
        return "debug"
        #else
        return "production"
        #endif
    }

    private static func metadata() -> [String: String] {
        let info = Bundle.main.infoDictionary
        return [
            "appVersion": info?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build": info?["CFBundleVersion"] as? String ?? "unknown",
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "locale": Locale.current.identifier
        ]
    }
}

private extension URL {
    /// Builds a URL from a compile-time-constant string. Only traps if the
    /// literal is malformed (caught immediately in development).
    init(staticString string: StaticString) {
        guard let url = URL(string: "\(string)") else {
            preconditionFailure("invalid static URL: \(string)")
        }
        self = url
    }
}
```

- [ ] **Step 2: Add the shell to the coverage EXCLUDE**

In `Scripts/coverage_check.py`, inside the `EXCLUDE = { ... }` set, add after the `UpdaterService.swift` line (before the closing `}`):

```python
    # Usero feedback URLSession orchestration over tested transport builders/parsers.
    "OpenCaffeine/Services/FeedbackService.swift",
```

- [ ] **Step 3: Generate, build, verify it compiles**

Run: `xcodegen generate && xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Lint then commit**

Run: `swiftlint --path OpenCaffeine/Services/FeedbackService.swift` → Expected: no violations.

```bash
git add OpenCaffeine/Services/FeedbackService.swift Scripts/coverage_check.py
git commit -m "feat: add FeedbackService URLSession client

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: FeedbackViewModel (state machine)

**Files:**
- Create: `OpenCaffeineTests/Mocks/MockFeedbackService.swift`
- Create: `OpenCaffeine/Settings/FeedbackViewModel.swift`
- Test: `OpenCaffeineTests/FeedbackViewModelTests.swift`

- [ ] **Step 1: Write the mock**

Create `OpenCaffeineTests/Mocks/MockFeedbackService.swift`:

```swift
import Foundation
@testable import OpenCaffeine

final class MockFeedbackService: FeedbackSubmitting {
    var uploadResult: Result<ScreenshotRef, Error>
    var submitResult: Result<String, Error>
    private(set) var uploadCount = 0
    private(set) var submitCalls: [(rating: Int?, comment: String?,
                                    email: String?, screenshots: [ScreenshotRef])] = []

    init(
        uploadResult: Result<ScreenshotRef, Error> = .success(
            ScreenshotRef(fileName: "s.png", url: "https://usero.io/s.png",
                          fileSize: 10, width: 1, height: 1, mimeType: "image/png")),
        submitResult: Result<String, Error> = .success("fb_1")
    ) {
        self.uploadResult = uploadResult
        self.submitResult = submitResult
    }

    func uploadScreenshot(_ screenshot: PendingScreenshot) async throws -> ScreenshotRef {
        uploadCount += 1
        return try uploadResult.get()
    }

    func submit(rating: Int?, comment: String?, email: String?,
                screenshots: [ScreenshotRef]) async throws -> String {
        submitCalls.append((rating, comment, email, screenshots))
        return try submitResult.get()
    }
}

struct DummyError: Error {}
```

- [ ] **Step 2: Write the failing tests**

Create `OpenCaffeineTests/FeedbackViewModelTests.swift`:

```swift
@testable import OpenCaffeine
import XCTest

@MainActor
final class FeedbackViewModelTests: XCTestCase {

    private func shot(_ name: String) -> PendingScreenshot {
        PendingScreenshot(data: Data([0x1, 0x2]), fileName: name, mimeType: "image/png")
    }

    func testSelectRatingSetsAndToggles() {
        let model = FeedbackViewModel(service: MockFeedbackService())
        model.selectRating(3)
        XCTAssertEqual(model.draft.rating, 3)
        model.selectRating(3)
        XCTAssertNil(model.draft.rating)
        model.selectRating(2)
        XCTAssertEqual(model.draft.rating, 2)
    }

    func testCanSendReflectsDraft() {
        let model = FeedbackViewModel(service: MockFeedbackService())
        XCTAssertFalse(model.canSend)
        model.selectRating(4)
        XCTAssertTrue(model.canSend)
    }

    func testSendIsNoOpWhenNotSendable() async {
        let service = MockFeedbackService()
        let model = FeedbackViewModel(service: service)
        await model.send()
        XCTAssertEqual(model.phase, .idle)
        XCTAssertTrue(service.submitCalls.isEmpty)
    }

    func testSendRatingOnlySucceedsAndResets() async {
        let service = MockFeedbackService()
        let model = FeedbackViewModel(service: service, draft: FeedbackDraft(rating: 4))
        await model.send()
        XCTAssertEqual(model.phase, .success)
        XCTAssertNil(model.draft.rating)
        XCTAssertEqual(service.submitCalls.count, 1)
        XCTAssertEqual(service.submitCalls.first?.rating, 4)
        XCTAssertNil(service.submitCalls.first?.comment)
        XCTAssertNil(service.submitCalls.first?.email)
    }

    func testSendForwardsCommentAndEmail() async {
        let service = MockFeedbackService()
        let draft = FeedbackDraft(rating: 2, comment: "  hello  ", email: " a@b.com ")
        let model = FeedbackViewModel(service: service, draft: draft)
        await model.send()
        XCTAssertEqual(service.submitCalls.first?.comment, "hello")
        XCTAssertEqual(service.submitCalls.first?.email, "a@b.com")
    }

    func testSendUploadsScreenshotsBeforeSubmit() async {
        let service = MockFeedbackService()
        var draft = FeedbackDraft(rating: 3)
        draft.screenshots = [shot("a.png"), shot("b.png")]
        let model = FeedbackViewModel(service: service, draft: draft)
        await model.send()
        XCTAssertEqual(service.uploadCount, 2)
        XCTAssertEqual(service.submitCalls.first?.screenshots.count, 2)
        XCTAssertEqual(model.phase, .success)
    }

    func testSubmitFailureKeepsDraftAndSetsFailed() async {
        let service = MockFeedbackService(submitResult: .failure(FeedbackError.server))
        let model = FeedbackViewModel(service: service, draft: FeedbackDraft(rating: 4))
        await model.send()
        XCTAssertEqual(model.phase, .failed(FeedbackError.server.errorDescription ?? ""))
        XCTAssertEqual(model.draft.rating, 4)
    }

    func testNonLocalizedErrorUsesGenericMessage() async {
        let service = MockFeedbackService(submitResult: .failure(DummyError()))
        let model = FeedbackViewModel(service: service, draft: FeedbackDraft(rating: 4))
        await model.send()
        XCTAssertEqual(model.phase, .failed("Something went wrong. Please try again."))
    }

    func testUploadFailureShortCircuitsSubmit() async {
        let service = MockFeedbackService(uploadResult: .failure(FeedbackError.network))
        var draft = FeedbackDraft(rating: 4)
        draft.screenshots = [shot("a.png")]
        let model = FeedbackViewModel(service: service, draft: draft)
        await model.send()
        XCTAssertEqual(service.uploadCount, 1)
        XCTAssertTrue(service.submitCalls.isEmpty)
        XCTAssertEqual(model.phase, .failed(FeedbackError.network.errorDescription ?? ""))
    }

    func testAddScreenshotsCapsAtThree() {
        let model = FeedbackViewModel(service: MockFeedbackService())
        model.addScreenshots([shot("1.png"), shot("2.png")])
        XCTAssertNil(model.attachmentNotice)
        model.addScreenshots([shot("3.png"), shot("4.png")])
        XCTAssertEqual(model.draft.screenshots.count, 3)
        XCTAssertNotNil(model.attachmentNotice)
        model.addScreenshots([shot("5.png")])
        XCTAssertEqual(model.draft.screenshots.count, 3)
    }

    func testRemoveScreenshot() {
        let model = FeedbackViewModel(service: MockFeedbackService())
        let only = shot("1.png")
        model.addScreenshots([only])
        model.removeScreenshot(only.id)
        XCTAssertTrue(model.draft.screenshots.isEmpty)
    }

    func testTerminalPhaseClearsOnEdit() async {
        let model = FeedbackViewModel(service: MockFeedbackService(), draft: FeedbackDraft(rating: 4))
        await model.send()
        XCTAssertEqual(model.phase, .success)
        model.selectRating(2)   // success -> idle
        XCTAssertEqual(model.phase, .idle)

        let failing = FeedbackViewModel(
            service: MockFeedbackService(submitResult: .failure(FeedbackError.server)),
            draft: FeedbackDraft(rating: 4))
        await failing.send()
        XCTAssertEqual(failing.phase, .failed(FeedbackError.server.errorDescription ?? ""))
        failing.removeScreenshot(UUID())  // failed -> idle
        XCTAssertEqual(failing.phase, .idle)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `xcodegen generate && xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' -only-testing:OpenCaffeineTests/FeedbackViewModelTests test`
Expected: FAIL — `cannot find 'FeedbackViewModel' in scope`.

- [ ] **Step 4: Write the view model**

Create `OpenCaffeine/Settings/FeedbackViewModel.swift`:

```swift
import Foundation

/// Drives the Feedback tab: owns the draft, validation gating, and the
/// submission state machine. Networking is delegated to `FeedbackSubmitting`.
@MainActor
final class FeedbackViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case sending
        case success
        case failed(String)
    }

    @Published var draft: FeedbackDraft
    @Published private(set) var phase: Phase = .idle
    @Published var attachmentNotice: String?

    private let service: FeedbackSubmitting

    init(service: FeedbackSubmitting, draft: FeedbackDraft = FeedbackDraft()) {
        self.service = service
        self.draft = draft
    }

    var canSend: Bool {
        draft.canSend && phase != .sending
    }

    func selectRating(_ value: Int) {
        draft.rating = (draft.rating == value) ? nil : value
        clearTerminalPhase()
    }

    func addScreenshots(_ shots: [PendingScreenshot]) {
        let remaining = FeedbackDraft.maxScreenshots - draft.screenshots.count
        guard remaining > 0 else {
            attachmentNotice = "You can attach up to \(FeedbackDraft.maxScreenshots) screenshots."
            return
        }
        if shots.count > remaining {
            attachmentNotice = "Only \(remaining) more screenshot(s) can be attached."
        } else {
            attachmentNotice = nil
        }
        draft.screenshots.append(contentsOf: shots.prefix(remaining))
        clearTerminalPhase()
    }

    func removeScreenshot(_ id: UUID) {
        draft.screenshots.removeAll { $0.id == id }
        attachmentNotice = nil
        clearTerminalPhase()
    }

    func send() async {
        guard draft.canSend, phase != .sending else { return }
        phase = .sending
        do {
            var refs: [ScreenshotRef] = []
            for shot in draft.screenshots {
                refs.append(try await service.uploadScreenshot(shot))
            }
            let comment = draft.trimmedComment.isEmpty ? nil : draft.trimmedComment
            let email = draft.trimmedEmail.isEmpty ? nil : draft.trimmedEmail
            _ = try await service.submit(rating: draft.rating, comment: comment,
                                         email: email, screenshots: refs)
            draft = FeedbackDraft()
            attachmentNotice = nil
            phase = .success
        } catch {
            phase = .failed(message(for: error))
        }
    }

    private func clearTerminalPhase() {
        if phase == .success || isFailed(phase) {
            phase = .idle
        }
    }

    private func isFailed(_ phase: Phase) -> Bool {
        if case .failed = phase { return true }
        return false
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription
            ?? "Something went wrong. Please try again."
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' -only-testing:OpenCaffeineTests/FeedbackViewModelTests test`
Expected: PASS (all FeedbackViewModelTests green).

- [ ] **Step 6: Lint then commit**

Run: `swiftlint --path OpenCaffeine/Settings/FeedbackViewModel.swift` → Expected: no violations.

```bash
git add OpenCaffeine/Settings/FeedbackViewModel.swift OpenCaffeineTests/FeedbackViewModelTests.swift OpenCaffeineTests/Mocks/MockFeedbackService.swift
git commit -m "feat: add FeedbackViewModel submission state machine

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: RatingFace (mockup geometry)

**Files:**
- Create: `OpenCaffeine/Settings/RatingFace.swift`
- Modify: `Scripts/coverage_check.py`

- [ ] **Step 1: Write the face views**

Create `OpenCaffeine/Settings/RatingFace.swift`:

```swift
import SwiftUI

/// One 1–4 face from the mockup, drawn from its exact 20×20 SVG geometry
/// (outer circle r8.3, stroke 1.6, round caps). Monochrome: selected uses
/// `.primary` over a faint chip, unselected `.secondary`.
struct RatingFace: View {
    let value: Int
    let isSelected: Bool

    var body: some View {
        Canvas { context, size in
            let unit = size.width / 20.0
            context.scaleBy(x: unit, y: unit)
            let shading = GraphicsContext.Shading.color(isSelected ? .primary : .secondary)
            let stroke = StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)

            context.stroke(
                Path(ellipseIn: CGRect(x: 1.7, y: 1.7, width: 16.6, height: 16.6)),
                with: shading, style: stroke)
            drawEyes(context, shading: shading, stroke: stroke)
            if value == 1 {
                context.stroke(brow(from: 5.7, control: 7.2, to: 8.6), with: shading, style: stroke)
                context.stroke(brow(from: 11.4, control: 12.8, to: 14.3), with: shading, style: stroke)
            }
            context.stroke(mouth(), with: shading, style: stroke)
        }
        .frame(width: 34, height: 34)
        .padding(5)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06))
            }
        }
        .contentShape(Rectangle())
    }

    private func drawEyes(_ context: GraphicsContext,
                          shading: GraphicsContext.Shading, stroke: StrokeStyle) {
        if value == 4 {
            context.stroke(eyeArc(from: 5.9, control: 7.2, to: 8.5), with: shading, style: stroke)
            context.stroke(eyeArc(from: 11.5, control: 12.8, to: 14.1), with: shading, style: stroke)
            return
        }
        let eyeY: CGFloat = value == 1 ? 8.6 : (value == 2 ? 8.4 : 8.2)
        for centerX in [7.2, 12.8] {
            let dot = Path(ellipseIn: CGRect(x: centerX - 0.62, y: eyeY - 0.62,
                                             width: 1.24, height: 1.24))
            context.fill(dot, with: shading)
        }
    }

    private func eyeArc(from startX: CGFloat, control: CGFloat, to endX: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: startX, y: 8.8))
        path.addQuadCurve(to: CGPoint(x: endX, y: 8.8), control: CGPoint(x: control, y: 7.2))
        return path
    }

    private func brow(from startX: CGFloat, control: CGFloat, to endX: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: startX, y: 6.9))
        path.addQuadCurve(to: CGPoint(x: endX, y: 6.9), control: CGPoint(x: control, y: 6.1))
        return path
    }

    private func mouth() -> Path {
        var path = Path()
        switch value {
        case 1:
            path.move(to: CGPoint(x: 6.6, y: 13.7))
            path.addQuadCurve(to: CGPoint(x: 13.4, y: 13.7), control: CGPoint(x: 10, y: 11.2))
        case 2:
            path.move(to: CGPoint(x: 6.9, y: 12.4))
            path.addLine(to: CGPoint(x: 13.1, y: 12.4))
        case 3:
            path.move(to: CGPoint(x: 6.7, y: 11.7))
            path.addQuadCurve(to: CGPoint(x: 13.3, y: 11.7), control: CGPoint(x: 10, y: 14.1))
        default:
            path.move(to: CGPoint(x: 6, y: 11.3))
            path.addQuadCurve(to: CGPoint(x: 14, y: 11.3), control: CGPoint(x: 10, y: 15.3))
        }
        return path
    }
}

/// The row of four faces. `onSelect` toggles via the view model.
struct FaceRatingRow: View {
    let selection: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...4, id: \.self) { value in
                Button { onSelect(value) } label: {
                    RatingFace(value: value, isSelected: selection == value)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

- [ ] **Step 2: Add the shell to the coverage EXCLUDE**

In `Scripts/coverage_check.py`, in the `EXCLUDE` set, add alongside the other `Settings/*View.swift` entries:

```python
    # Canvas-drawn rating faces (declarative view shell).
    "OpenCaffeine/Settings/RatingFace.swift",
```

- [ ] **Step 3: Generate, build, verify it compiles**

Run: `xcodegen generate && xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Lint then commit**

Run: `swiftlint --path OpenCaffeine/Settings/RatingFace.swift` → Expected: no violations.

```bash
git add OpenCaffeine/Settings/RatingFace.swift Scripts/coverage_check.py
git commit -m "feat: add rating face views matching the mockup

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: FeedbackSettingsView (the tab)

**Files:**
- Create: `OpenCaffeine/Settings/FeedbackSettingsView.swift`
- Modify: `Scripts/coverage_check.py`

- [ ] **Step 1: Write the view**

Create `OpenCaffeine/Settings/FeedbackSettingsView.swift`:

```swift
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The "Feedback" preferences tab: a 1–4 face rating, comment, email, and
/// screenshot attachments, submitted to Usero. View shell — excluded from the
/// coverage gate; logic lives in `FeedbackViewModel` / `Feedback*` types.
struct FeedbackSettingsView: View {
    @StateObject private var model: FeedbackViewModel

    init(service: FeedbackSubmitting = FeedbackService()) {
        _model = StateObject(wrappedValue: FeedbackViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ratingSection
                tellUsMoreSection
                sendSection
                footer
            }
            .padding(20)
        }
    }

    // MARK: Rating

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroupLabel(text: "Your Rating")
            SettingsGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How would you rate Open Caffeine?").font(.system(size: 13))
                    FaceRatingRow(selection: model.draft.rating, onSelect: model.selectRating)
                    Text("Tap a face — 1 to 4.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
    }

    // MARK: Tell us more

    private var tellUsMoreSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroupLabel(text: "Tell Us More")
            SettingsGroup {
                VStack(spacing: 0) {
                    commentField
                    Divider().padding(.leading, 14)
                    emailField
                    Divider().padding(.leading, 14)
                    screenshotField
                }
            }
        }
    }

    private var commentField: some View {
        fieldContainer(title: "Comment", caption: "Optional") {
            TextField("What’s working well? What would you change?",
                      text: $model.draft.comment, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .modifier(InputBackground())
        }
    }

    private var emailField: some View {
        fieldContainer(title: "Email", caption: "Optional — so we can reply.") {
            VStack(alignment: .leading, spacing: 4) {
                TextField("you@example.com", text: $model.draft.email)
                    .textFieldStyle(.plain)
                    .modifier(InputBackground())
                if !model.draft.emailIsValid {
                    Text("That doesn’t look like a valid email.")
                        .font(.system(size: 11)).foregroundStyle(.red)
                }
            }
        }
    }

    private var screenshotField: some View {
        fieldContainer(title: "Screenshot",
                       caption: "Optional — attach what you’re looking at.") {
            VStack(alignment: .leading, spacing: 8) {
                if !model.draft.screenshots.isEmpty { thumbnails }
                Button { pickScreenshots() } label: {
                    Label("Choose Image…", systemImage: "camera")
                }
                .disabled(model.draft.screenshots.count >= FeedbackDraft.maxScreenshots)
                if let notice = model.attachmentNotice {
                    Text(notice).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var thumbnails: some View {
        HStack(spacing: 8) {
            ForEach(model.draft.screenshots) { shot in
                if let image = NSImage(data: shot.data) {
                    Image(nsImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(alignment: .topTrailing) {
                            Button { model.removeScreenshot(shot.id) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, .black.opacity(0.5))
                            }
                            .buttonStyle(.plain).padding(2)
                        }
                }
            }
        }
    }

    // MARK: Send + footer

    private var sendSection: some View {
        VStack(spacing: 8) {
            Button { Task { await model.send() } } label: {
                HStack(spacing: 6) {
                    if model.phase == .sending { ProgressView().controlSize(.small) }
                    Text(model.phase == .sending ? "Sending…" : "Send Feedback")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!model.canSend)
            statusBanner
        }
        .padding(.top, 18)
    }

    @ViewBuilder private var statusBanner: some View {
        switch model.phase {
        case .success:
            Label("Thanks for the feedback!", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12)).foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12)).foregroundStyle(.red)
        default:
            EmptyView()
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text("Powered by").font(.system(size: 11)).foregroundStyle(.secondary)
            Button("Usero") { openUsero() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tint)
        }
        .padding(.top, 16)
    }

    // MARK: Helpers

    private func fieldContainer<Content: View>(
        title: String, caption: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 13))
                Spacer()
                Text(caption).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            content()
        }
        .padding(14)
    }

    private func pickScreenshots() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .heic, .tiff, .image]
        guard panel.runModal() == .OK else { return }
        model.addScreenshots(panel.urls.compactMap(Self.pendingScreenshot(from:)))
    }

    private static func pendingScreenshot(from url: URL) -> PendingScreenshot? {
        guard let mime = PendingScreenshot.imageMimeType(forPathExtension: url.pathExtension),
              let data = try? Data(contentsOf: url),
              data.count <= 10 * 1024 * 1024 else { return nil }
        return PendingScreenshot(data: data, fileName: url.lastPathComponent, mimeType: mime)
    }

    private func openUsero() {
        if let url = URL(string: "https://usero.io") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// White rounded input background matching the mockup's text fields.
private struct InputBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5))
    }
}
```

- [ ] **Step 2: Add the shell to the coverage EXCLUDE**

In `Scripts/coverage_check.py`, in the `EXCLUDE` set, add alongside the other `Settings/*View.swift` entries:

```python
    "OpenCaffeine/Settings/FeedbackSettingsView.swift",
```

- [ ] **Step 3: Generate, build, verify it compiles**

Run: `xcodegen generate && xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Lint then commit**

Run: `swiftlint --path OpenCaffeine/Settings/FeedbackSettingsView.swift` → Expected: no violations.

```bash
git add OpenCaffeine/Settings/FeedbackSettingsView.swift Scripts/coverage_check.py
git commit -m "feat: add Feedback settings tab view

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Wire the tab into PreferencesScene

**Files:**
- Modify: `OpenCaffeine/Settings/PreferencesScene.swift`

- [ ] **Step 1: Add `.feedback` to the page enum**

In `OpenCaffeine/Settings/PreferencesScene.swift`, change:

```swift
    enum PrefPage: Hashable {
        case general, battery, updates
        var title: String {
            switch self {
            case .general: return "General"
            case .battery: return "Duration & Battery"
            case .updates: return "Updates"
            }
        }
    }
```

to:

```swift
    enum PrefPage: Hashable {
        case general, battery, updates, feedback
        var title: String {
            switch self {
            case .general: return "General"
            case .battery: return "Duration & Battery"
            case .updates: return "Updates"
            case .feedback: return "Feedback"
            }
        }
    }
```

- [ ] **Step 2: Add the sidebar row**

In the `sidebar` `VStack(spacing: 2)`, after the Updates `NavRow`, add:

```swift
                NavRow(title: "Feedback", systemImage: "text.bubble", tint: .pink,
                       selected: page == .feedback) { page = .feedback }
```

- [ ] **Step 3: Add the detail case**

In the `detail` `switch page`, after the `case .updates:` branch, add:

```swift
            case .feedback:
                FeedbackSettingsView()
```

- [ ] **Step 4: Generate, build, run the app**

Run: `xcodegen generate && xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build`
Expected: BUILD SUCCEEDED.

Launch the built app, open Settings (menu bar → Settings), click the **Feedback** tab.
Expected: the tab shows the four faces, comment/email/screenshot fields, a disabled "Send Feedback" button, and the "Powered by Usero" footer.

- [ ] **Step 5: Lint then commit**

Run: `swiftlint --path OpenCaffeine/Settings/PreferencesScene.swift` → Expected: no violations.

```bash
git add OpenCaffeine/Settings/PreferencesScene.swift
git commit -m "feat: add Feedback tab to settings sidebar

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Full verification (suite, lint, coverage, manual)

**Files:** none (verification only).

- [ ] **Step 1: Run the entire test suite**

Run: `xcodegen generate && xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' test`
Expected: TEST SUCCEEDED — all existing tests plus the three new Feedback test classes pass.

- [ ] **Step 2: Run SwiftLint over the whole project**

Run: `swiftlint`
Expected: no violations (no new warnings or errors).

- [ ] **Step 3: Run the coverage gate**

Run: `Scripts/coverage-gate.sh`
Expected: `✅ All logic files at 100% line coverage.` with no stale EXCLUDE entries. If `FeedbackModels.swift`, `FeedbackTransport.swift`, or `FeedbackViewModel.swift` report <100%, add the missing-branch test and re-run.

- [ ] **Step 4: Manual verification against the mockup**

Launch the app and verify each:
- Feedback tab styling matches the other tabs; all four faces render (frown → flat → smile → big smile) and selecting/clearing works.
- "Send Feedback" stays disabled until a rating OR non-empty comment exists.
- Entering a malformed email shows the inline hint and keeps Send disabled.
- "Choose Image…" attaches up to 3 thumbnails; the remove (×) works; a 4th attempt shows the notice.
- A real submission (rating 4 + a short comment) flips to "Sending…" then "Thanks for the feedback!" and clears the form. Confirm it appears in the Usero dashboard.
- With Wi-Fi off, Send shows a friendly error and the form is preserved for retry.
- Toggle light/dark mode — faces and inputs remain legible.
- "Usero" in the footer opens https://usero.io in the browser.

- [ ] **Step 5: Final commit (if any manual fixes were needed)**

```bash
git add -A
git commit -m "test: verify feedback tab end-to-end

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Feedback tab in sidebar → Task 7. ✓
- 1–4 faces, exact geometry, monochrome → Task 5. ✓
- Comment / email / screenshot fields → Task 6. ✓
- Validation (`isSendable`, email, ≤3) → Tasks 1 & 4. ✓
- Submit + screenshot upload to Usero → Tasks 2 & 3. ✓
- Diagnostics metadata + environment → Task 3. ✓
- State machine idle→sending→success|failed → Task 4. ✓
- Error mapping (400/403/500/other/network/decoding) → Task 2. ✓
- Powered-by-Usero link → Task 6. ✓
- 100% coverage / shells excluded → Tasks 3, 5, 6, 8. ✓
- Non-goals (no capture, no session replay, no draft persistence) → respected. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code and exact commands. ✓

**Type consistency:** `FeedbackSubmitting.submit(rating:comment:email:screenshots:)` and `uploadScreenshot(_:)` are defined identically in Task 3, used by the VM (Task 4), mock (Task 4), and tests. `FeedbackRequest.feedback/screenshot/multipartBody` and `FeedbackResponse.feedbackId/screenshot` match between Task 2's source and tests. `FeedbackDraft` initializer and computed props match across Tasks 1 & 4. `FeedbackViewModel.Phase` cases and `selectRating`/`addScreenshots`/`removeScreenshot`/`send`/`canSend`/`attachmentNotice` names are consistent between Task 4's source and tests, and the view (Task 6). `RatingFace` / `FaceRatingRow` signatures match between Task 5 and Task 6. ✓
