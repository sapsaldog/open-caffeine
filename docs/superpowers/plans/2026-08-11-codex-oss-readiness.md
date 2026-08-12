# Codex for Open Source Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strengthen Open Caffeine's public open-source evidence, add a verifiable CI quality gate, improve maintainer discoverability, and produce a truthful Codex for Open Source application packet.

**Architecture:** Repository changes stay limited to README copy and one GitHub Actions workflow, with the existing coverage script remaining the quality-policy source of truth. GitHub repository metadata and the maintainer bio are updated through narrow API patches, profile pins are changed through the authenticated GitHub UI, and the application packet is generated as a separate user-facing artifact outside the repository.

**Tech Stack:** Markdown, GitHub Actions YAML, macOS 26 GitHub-hosted runner, Xcode 26, XcodeGen, SwiftLint, XCTest/xccov, GitHub CLI, authenticated GitHub web UI.

## Global Constraints

- Preserve the deployment floor of Apple Silicon and macOS 26 (Tahoe) or newer.
- Do not add macOS 15 compatibility, application behavior, signing, notarization, dependencies, or caching.
- Do not claim that a project is widely used, that downloads equal unique users, or that external contributors exist where they do not.
- Keep `Scripts/coverage-gate.sh` and `Scripts/coverage_check.py` as the single source of truth for the 100% tested-logic line-coverage policy.
- Preserve existing company, location, name, and other GitHub profile fields; patch only the bio.
- Use only refreshed, traceable GitHub metrics and the existing Product Hunt badge in the application packet.
- Do not submit the OpenAI application; final submission requires a separate explicit user approval.
- Work on `agent/codex-oss-readiness`; publish a draft pull request and do not merge it.

## File Structure

- Modify `README.md`: public positioning, feature summary, binary installation path, and accurate unsigned-build explanation.
- Create `.github/workflows/ci.yml`: the only hosted quality-gate workflow.
- Existing `Scripts/coverage-gate.sh`: invoked unchanged by CI.
- Existing `Scripts/coverage_check.py`: invoked unchanged by the coverage gate.
- Create `/Users/sapsaldog/Documents/Codex/2026-08-11/codex-for-open-source/outputs/codex-for-open-source-application.md`: copy-ready application evidence and answers; never commit this file to the repository.

---

### Task 1: Reframe the README for users and contributors

**Files:**
- Modify: `README.md:1-35`
- Test: `README.md` structural and copy assertions with `rg`

**Interfaces:**
- Consumes: current release URL, Product Hunt badge, Sparkle release flow, macOS 26 platform floor.
- Produces: stable headings `## Features`, `## Install`, and `## Build from source` for users and the application evidence review.

- [ ] **Step 1: Run the copy assertions before editing**

Run:

```bash
rg -n '^A personal macOS|^## Features$|^## Install$|^## Build from source$|not code-signed or notarized' README.md
```

Expected: the command finds `A personal macOS` only; the three headings and the accurate signing sentence are absent.

- [ ] **Step 2: Replace the opening product copy**

Replace:

```markdown
A personal macOS menubar utility that keeps the Mac awake for a chosen duration.
Apple Silicon, macOS 26 (Tahoe)+ — native Liquid Glass UI. No code signing — local builds only.
```

with:

```markdown
An open-source macOS menu-bar utility that keeps your Mac awake for a chosen duration.
Built for Apple Silicon and macOS 26 (Tahoe) or newer with a native Liquid Glass UI.
```

- [ ] **Step 3: Add the feature and installation sections after the Product Hunt recognition**

Insert this exact Markdown immediately after the Product Hunt ranking paragraph:

```markdown
## Features

- Timed sessions from 5 minutes to 8 hours, plus a keep-awake-forever mode
- Separate control over display sleep and system sleep
- Live menu-bar countdown and a customizable global shortcut
- Optional battery threshold that stops an active session
- Launch-at-login, Dock visibility, appearance, and menu-bar icon preferences
- EdDSA-verified automatic updates through Sparkle

## Install

Download the latest archive from [GitHub Releases](https://github.com/sapsaldog/open-caffeine/releases/latest), extract it, and move **Open Caffeine.app** to `/Applications`.

Open Caffeine releases are EdDSA-signed for Sparkle update integrity, but the app is not Apple code-signed or notarized. On first launch, macOS may require **System Settings → Privacy & Security → Open Anyway**.
```

- [ ] **Step 4: Rename the source-build heading**

Change:

```markdown
## Build
```

to:

```markdown
## Build from source
```

- [ ] **Step 5: Run README verification**

Run:

```bash
rg -n '^An open-source macOS|^## Features$|^## Install$|^## Build from source$|not Apple code-signed or notarized' README.md
! rg -n '^A personal macOS|local builds only' README.md
git diff --check -- README.md
```

Expected: all five positive patterns are found, neither negative pattern is found, and `git diff --check` exits 0.

- [ ] **Step 6: Commit the README change**

Run:

```bash
git add README.md
git commit -m "docs: clarify Open Caffeine installation"
```

Expected: one commit containing only `README.md`.

---

### Task 2: Add the hosted macOS 26 quality gate

**Files:**
- Create: `.github/workflows/ci.yml`
- Reuse unchanged: `Scripts/coverage-gate.sh`
- Reuse unchanged: `Scripts/coverage_check.py`
- Test: `.github/workflows/ci.yml` with Actionlint and the full local coverage gate

**Interfaces:**
- Consumes: executable `Scripts/coverage-gate.sh`, Homebrew packages `xcodegen` and `swiftlint`, scheme `OpenCaffeine` from `project.yml`.
- Produces: GitHub Actions check named `Quality gate` on pull requests, pushes to `main`, and manual runs.

- [ ] **Step 1: Verify the workflow does not exist**

Run:

```bash
test ! -e .github/workflows/ci.yml
```

Expected: exit 0, proving this task creates rather than replaces the workflow.

- [ ] **Step 2: Create the workflow**

Create `.github/workflows/ci.yml` with exactly:

```yaml
name: CI

on:
  pull_request:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ci-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

jobs:
  quality-gate:
    name: Quality gate
    runs-on: macos-26
    timeout-minutes: 30
    steps:
      - name: Check out repository
        uses: actions/checkout@v6

      - name: Install build tools
        run: brew install xcodegen swiftlint

      - name: Run tests and coverage gate
        run: Scripts/coverage-gate.sh
```

- [ ] **Step 3: Lint the workflow**

Run:

```bash
actionlint .github/workflows/ci.yml
```

Expected: no output and exit 0.

- [ ] **Step 4: Run the local quality gate**

Run on the current macOS 26.5.2 / Xcode 26.6 host:

```bash
Scripts/coverage-gate.sh
```

Expected: the XCTest suite passes and the final output contains `All logic files at 100% line coverage.`

- [ ] **Step 5: Inspect the workflow diff**

Run:

```bash
git diff --check -- .github/workflows/ci.yml
git diff -- .github/workflows/ci.yml
```

Expected: a single new workflow matching Step 2, with no changes to either coverage script.

- [ ] **Step 6: Commit the workflow**

Run:

```bash
git add .github/workflows/ci.yml
git commit -m "ci: run macOS quality gate"
```

Expected: one commit containing only `.github/workflows/ci.yml`.

---

### Task 3: Update GitHub repository and maintainer metadata

**Files:**
- Modify externally: GitHub repository About description and topics for `sapsaldog/open-caffeine`
- Modify externally: GitHub profile bio for `sapsaldog`
- Modify externally: GitHub profile pinned repositories
- Test: GitHub REST/GraphQL readback and authenticated visual verification

**Interfaces:**
- Consumes: authenticated `gh` session and an authenticated GitHub browser session for profile pins.
- Produces: discoverable repository metadata, the approved maintainer bio, and three ordered profile pins.

- [ ] **Step 1: Capture the current metadata without changing it**

Run:

```bash
gh api repos/sapsaldog/open-caffeine --jq '{description,homepage,topics}'
gh api user --jq '{login,name,bio,company,location,blog}'
```

Expected: repository description is null, topics are empty, and the profile bio is null; company and location remain populated and must not be altered.

- [ ] **Step 2: Patch only the repository description**

Run:

```bash
gh api --method PATCH repos/sapsaldog/open-caffeine \
  -f description='Open-source macOS menu-bar utility with timers, hotkeys, battery protection, and automatic updates.' \
  --jq '{description,html_url}'
```

Expected: the returned description exactly matches the provided sentence.

- [ ] **Step 3: Replace the empty topic set with the approved topics**

Run:

```bash
gh api --method PUT repos/sapsaldog/open-caffeine/topics --input - <<'JSON'
{"names":["macos","swift","swiftui","menu-bar","productivity","open-source","sparkle"]}
JSON
```

Expected: the response contains all seven topics and no additional topics.

- [ ] **Step 4: Patch only the profile bio**

Run:

```bash
gh api --method PATCH user \
  -f bio='Building practical open-source tools for macOS, developer workflows, and Korean SaaS integrations.' \
  --jq '{login,name,bio,company,location,blog}'
```

Expected: the bio matches exactly; name, company, location, and blog retain their Step 1 values.

- [ ] **Step 5: Pin and order the three repositories through GitHub's authenticated UI**

Use the `chrome:control-chrome` skill and the existing Chrome session:

1. Open `https://github.com/sapsaldog`.
2. Select **Customize your pins**.
3. Select `open-caffeine`, `oh-my-worktree`, and `supabase-naver-oidc-proxy`; deselect any other repository pins.
4. Save the selection.
5. Reorder the cards to `open-caffeine`, `oh-my-worktree`, `supabase-naver-oidc-proxy`.
6. Refresh the profile and visually verify the saved order.

If GitHub requires a login or reauthentication, stop only this pinning step and report the exact browser prompt; continue all non-browser tasks.

- [ ] **Step 6: Read back API-visible metadata**

Run:

```bash
gh api repos/sapsaldog/open-caffeine --jq '{description,topics}'
gh api user --jq '{login,name,bio,company,location,blog}'
gh api graphql -f query='query($login:String!){user(login:$login){pinnedItems(first:6,types:[REPOSITORY]){nodes{... on Repository{nameWithOwner}}}}}' -F login=sapsaldog --jq '.data.user.pinnedItems.nodes'
```

Expected: the description and seven topics match Steps 2-3, the bio matches Step 4 without collateral profile changes, and the first three pinned repositories match Step 5.

---

### Task 4: Publish a draft pull request and verify hosted CI

**Files:**
- Publish: committed changes on `agent/codex-oss-readiness`
- Create externally: draft pull request targeting `sapsaldog/open-caffeine:main`
- Test: GitHub Actions `Quality gate`

**Interfaces:**
- Consumes: the committed design, implementation plan, README change, CI workflow, authenticated `gh` session.
- Produces: a reviewable draft PR and an authoritative hosted macOS 26 quality-gate result.

- [ ] **Step 1: Invoke the GitHub publish workflow and confirm scope**

Read and follow `github:yeet`. Run:

```bash
gh --version
gh auth status
git status -sb
git log --oneline origin/main..HEAD
git diff --stat origin/main...HEAD
```

Expected: authentication succeeds, the branch is `agent/codex-oss-readiness`, and the diff contains only the design, plan, README, and CI workflow.

- [ ] **Step 2: Push the branch**

Run:

```bash
git push -u origin agent/codex-oss-readiness
```

Expected: the remote tracking branch is created successfully.

- [ ] **Step 3: Open the draft pull request**

Prefer the connected GitHub app. Use these exact values:

- Repository: `sapsaldog/open-caffeine`
- Base: `main`
- Head: `agent/codex-oss-readiness`
- Draft: `true`
- Title: `docs: strengthen Open Caffeine OSS readiness`
- Body:

```markdown
## What changed

- present Open Caffeine as an open-source utility with a clear feature summary
- document the GitHub Releases installation path and unsigned/notarized status
- add a macOS 26 GitHub Actions quality gate for tests and 100% tested-logic coverage
- record the approved OSS-readiness design and implementation plan

## Why

The repository already has releases, contribution guidance, security reporting, and a strict local coverage gate, but the README still frames it as a personal utility and the quality gate is not independently visible to contributors. This change makes the public project status and maintenance standards explicit without changing application behavior or support policy.

## Validation

- `actionlint .github/workflows/ci.yml`
- `Scripts/coverage-gate.sh`
```

If the connector cannot create the PR, use `gh pr create --draft` with the same title, body, base, and head.

- [ ] **Step 4: Wait for and inspect hosted checks**

Run:

```bash
gh pr checks --watch
```

Expected: `Quality gate` completes successfully.

If it fails, invoke `github:gh-fix-ci`, inspect the failing Actions logs, make the smallest correction on the same branch, rerun local validation, commit, push, and watch the replacement run. Do not weaken coverage or remove SwiftLint.

- [ ] **Step 5: Record the PR URL and final check state**

Run:

```bash
gh pr view --json url,isDraft,headRefName,baseRefName,statusCheckRollup --jq '{url,isDraft,headRefName,baseRefName,checks:[.statusCheckRollup[]|{name,status,conclusion}]}'
```

Expected: draft is true, head/base are correct, and `Quality gate` has conclusion `SUCCESS`.

---

### Task 5: Refresh evidence and create the application packet

**Files:**
- Create: `/Users/sapsaldog/Documents/Codex/2026-08-11/codex-for-open-source/outputs/codex-for-open-source-application.md`
- Test: source metrics, links, unsupported-claim scan, and file location

**Interfaces:**
- Consumes: GitHub repository metadata, release assets, collaborator permissions, closed issue #4, passing CI, and official OpenAI Docs program criteria.
- Produces: a copy-ready English application packet with concise and expanded answers.

- [ ] **Step 1: Refresh public metrics and maintainer permissions**

Run:

```bash
for repo_name in open-caffeine oh-my-worktree supabase-naver-oidc-proxy; do
  gh api "repos/sapsaldog/$repo_name" --jq '{repo:.full_name,stars:.stargazers_count,forks:.forks_count,open_issues:.open_issues_count,license:(.license.spdx_id // "none"),pushed_at}'
  gh api "repos/sapsaldog/$repo_name/releases?per_page=100" --paginate --jq '[.[] | [.assets[].download_count] | add // 0] | {releases:length,asset_downloads:(add // 0)}'
  gh api "repos/sapsaldog/$repo_name/collaborators/sapsaldog/permission" --jq '{repo:"sapsaldog/'"$repo_name"'",permission,user:.user.login}'
done
```

Expected: all repositories are readable, `sapsaldog` has admin/write-level permission, and the current metric values are available for the packet. If a release or star count differs from the draft values below, use the refreshed value everywhere in the output.

- [ ] **Step 2: Verify maintenance evidence**

Run:

```bash
gh issue view 4 --repo sapsaldog/open-caffeine --json state,stateReason,url --jq '{state,stateReason,url}'
gh pr view --json url,isDraft,statusCheckRollup --jq '{url,isDraft,checks:[.statusCheckRollup[]|{name,conclusion}]}'
```

Expected: issue #4 is closed as not planned, the PR is a draft, and `Quality gate` is successful.

- [ ] **Step 3: Create the application packet**

Create `/Users/sapsaldog/Documents/Codex/2026-08-11/codex-for-open-source/outputs/codex-for-open-source-application.md` with this content, replacing only refreshed numeric metrics when Step 1 differs:

```markdown
# Codex for Open Source Application Packet

Verified: August 11, 2026

Official program: https://developers.openai.com/community/codex-for-oss

## Applicant

- Name: Donghun Choi
- GitHub: https://github.com/sapsaldog
- Role: Creator and core maintainer with admin/write access

## Primary project

- Repository: https://github.com/sapsaldog/open-caffeine
- License: MIT
- Project: Open Caffeine, an open-source macOS 26 menu-bar utility that keeps a Mac awake for a chosen duration

## Copy-ready concise answer

I am the creator and core maintainer of Open Caffeine, an MIT-licensed macOS 26 menu-bar utility for timed and indefinite keep-awake sessions. I own the repository and maintain its issue triage, architecture, tests, releases, signed Sparkle update feed, contributor guidance, and security process. As of August 11, 2026, the project has 45 GitHub stars, three releases, and 166 release-asset downloads, and it ranked #10 Product of the Day on Product Hunt.

I also maintain Oh My Worktree, a native macOS worktree and pull-request manager with 15 stars, two forks, 21 releases, and 82 release-asset downloads, and Supabase Naver OIDC Proxy, a focused interoperability project with 19 stars and eight forks that enables Supabase Custom Provider login through Naver's non-standard user-info response.

Six months of ChatGPT Pro with Codex would help me sustain these projects as a solo maintainer. I would use Codex for issue triage, compatibility analysis, regression-test generation, pull-request review, documentation maintenance, and release automation. My immediate request is maintainer access to ChatGPT Pro with Codex; I am not claiming an existing OpenAI API integration or a larger user base than the public evidence supports.

## Expanded project and ecosystem impact answer

Open Caffeine provides a transparent, inspectable alternative for macOS users who need controlled keep-awake sessions. It supports timed and indefinite sessions, separate display/system-sleep behavior, global shortcuts, battery-threshold protection, login launch, and EdDSA-verified Sparkle updates. The repository includes an MIT license, contribution and conduct guides, private vulnerability reporting instructions, release documentation, extensive XCTest coverage, and a quality gate that requires 100% line coverage for every non-exempt logic file.

The project is still emerging, so I would not describe it as widely used. Its public adoption signals are concrete: 45 stars, three releases, 166 release-asset downloads, Product Hunt #10 Product of the Day, and continuing repository traffic. My supporting projects show a broader maintenance pattern: developer workflow tooling through Oh My Worktree and a Korea-specific authentication interoperability solution through Supabase Naver OIDC Proxy. The latter's eight forks are especially useful evidence that other developers are adapting the solution.

## Expanded Codex use answer

I would use Codex in day-to-day maintainer workflows rather than for speculative feature volume. The main uses would be:

- reproduce and classify incoming bug reports;
- analyze macOS and dependency compatibility changes;
- add regression tests while preserving the existing 100% tested-logic coverage policy;
- review pull requests for behavior, security, and maintenance risk;
- keep contributor, security, and release documentation aligned with the code;
- automate repetitive release and changelog checks across multiple public repositories.

This support would reduce the maintenance burden on a solo maintainer and make it easier to respond promptly to users while keeping changes reviewable and well tested.

## Supporting evidence

| Evidence | Link |
|---|---|
| Open Caffeine repository | https://github.com/sapsaldog/open-caffeine |
| Releases | https://github.com/sapsaldog/open-caffeine/releases |
| CI quality gate | https://github.com/sapsaldog/open-caffeine/actions |
| Contribution guide | https://github.com/sapsaldog/open-caffeine/blob/main/CONTRIBUTING.md |
| Security policy | https://github.com/sapsaldog/open-caffeine/blob/main/SECURITY.md |
| Oh My Worktree | https://github.com/sapsaldog/oh-my-worktree |
| Supabase Naver OIDC Proxy | https://github.com/sapsaldog/supabase-naver-oidc-proxy |

## Submission note

The official OpenAI Docs page publishes the eligibility criteria and benefits but does not expose the application form's field schema. Use the concise or expanded answers above according to the available text limits. Do not submit until the account email, legal acknowledgements, and any form-specific selections have been reviewed by the applicant.
```

- [ ] **Step 4: Validate the packet**

Run:

```bash
test -f /Users/sapsaldog/Documents/Codex/2026-08-11/codex-for-open-source/outputs/codex-for-open-source-application.md
rg -n '^## Applicant$|^## Primary project$|^## Copy-ready concise answer$|^## Expanded project and ecosystem impact answer$|^## Expanded Codex use answer$|^## Supporting evidence$|^## Submission note$' /Users/sapsaldog/Documents/Codex/2026-08-11/codex-for-open-source/outputs/codex-for-open-source-application.md
! rg -ni 'is widely used|thousands of users|I have an existing OpenAI API integration' /Users/sapsaldog/Documents/Codex/2026-08-11/codex-for-open-source/outputs/codex-for-open-source-application.md
```

Expected: the file exists under `outputs`, every required section is present, and no unsupported positive claim is found. Explicit disclaimers such as `would not describe it as widely used` and `not claiming an existing OpenAI API integration` remain in the packet.

---

### Task 6: Final cross-surface verification and handoff

**Files:**
- Verify: repository branch and draft PR
- Verify: GitHub repository/profile metadata and pins
- Verify: `/Users/sapsaldog/Documents/Codex/2026-08-11/codex-for-open-source/outputs/codex-for-open-source-application.md`

**Interfaces:**
- Consumes: all outputs from Tasks 1-5.
- Produces: a final evidence-backed handoff with the draft PR URL, check result, profile state, and application packet link.

- [ ] **Step 1: Verify the local branch is clean**

Run:

```bash
git status -sb
git log --oneline origin/main..HEAD
```

Expected: no uncommitted repository changes and the intended design, plan, README, and CI commits are present.

- [ ] **Step 2: Verify public repository state**

Run:

```bash
gh pr view --json url,isDraft,headRefName,baseRefName,statusCheckRollup --jq '{url,isDraft,headRefName,baseRefName,checks:[.statusCheckRollup[]|{name,status,conclusion}]}'
gh api repos/sapsaldog/open-caffeine --jq '{description,topics}'
gh api user --jq '{login,bio,company,location}'
gh api graphql -f query='query($login:String!){user(login:$login){pinnedItems(first:3,types:[REPOSITORY]){nodes{... on Repository{nameWithOwner}}}}}' -F login=sapsaldog --jq '.data.user.pinnedItems.nodes'
```

Expected: the PR is a draft with successful `Quality gate`, metadata and bio match Task 3, and the three pins are in the approved order.

- [ ] **Step 3: Verify the application artifact one last time**

Run:

```bash
wc -w /Users/sapsaldog/Documents/Codex/2026-08-11/codex-for-open-source/outputs/codex-for-open-source-application.md
rg -n 'https://github.com/sapsaldog/open-caffeine|https://github.com/sapsaldog/oh-my-worktree|https://github.com/sapsaldog/supabase-naver-oidc-proxy|https://developers.openai.com/community/codex-for-oss' /Users/sapsaldog/Documents/Codex/2026-08-11/codex-for-open-source/outputs/codex-for-open-source-application.md
```

Expected: the artifact is non-empty and contains all four source links.

- [ ] **Step 4: Handoff without submitting or merging**

Report:

- the draft PR URL and successful hosted CI result;
- repository description/topics and profile bio changes;
- whether profile pinning succeeded or needs browser reauthentication;
- the clickable application-packet file under `outputs`;
- that neither the draft PR nor the OpenAI application has been merged/submitted.
