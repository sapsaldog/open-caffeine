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
            TextField("What's working well? What would you change?",
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
                    Text("That doesn't look like a valid email.")
                        .font(.system(size: 11)).foregroundStyle(.red)
                }
            }
        }
    }

    private var screenshotField: some View {
        fieldContainer(title: "Screenshot",
                       caption: "Optional — attach what you're looking at.") {
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
                .foregroundStyle(Color.accentColor)
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
