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
