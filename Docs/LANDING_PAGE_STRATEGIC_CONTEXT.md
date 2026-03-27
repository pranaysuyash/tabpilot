# TabPilot Landing Page Redesign — Strategic Context Document

**Generated:** 2026-03-26  
**Purpose:** Comprehensive audit and strategic input for landing page redesign  
**Scope:** App codebase, documentation, existing landing page, product positioning  

---

## 1. Product Understanding Summary

### What the Product Is

TabPilot is a native macOS utility app that manages Chrome tab overload. It scans all Chrome windows, detects duplicate tabs using URL normalization, and allows users to close them safely with review, undo, and protected domains.

The app communicates with Chrome via AppleScript (not a Chrome extension). It is a native SwiftUI macOS app (macOS 14+), distributed outside the Mac App Store via direct download (S3/CloudFront).

### What It Does Today (Code-Verified)

| Capability | Status | Evidence |
|------------|--------|----------|
| Scan all Chrome tabs across all windows | Implemented | `ScanController.swift:61`, `ChromeController.swift:115-189` |
| Detect duplicates via URL normalization | Implemented | `ScanController.swift:291-306`, strips `utm_`, `fbclid`, etc. |
| Close selected or all duplicates | Implemented | `AppViewModel.swift:299-552` |
| Review plan before close (SuperUser mode) | Implemented | `AppViewModel.swift:361-419`, `ReviewPlanView.swift` |
| 30-second undo after close | Implemented | `UndoController.swift:8, 36-98` |
| Save/restore sessions | Implemented | `Models/Session.swift`, `Views/SessionView.swift` |
| Auto-cleanup with rules | Implemented | `AutoCleanupManager.swift:6-149` |
| Protected domains (Gmail, Calendar) | Implemented | `ScanController.swift:391-395` |
| Statistics & tab debt scoring | Implemented | `StatisticsStore.swift`, `TabDebtView.swift` |
| Menu bar status item | Implemented | `MenuBarController.swift:6-87` |
| Global hotkeys (Cmd+Shift+C, D) | Implemented | `HotkeyManager.swift:44-62` |
| Export (Markdown, CSV, JSON, HTML) | Implemented | `ExportManager.swift`, `AppViewModel.swift:606-691` |
| Cleanup impact (memory/CPU freed) | Implemented | `SystemMetrics.swift`, `CleanupImpactView.swift` |
| Chrome extension for time tracking | Implemented (optional) | `extension/background.js`, `TabTimeHost.swift` |
| Persona-based UI (Light/Standard/Power/Super) | Implemented | `PersonaDetection.swift:158-183` |

### What the Product Is Trying to Become

From docs and roadmap:
- Full browser health platform (beyond just duplicates)
- Cross-browser support (Safari, Arc, Edge) — planned, not built
- AI-powered tab organization suggestions — deferred
- Team/business features — deferred
- Cloud sync — deferred

### Core Problem It Solves

Three problems, consistently documented:
1. **Browser slowdown** — too many tabs = memory bloat, sluggish Mac, fan noise
2. **Lost work** — important tabs buried and forgotten in chaos
3. **Manual cleanup risk** — closing tabs manually risks losing important research

### Who It Is For

| Persona | Evidence |
|---------|----------|
| Power users with 100+ tabs | "These users feel the pain daily" (MARKETING_AND_PRICING.md:73) |
| Researchers, developers, journalists | Explicitly listed (MARKETING_AND_PRICING.md:74) |
| Chrome users with slow Macs | "Tab clutter = memory = performance issues" (MARKETING_AND_PRICING.md:75) |
| "Anyone who's wondered 'why is Chrome so slow?'" | App Store description draft |

**Demographics:** Mac-only, Chrome-primary, power users, willing to pay $19.99 one-time for a tool.

---

## 2. Evidence Map

| Claim | Evidence File | Lines | What It Supports |
|-------|---------------|-------|------------------|
| "TabPilot" is the product name | `ChromeTabManager.swift` | 11 | Window title is "TabPilot" |
| URL normalization strips tracking | `ChromeController.swift` | 644-707 | `normalizeURL()` filters `utm_*`, `fbclid`, etc. |
| 30-second undo | `UndoController.swift` | 8 | `static let undoTimeout: TimeInterval = 30` |
| No free tier | `PAYMENT_ARCHITECTURE_DECISION_2026-03-26.md` | 156-162 | Decision: no free tier, $19.99 to download |
| Protected domains default | `DefaultsKeys.swift` | 14 | `["mail.google.com", "calendar.google.com"]` |
| Auto-cleanup runs on timer | `AutoCleanupManager.swift` | 63-67 | 15-minute default interval |
| Chrome via AppleScript | `ChromeController.swift` | 115-130 | AppleScript `tell application "Google Chrome"` |
| Global hotkeys | `HotkeyManager.swift` | 52-59 | Cmd+Shift+C (scan), Cmd+Shift+D (close) |
| Persona detection | `PersonaDetection.swift` | 158-183 | Auto-detects Light/Standard/Power/Super |
| Export formats | `ExportManager.swift` | 7-18 | Markdown, CSV, JSON, HTML |
| macOS 14+ required | `Package.swift` | 6 | `.macOS(.v14)` |
| No in-app payment | `PAYMENT_ARCHITECTURE_DECISION_2026-03-26.md` | 93-96 | Purchase on landing page only |
| One-time $19.99 | `MARKETING_AND_PRICING.md` | 5 | "$19.99 lifetime purchase" |

---

## 3. Persona + Jobs-to-be-Done Summary

### Primary Persona: Power User with Tab Overload

| Aspect | Detail |
|--------|--------|
| **Goals** | Reclaim browser performance, find/close duplicates quickly, never accidentally lose important tabs, understand tab consumption patterns |
| **Pains** | Chrome is slow, fans spinning, can't find tabs, manual cleanup is risky, memory is bloated |
| **Expectations** | Fast scan, clear duplicate groups, safe close with undo, memory freed after cleanup |
| **Desired Outcome** | Chrome feels fast again, important tabs preserved, one-click cleanup |

### Secondary Persona: Professional (Developer/Researcher)

| Aspect | Detail |
|--------|--------|
| **Goals** | Save session before cleanup, restore later, automate cleanup rules, export tab lists for documentation |
| **Pains** | Losing research tabs, repetitive manual cleanup, no visibility into tab patterns |
| **Expectations** | Sessions, auto-cleanup rules, statistics, export |
| **Desired Outcome** | Workflow preserved, automation for recurring cleanup tasks |

### Tertiary Persona: Casual User

| Aspect | Detail |
|--------|--------|
| **Goals** | Just scan and clean, minimal friction |
| **Pains** | Too many options, complicated UI |
| **Expectations** | Simple one-click clean, not overwhelmed |
| **Desired Outcome** | Cleaner browser without learning curve |

---

## 4. Capability Matrix

| Capability | Description | Status | Evidence | Landing Page Relevance |
|------------|-------------|--------|-----------|------------------------|
| Chrome scan | Scan all tabs across all windows via AppleScript | Implemented | `ScanController.swift:61` | Hero: "Scan Your Tabs" |
| Duplicate detection | URL normalization, strips tracking params | Implemented | `ChromeController.swift:644-707` | Feature: "Smart Detection" |
| Close operations | Selective close, bulk close, review plan | Implemented | `AppViewModel.swift:299-552` | Feature: "Close Safely" |
| Undo | 30-second undo window | Implemented | `UndoController.swift:8` | Feature: "Undo Protection" |
| Sessions | Save/restore tab sessions | Implemented | `Session.swift`, `SessionView.swift` | Feature: "Sessions" |
| Auto-cleanup | Timer-based cleanup with rules | Implemented | `AutoCleanupManager.swift:6-149` | Feature: "Auto-Cleanup" |
| Protected domains | Never close Gmail/Calendar | Implemented | `ScanController.swift:391-395` | Feature: "Protected Domains" |
| Statistics | Tab count, debt score, domain analytics | Implemented | `StatisticsStore.swift` | Feature: "Statistics" |
| Menu bar | Status item showing duplicate count | Implemented | `MenuBarController.swift:6-87` | Feature: "Menu Bar" |
| Global hotkeys | Cmd+Shift+C, Cmd+Shift+D | Implemented | `HotkeyManager.swift:44-62` | Feature: "Shortcuts" |
| Export | Markdown, CSV, JSON, HTML | Implemented | `ExportManager.swift` | Feature: "Export" |
| Cleanup impact | Before/after memory/CPU | Implemented | `SystemMetrics.swift` | Proof point: "See What You Saved" |
| Chrome extension | Time tracking per domain (optional) | Implemented | `extension/background.js` | Differentiator: "Real-Time Tracking" |
| Persona modes | Light/Standard/Power/Super UI | Implemented | `PersonaDetection.swift:158-183` | UX: adaptive interface |
| Accessibility | VoiceOver, Dynamic Type | Partial | `AccessibilityUtils.swift` | Note: requires Accessibility permission |

---

## 5. Differentiation Analysis

### Real Differentiators

| Differentiator | Why It's Real | Evidence |
|----------------|---------------|-----------|
| Native macOS app, not Chrome extension | Works offline, no extension needed, deeper system access | Code: AppleScript bridge |
| One-time $19.99 purchase | No subscription, "buy once use forever" | Docs: `MARKETING_AND_PRICING.md` |
| Review plan before close | Users see exactly what will close | Code: `ReviewPlanView.swift` |
| 30-second undo | Safety net for every close | Code: `UndoController.swift:8` |
| Protected domains | Gmail, Calendar never at risk | Code: `DefaultsKeys.swift:14` |
| Cleanup impact metrics | Shows memory/CPU freed | Code: `CleanupImpactView.swift` |
| Tab debt scoring | Quantifies browser health | Code: `TabDebtView.swift` |
| Chrome extension time tracking | Real dwell time per domain | Code: `extension/background.js` |

### Weak Differentiators (Avoid Over-Claiming)

| Claim | Issue |
|-------|-------|
| "AI-powered detection" | No AI in codebase — just URL normalization. Do not use. |
| "Exact and near-duplicate tabs" | Just URL normalization — no fuzzy matching. Be precise. |
| "Cross-browser support" | Not built. Arc/Edge/Safari not supported yet. Do not claim. |
| "Cloud sync" | Not built. Do not claim. |
| "Enterprise features" | Not built. Do not claim. |

### Commodity Claims to Avoid

- "Built for macOS power users" — every Mac app says this
- "Intuitive interface" — meaningless
- "Productivity boost" — generic
- "Advanced features" — generic

---

## 6. Trust / Proof Inventory

| Claim | Evidence Strength | Safe to Use? |
|-------|-------------------|--------------|
| Native macOS app | Code-verified | Yes |
| Works offline | No network calls during scan | Yes |
| Tab data never leaves computer | `PRIVACY_POLICY.md:62` | Yes |
| No in-app tracking | `PRIVACY_POLICY.md:23-30` (explicit list of what is NOT collected) | Yes |
| One-time purchase | `MARKETING_AND_PRICING.md:5` | Yes |
| 30-second undo | Code-verified | Yes |
| Protected domains | Code-verified | Yes |
| Notarized by Apple | `DISTRIBUTION_ARCHITECTURE.md:48-54` | Yes (when implemented) |
| Sparkle updates | `DISTRIBUTION_ARCHITECTURE.md:43-46` | Yes (when implemented) |
| Cleanup impact (memory freed) | Code-verified | Yes, strong proof point |
| Tab debt scoring | Code-verified | Yes, unique proof point |
| "AI-powered" | Not in code | **No — remove** |
| "Near-duplicate detection" | Just URL normalization | Be precise — say "URL normalization" |
| User testimonials | None exist | No — don't invent |
| "Used by X users" | None exist | No — don't invent |
| Cross-browser support | Not built | No — remove |

---

## 7. Product Story Draft

**Why this product exists:**
TabPilot was built to solve a personal pain: Chrome had become unusable with hundreds of tabs, and manual cleanup was risky. The developer needed a way to see exactly what would close before committing, with an undo safety net.

**What problem space it enters:**
Tab overload is a growing problem for power users. Chrome slows down, memory bloats, fans spin. Users don't want to lose important tabs but can't manually manage hundreds of them.

**What kind of future it points to:**
The app starts as a duplicate tab manager but positions toward a broader "browser health platform" — with time tracking, resource recovery metrics, auto-cleanup rules, and eventually cross-browser support.

**How broad or narrow its wedge is:**
Narrow wedge initially: duplicate cleanup for Chrome users on Mac. The landing page should lead with this narrow value and expand to features as secondary.

---

## 8. Landing Page Requirements Inputs

### Must Communicate

1. **What it is:** Native macOS app for Chrome tab management
2. **What it does:** Scans Chrome, finds duplicates, closes safely with undo
3. **Why it's different:** Native app (not extension), review-before-close, undo, protected domains, cleanup impact metrics
4. **Price:** $19.99 one-time, no subscription
5. **How to get it:** Download from landing page after purchase
6. **Requirements:** macOS 14+, Chrome, Accessibility permission

### Should Communicate

- Tab debt scoring as a unique proof point
- Cleanup impact (memory/CPU freed) as proof of value
- Chrome extension (optional) for real-time time tracking
- Sessions for saving/restoring workflow
- Auto-cleanup rules for automation

### Avoid Claiming

- "AI-powered" (not in code)
- Cross-browser support (not built)
- Cloud sync (not built)
- Enterprise features (not built)
- "Exact and near-duplicate" (just URL normalization)

### Unknowns to Resolve

- Is the Chrome extension required or optional? (Code says optional, but marketing treats it as a differentiator — clarify)
- Is the "Tab Debt" feature fully shipping in v1.0? (Code exists, but QA report had concerns — verify)
- What is the exact macOS version requirement? (`Package.swift` currently targets macOS 14+; keep landing copy aligned to that repo source of truth.)
- What permissions are shown on first launch? (Accessibility is required — should be mentioned)

---

## 9. Design Direction Inputs

### Aesthetic Direction Signals

- **Feel:** Premium, tool-like, macOS-native, calm confidence
- **Visual references in words:** Not generic SaaS, not startup neon, not fake glass. Think: native macOS app presentation, clean typography, structured whitespace, Apple-inspired but not Apple-imitating
- **macOS/desktop-native cues:** Show real app UI (screenshots), not CSS mockups. Use window frame aesthetics subtly. Respect macOS design language (SF Pro, system colors, subtle shadows)
- **Minimalism:** Yes, but not at the expense of features. Show enough to convey depth
- **Technicality:** Moderate — this is a tool, not a lifestyle product. Show metrics, numbers, proof
- **Warmth:** The app has personality (fun scanning messages, undo countdown). The landing page can reflect that subtly
- **Premium:** Yes — $19.99 is a premium price point for a utility. Page should feel worth it

### What to Avoid Visually

- Generic gradient wallpaper backgrounds
- Random floating cards with no structure
- Fake glass/glassmorphism overload
- "Startup neon" or bright saturated gradients
- AI-generated look (generic illustrations, generic typography)
- CSS-only mockups (replace with real screenshots)
- SF Symbol Unicode characters that won't render on non-Apple devices

### What Makes It Feel Generic or AI-Made

- Overly generic headlines like "The Ultimate Tab Manager"
- Bullet-point feature lists without context
- No real product UI shown
- Fake testimonials or user counts
- "Join X users" or "Trusted by" with no real logos
- Wall of checkmarks in pricing section

### App-Style Cues

- Show the real app interface in screenshots
- Use a window frame aesthetic for visual consistency
- Clean typography with clear hierarchy
- Subtle shadows, not heavy drop shadows
- Respects whitespace and visual rhythm

---

## 10. Copy Audit

### Keep

| Copy | Why |
|------|-----|
| "Reclaim Your Browser. Restore Your Focus." | Strong, emotional, parallel structure |
| "Buy once. Use forever." | Clear anti-subscription positioning |
| "One-time purchase. Own it forever." | Clear pricing message |
| "Tab Overload Silently Destroys Your Productivity" | Punchy problem statement |
| "Clean Your Tabs in 3 Steps" | Clear workflow |
| "Review Before You Act" | Key differentiator — keep phrasing |

### Rewrite

| Copy | Rewrite To |
|------|------------|
| "Intelligent Chrome tab management for macOS power users. Auto-cleanup, smart sessions, statistics, and zero regrets." | Lead with benefit: "Your Chrome, fast again. One click, zero risks." |
| "Built for macOS Power Users" | Too generic — show what it does instead |
| "AI-powered detection" | Don't use — change to "Smart URL normalization" or remove |
| "Exact and near-duplicate tabs" | Be precise: "Finds duplicate tabs by normalizing URLs" |
| Feature card copy (generic) | Each card should answer: What do I get? Why do I care? |

### Remove

- "Download Free" — no free tier exists
- "Free" pricing card — no free tier exists
- "10 closes/day" — not applicable
- "AI-powered" — not in code
- Any claim about cross-browser support
- Any claim about cloud sync

### Merge

- The 13-feature bullet list in pricing is overwhelming — merge into 3-4 key benefit areas
- "Smart Detection" + "Duplicate Detection" features — merge into one "Smart Duplicate Detection" with explanation

---

## 11. Final Handoff for Next Prompt

### LANDING_PAGE_CONTEXT_HANDOFF

**Product:** TabPilot — native macOS Chrome tab management utility  
**Price:** $19.99 one-time, no subscription  
**Distribution:** Direct download (S3/CloudFront), notarized DMG  
**Purchase flow:** Landing page → Dodo Payments hosted checkout → Download link  
**No login required.**  
**No free tier.**

### Key Positioning

- **One-liner:** "Your Chrome, fast again. One click, zero risks."
- **What it is:** Native macOS app (not extension) that scans Chrome, finds duplicates, closes them safely with review, undo, and protected domains.
- **What makes it different:** Native app with system integration, review-before-close workflow, 30-second undo, protected domains, cleanup impact metrics, tab debt scoring.
- **Target user:** Chrome power users on Mac with 50+ tabs who want performance back.

### Critical Fixes Required

1. **Branding:** "Chrome Tab Manager" → "TabPilot" everywhere
2. **Pricing:** Remove free tier, single $19.99 price
3. **CTAs:** Wire "Buy Now" to Dodo checkout, "Download" to post-purchase page
4. **Restore:** Add "Already purchased? Enter email" for re-download

### Features to Feature

- Review plan before close (key differentiator)
- 30-second undo (key differentiator)
- Protected domains (key differentiator)
- Cleanup impact (memory/CPU freed) — strong proof point
- Tab debt scoring — unique proof point
- Sessions (save/restore workflow)
- Auto-cleanup rules

### Features to De-Emphasize

- Export (secondary)
- URL patterns (secondary, power user)
- Statistics (secondary)
- Global hotkeys (secondary)

### Screenshots Needed

1. Main scan results (Standard or SuperUser view) — hero shot
2. Review Plan overlay — safety/differentiation
3. Cleanup Impact sheet — proof it works
4. Statistics view — awareness value
5. Scanning in progress — polish and personality
6. Sidebar Tab Health gauge — at-a-glance value

### Trust Signals to Include

- "Tab data never leaves your computer"
- One-time purchase, no subscription
- macOS 14+, Chrome required
- Requires Accessibility permission (state before download)
- Refund policy (30 days)

### What NOT to Claim

- AI-powered (not in code)
- Cross-browser support (not built)
- Cloud sync (not built)
- Enterprise features (not built)
- "Near-duplicate" (just URL normalization)

### Section Structure Recommendation

1. **Hero:** Headline, subhead, single CTA (Buy Now), app screenshot
2. **Problem:** Why tab overload matters (3 pain points)
3. **Solution:** What TabPilot does (lead with scan → review → close → undo)
4. **Features:** Key differentiators (review, undo, protected, impact)
5. **Proof:** Cleanup impact numbers, tab debt score
6. **Pricing:** Single $19.99, clear, no free tier
7. **FAQ:** Common objections (permissions, Chrome only, data privacy)
8. **CTA:** Buy now, download after purchase
9. **Footer:** Privacy, support, terms, contact

### Design Direction

- Premium, tool-like, macOS-native feel
- Show real app screenshots, not CSS mockups
- Clean typography, structured whitespace
- Moderate technicality — show metrics, numbers, proof
- Avoid generic SaaS look, avoid fake glass, avoid startup neon
- Single purchase button, clear path to download after payment
