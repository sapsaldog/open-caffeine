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
        model.selectRating(2)
        XCTAssertEqual(model.phase, .idle)

        let failing = FeedbackViewModel(
            service: MockFeedbackService(submitResult: .failure(FeedbackError.server)),
            draft: FeedbackDraft(rating: 4))
        await failing.send()
        XCTAssertEqual(failing.phase, .failed(FeedbackError.server.errorDescription ?? ""))
        failing.removeScreenshot(UUID())
        XCTAssertEqual(failing.phase, .idle)
    }

    func testAddScreenshotsClearsTerminalPhase() async {
        let model = FeedbackViewModel(service: MockFeedbackService(), draft: FeedbackDraft(rating: 4))
        await model.send()
        XCTAssertEqual(model.phase, .success)
        model.addScreenshots([shot("a.png")])
        XCTAssertEqual(model.phase, .idle)
    }

    func testAddScreenshotsReportsRejectedFiles() {
        let model = FeedbackViewModel(service: MockFeedbackService())
        model.addScreenshots([shot("a.png")], rejectedCount: 2)
        XCTAssertEqual(model.draft.screenshots.count, 1)
        XCTAssertNotNil(model.attachmentNotice)
    }

    func testEditingCommentClearsTerminalPhase() async {
        let model = FeedbackViewModel(service: MockFeedbackService(), draft: FeedbackDraft(rating: 4))
        await model.send()
        XCTAssertEqual(model.phase, .success)
        model.draft.comment = "more"
        XCTAssertEqual(model.phase, .idle)
    }
}
