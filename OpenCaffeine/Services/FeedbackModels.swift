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
        case "heif": return "image/heif"
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
                return String(localized: "Some details look off: \(detail)",
                              comment: "Feedback validation error; %@ = detail text from the server")
            }
            return String(localized: "Some details look off. Please check and try again.",
                          comment: "Feedback validation error without details")
        case .domainBlocked:
            return String(localized: "Feedback isn't accepted from this app right now.",
                          comment: "Feedback error: Usero rejected this app (HTTP 403)")
        case .server:
            return String(localized: "Usero ran into a problem. Please try again in a bit.",
                          comment: "Feedback error: Usero server error (HTTP 500)")
        case .unexpected(let code):
            return String(localized: "Unexpected response (\(code)). Please try again.",
                          comment: "Feedback error; %lld = HTTP status code")
        case .network:
            return String(localized: "Couldn't reach Usero. Check your connection and try again.",
                          comment: "Feedback error: network failure")
        case .decoding:
            return String(localized: "Usero sent back something unexpected.",
                          comment: "Feedback error: response could not be decoded")
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
        guard let atIndex = value.firstIndex(of: "@"), atIndex != value.startIndex else {
            return false
        }
        guard value.firstIndex(of: "@") == value.lastIndex(of: "@") else {
            return false
        }
        let domain = value[value.index(after: atIndex)...]
        guard !domain.isEmpty, domain.contains(".") else { return false }
        return domain.first != "." && domain.last != "."
    }

    var canSend: Bool {
        isSendable && emailIsValid && screenshots.count <= FeedbackDraft.maxScreenshots
    }
}
