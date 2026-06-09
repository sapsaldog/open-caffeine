# Feedback Tab — Design Spec

**Date:** 2026-06-08
**Status:** Approved (pending user review of this document)
**Author:** Brainstormed with Claude

## Overview

Add a **Feedback** tab to the Settings window so users can rate Open Caffeine
(1–4 faces), leave a comment, optionally share an email, and optionally attach
screenshots. Submissions go to the **Usero** feedback service.

The UI is a faithful native port of the provided mockup
(`C _ Settings pane _ a Feedback tab`), reusing the existing Tahoe
System-Settings primitives (`SettingsGroupLabel` / `SettingsGroup` /
`SettingsRow`) so it matches the other tabs by construction.

## Goals & Non-Goals

**Goals**
- New sidebar tab "Feedback" rendered like the existing tabs.
- 1–4 face rating drawn to match the mockup exactly (monochrome line faces).
- Optional comment, optional email, optional screenshot attachments (upload).
- Submit to Usero (`/api/feedback`, screenshots via `/api/screenshots`).
- Attach app/OS diagnostics (no PII) so reports are triageable.
- Networking logic is unit-tested via pure builders/parsers + a mock service.
- Every source file stays well under the 500-line SwiftLint cap.

**Non-Goals**
- Interactive screen capture (`screencapture -i`) — screenshots are attached by
  picking image files only (user decision).
- Session replay (`sessionReplayId` / `replayOffsetMs`) and web-only fields
  (`pageUrl`, `pageTitle`, `referrer`).
- Persisting drafts across app launches.
- Localization of the feedback copy (English, matching the mockup).

## Scope (Feature List)

1. `Feedback` tab in `PreferencesScene` sidebar (`text.bubble`, pink tile).
2. `YOUR RATING` group: prompt + a row of 4 tappable faces (1–4).
3. `TELL US MORE` group:
   - **Comment** — multiline text field. Optional.
   - **Email** — single-line text field. Optional, validated if non-empty.
   - **Screenshot** — "attach" button + up to 3 removable thumbnails. Optional.
4. **Send Feedback** primary button — disabled until sendable; shows progress;
   success confirmation + form reset; inline error + retry on failure.
5. **Powered by Usero** footer link → opens `https://usero.io`.

## API Contract (Usero)

`clientId` (constant, embedded — it is a public project identifier, not a
secret): **`client_8b1cc88ed71c4090`**. No auth header. HTTPS (no ATS changes).

### Submit feedback
`POST https://usero.io/api/feedback` · `Content-Type: application/json`

Body (we send): `clientId` (required); at least one of `rating` (Int 1–4) or
`comment` (String); `userEmail` (String, optional); `environment`
(`"debug"`/`"production"`); `metadata` (object, ≤10KB); `screenshots` (array of
uploaded refs, optional).

Response `200`: `{ "success": true, "feedbackId": "abc123" }`.
Errors: `400 {error, issues?}`, `403 {error:"Domain not allowed"}`,
`500 {error}`.

### Upload screenshot (one file per request, ≤3 per feedback)
`POST https://usero.io/api/screenshots` · `multipart/form-data`
Fields: `screenshot` (file, `image/*`, ≤10MB), `clientId`.

Response `200`:
```json
{ "success": true,
  "screenshot": { "fileName": "...", "url": "https://usero.io/api/screenshots/...",
                  "fileSize": 48211, "width": 1280, "height": 800, "mimeType": "image/png" } }
```
The returned `screenshot` object is placed verbatim into the feedback
`screenshots` array.

## Rating Faces (exact mockup geometry)

All faces: SVG `viewBox 0 0 20 20`, outer circle `cx=10 cy=10 r=8.3`,
`stroke-width 1.6`, round cap/join, `fill=none`. Monochrome (`currentColor`):
in the light-mode export, unselected ≈ `rgba(0,0,0,0.5)`, selected = full
`rgb(0,0,0)` with a subtle `~0.06` rounded background chip. Native mapping:
unselected `.secondary`, selected `.primary` over `Color.primary.opacity(0.06)`
— so dark mode and accent come for free. Reproduced in SwiftUI `Path` scaled
from the 20×20 space.

| Rating | Expression | Eyes | Mouth `d` | Extra |
|-------:|------------|------|-----------|-------|
| 1 Terrible | frown (∩) | dots `r0.62 @(7.2,8.6)(12.8,8.6)` | `M6.6 13.7 Q10 11.2 13.4 13.7` | brows `M5.7 6.9 Q7.2 6.1 8.6 6.9` / `M11.4 6.9 Q12.8 6.1 14.3 6.9` |
| 2 Bad | flat | dots `@(7.2,8.4)(12.8,8.4)` | `M6.9 12.4 H13.1` | — |
| 3 Good | smile (∪) | dots `@(7.2,8.2)(12.8,8.2)` | `M6.7 11.7 Q10 14.1 13.3 11.7` | — |
| 4 Amazing | big smile | arcs `M5.9 8.8 Q7.2 7.2 8.5 8.8` / `M11.5 8.8 Q12.8 7.2 14.1 8.8` | `M6 11.3 Q10 15.3 14 11.3` | — |

Faces are laid out left→right 1…4. Tapping selects (single selection);
tapping the selected face again clears it (rating becomes `nil`).

## Architecture

Logic is split so the network-free parts are unit-testable; the SwiftUI view is
a thin shell (excluded from the coverage gate, like the other views).

```
FeedbackSettingsView (SwiftUI shell)
  └── FeedbackViewModel  @MainActor ObservableObject
        ├── FeedbackDraft (value type: rating?, comment, email, [PendingScreenshot]) — validation
        ├── pending screenshots provided by the view via NSOpenPanel
        └── submit() → FeedbackSubmitting (protocol)
              └── FeedbackService (concrete)
                    ├── FeedbackRequest.make…() -> URLRequest   (pure)
                    ├── FeedbackResponse.parse…() throws -> …    (pure)
                    └── URLSession (injected; default .shared)
```

- **`FeedbackDraft`** — `rating: Int?`, `comment`, `email`, `screenshots`.
  `isSendable = rating != nil || !comment.trimmed.isEmpty`. `emailIsValid =
  email.isEmpty || matches(simple RFC-ish regex)`. `canSend = isSendable &&
  emailIsValid && !screenshots over 3`.
- **`FeedbackSubmitting`** protocol: `uploadScreenshot(_:) async throws ->
  ScreenshotRef`, `submit(_:) async throws -> String`. Lets the VM state
  machine be tested with `MockFeedbackService` (repo `Mocks/` style).
- **`FeedbackService`** composes pure request builders + parsers with
  `URLSession`. Builders/parsers are pure and tested directly.
- **`FeedbackViewModel`** state: `enum Phase { idle, sending, success, failed(String) }`.
  `send()`: guard `canSend`; `phase = .sending`; upload each pending screenshot
  → collect refs; build metadata; `submit`; on success `phase = .success`,
  reset draft; on throw `phase = .failed(message)`.
- **Diagnostics** `metadata`: `{ appVersion, build, os (ProcessInfo
  operatingSystemVersionString), locale (Locale.current.identifier) }`;
  `environment` = `"debug"` in `DEBUG` else `"production"`.
- **Screenshot picking** stays in the view: `NSOpenPanel`
  (`allowedContentTypes = [.png, .jpeg, .image]`, multiple, cap to remaining of
  3). The view reads `Data` + filename + mimeType into `PendingScreenshot`
  (with a thumbnail `NSImage`) and hands it to the VM. Oversized (>10MB) or
  non-image files are rejected client-side with an inline message.

## Components & File Layout

**Add**
- `OpenCaffeine/Services/FeedbackModels.swift` — `ScreenshotRef`,
  `PendingScreenshot`, request/response Codables, `FeedbackError` (user-facing
  `errorDescription`).
- `OpenCaffeine/Services/FeedbackService.swift` — `FeedbackSubmitting` protocol,
  `FeedbackService`, pure `FeedbackRequest` builders + `FeedbackResponse`
  parsers, `clientId` constant, multipart encoder.
- `OpenCaffeine/Settings/FeedbackViewModel.swift` — `@MainActor` VM + `Phase`.
- `OpenCaffeine/Settings/RatingFace.swift` — `RatingFace` view (Path geometry
  above) + a `FaceRatingRow`.
- `OpenCaffeine/Settings/FeedbackSettingsView.swift` — the tab view shell.
- `OpenCaffeineTests/FeedbackDraftTests.swift`,
  `FeedbackRequestTests.swift`, `FeedbackResponseTests.swift`,
  `FeedbackViewModelTests.swift`.
- `OpenCaffeineTests/Mocks/MockFeedbackService.swift`.

**Edit**
- `OpenCaffeine/Settings/PreferencesScene.swift` — add `.feedback` to
  `PrefPage` (+ title), a `NavRow`, and `case .feedback: FeedbackSettingsView()`.

XcodeGen (`sources: path: OpenCaffeine`) auto-includes new files; no
`project.yml` edit needed. No new entitlements (app is not sandboxed; hardened
runtime off).

## Data Flow & Key Scenarios

**A — Rate + comment, send.** Tap face (rating=3) → type comment → Send becomes
enabled → tap Send → `phase=.sending` → no screenshots → `POST /feedback` →
200 → `phase=.success`, show "Thanks for the feedback!", reset form.

**B — Comment only (no rating).** `isSendable` true via non-empty comment →
sends with `comment` and no `rating`.

**C — With screenshots.** Attach 1–3 images (picker) → thumbnails shown → Send
→ for each: `POST /screenshots` (multipart) → collect refs → `POST /feedback`
with `screenshots` → success.

**D — Invalid email.** Non-empty malformed email → `emailIsValid=false` → Send
disabled + inline hint on the email row.

**E — Network/server failure.** Any upload or submit throws → `phase=.failed(msg)`
→ inline error under Send + button returns to enabled for retry. Draft kept.

### State machine — `FeedbackViewModel.Phase`
`idle → (send, canSend) → sending → success` (auto back to `idle` on next edit)
`sending → failed(msg) → (send) → sending` (retry). Edits while `sending` are
ignored/disabled.

## Error Handling & Edge Cases

- HTTP status mapping → `FeedbackError`: `.validation(issues)` (400),
  `.domainBlocked` (403), `.server` (500), `.unexpected(status)`, `.network`
  (URLSession error), `.decoding`. Each has a friendly `errorDescription`.
- Screenshot client-side guards: ≤3 total, ≤10MB each, `image/*` only.
- Empty submit (no rating, empty comment) is impossible — Send disabled.
- Trim comment/email before validation and submit; omit empty optional fields.
- `metadata` is tiny and well under the 10KB cap.

## Testing Strategy

### Unit tests (XCTest)
- **FeedbackDraftTests** — `isSendable` truth table (rating only / comment only
  / both / neither), email validation (empty ok, valid, invalid), 3-screenshot
  cap.
- **FeedbackRequestTests** — feedback `URLRequest`: URL, method, JSON content
  type, body contains `clientId` and only the provided fields (rating/comment/
  email/environment/metadata/screenshots); screenshot request: multipart
  boundary, `clientId` + `screenshot` parts, filename/mime in headers.
- **FeedbackResponseTests** — parse 200 success (feedbackId / screenshot ref);
  each error status → correct `FeedbackError`; malformed JSON → `.decoding`.
- **FeedbackViewModelTests** — with `MockFeedbackService`: happy path
  `idle→sending→success` + draft reset; screenshots uploaded before submit and
  refs forwarded; submit failure → `.failed`; upload failure short-circuits
  (no submit); `canSend` gating.

### Manual verification checklist
- Tab appears, matches other tabs; faces match mockup (all four), select/clear
  works; Send disabled until rating-or-comment; email hint on bad email;
  attach/remove up to 3 screenshots; real submit returns 200 (verify in Usero
  dashboard); success + reset; airplane-mode → friendly error + retry;
  light/dark mode; "Powered by Usero" opens the site.

## Open Questions / Deferred
- Interactive screen capture — deferred (upload-only chosen).
- Session replay linkage — out of scope.
- Draft persistence — out of scope.

## Implementation Phases (rough)
1. Models + service (pure builders/parsers) + their tests.
2. `RatingFace` geometry + view.
3. `FeedbackViewModel` (+ mock) + tests.
4. `FeedbackSettingsView` + `NSOpenPanel` wiring.
5. `PreferencesScene` tab wiring.
6. Build, lint, run tests, manual verification against the mockup.
