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
    // Pure assembler of all wire fields; a parameter object would only add indirection.
    // swiftlint:disable:next function_parameter_count
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

    private static func multipartBody(
        clientId: String, screenshot: PendingScreenshot, boundary: String
    ) -> Data {
        var body = Data()
        func append(_ string: String) {
            body.append(Data(string.utf8))
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
