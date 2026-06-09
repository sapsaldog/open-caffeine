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
    func testEmailEmptyDomainInvalid() {
        XCTAssertFalse(FeedbackDraft(email: "a@").emailIsValid)
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
    func testCanSendFalseWhenTooManyScreenshots() {
        let shots = (0..<4).map {
            PendingScreenshot(data: Data([UInt8($0)]), fileName: "\($0).png", mimeType: "image/png")
        }
        XCTAssertFalse(FeedbackDraft(rating: 4, screenshots: shots).canSend)
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
        XCTAssertEqual(FeedbackError.domainBlocked.errorDescription,
                       "Feedback isn't accepted from this app right now.")
        XCTAssertEqual(FeedbackError.server.errorDescription,
                       "Usero ran into a problem. Please try again in a bit.")
        XCTAssertEqual(FeedbackError.unexpected(418).errorDescription,
                       "Unexpected response (418). Please try again.")
        XCTAssertEqual(FeedbackError.network.errorDescription,
                       "Couldn't reach Usero. Check your connection and try again.")
        XCTAssertEqual(FeedbackError.decoding.errorDescription,
                       "Usero sent back something unexpected.")
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
        let first = PendingScreenshot(data: Data([0x1]), fileName: "a.png", mimeType: "image/png")
        let second = PendingScreenshot(data: Data([0x1]), fileName: "a.png", mimeType: "image/png")
        XCTAssertNotEqual(first.id, second.id)
    }
}
