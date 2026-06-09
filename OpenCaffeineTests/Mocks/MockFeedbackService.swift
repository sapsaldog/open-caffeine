import Foundation
@testable import OpenCaffeine

struct SubmitCall {
    let rating: Int?
    let comment: String?
    let email: String?
    let screenshots: [ScreenshotRef]
}

final class MockFeedbackService: FeedbackSubmitting {
    var uploadResult: Result<ScreenshotRef, Error>
    var submitResult: Result<String, Error>
    private(set) var uploadCount = 0
    private(set) var submitCalls: [SubmitCall] = []

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
        submitCalls.append(SubmitCall(rating: rating, comment: comment,
                                     email: email, screenshots: screenshots))
        return try submitResult.get()
    }
}

struct DummyError: Error {}
