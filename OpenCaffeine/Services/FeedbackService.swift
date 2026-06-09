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
