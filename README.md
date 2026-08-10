# Cash Memer — iOS · iPadOS · watchOS

Professional receipt organiser. A native rebuild of the Android app, targeting
**iOS/iPadOS 16.0** and **watchOS 9.0**, buildable on **Xcode 14.2**.

---

## Building

The project is generated from `project.yml` so there is no `.xcodeproj` in git.

```bash
brew install xcodegen     # once
xcodegen generate
open CashMemer.xcodeproj
```

Then set your team in **Signing & Capabilities** for all three targets and build.

### Before the first run

1. **App Group** — all three targets share `group.com.cashmemer.shared`. Register it
   on your developer account (or change the ID in `AppSettings.appGroupID` and the
   three `.entitlements` files). The Core Data store, preferences and the widget
   all live in it.
2. **API keys** — already in `CashMemer/Resources/Info.plist`: `GEMINI_API_KEY`
   (scanner), `EXCHANGE_RATE_API_KEY` (Rates screen, falls back to the keyless
   endpoint), `GOOGLE_MAPS_API_KEY` (reverse-geocoding fallback when `CLGeocoder`
   rate-limits). Read through `APIKeys`. Keep this repo **private**, and restrict
   each key to bundle id `com.cashmemer.app` in its console.
3. **WeatherKit** *(optional)* — the sidebar weather tile and the watch header need
   the WeatherKit capability on a paid account. Unprovisioned, the tile shows `—`.
4. **App icon** — already installed. Your artwork was cropped out of its black
   letterbox, edge-extended into the baked-in rounded corners and flattened to
   opaque RGB, then exported as a 1024pt single-size iOS icon plus the full
   watchOS ladder. It also appears on the App Lock screen as `AppLogo`.

---

## Xcode 14.2 constraints

Swift 5.7 / iOS 16.2 SDK, which rules out a few things worth knowing about:

| Not available | Used instead |
|---|---|
| SwiftData (iOS 17) | **Core Data** — `CashMemer.xcdatamodeld`, manual `NSManagedObject` subclasses |
| `@Observable` / Observation (Swift 5.9) | `ObservableObject` + `@Published` + `@EnvironmentObject` |
| `if` / `switch` expressions (Swift 5.9) | explicit `return` in every branch |
| `navigationDestination(item:)` (iOS 17) | `navigationDestination(isPresented:)` |
| `.toolbar(removing: .sidebarToggle)` (iOS 17) | omitted |

Everything else the app needs — AppIntents, ActivityKit, DataScanner, PencilKit,
PDFKit, Swift Charts, NavigationSplitView, `.photosPicker` — shipped in iOS 16.

---

## Platform integration

**App Intents & Siri** (`Shared/Intents/`)
`CreateReceiptIntent` (runs in the background, no app launch), `ScanReceiptIntent`,
`FindReceiptIntent`, `TodaysTotalIntent`, `OpenDashboardIntent`. `ReceiptEntity` is a
first-class `AppEntity` with an `EntityStringQuery`, so a receipt can be passed between
Shortcuts actions. `CashMemerShortcuts` registers Siri phrases with zero user setup —
*"Scan a receipt with Cash Memer"*, *"What is my total in Cash Memer"*.

**Spotlight** (`Shared/Spotlight/`)
`NSCoreDataCoreSpotlightDelegate` indexes every receipt automatically, so edits and
deletes stay in sync without hand-written index calls. Each item carries the store,
number, customer, every item name and the coordinates. Tapping a result deep-links
into the memo; `ReceiptDetailView` also donates an `NSUserActivity` for prediction.

**Live Activity** (`Shared/LiveActivity/`, `CashMemerWidgets/ScanLiveActivity.swift`)
The scanner drives an activity through capture → upload → parse → result, with a full
Dynamic Island layout (expanded, compact and minimal) plus a Lock Screen banner. OCR
round-trips take seconds and people put the phone down; the result reaches them anyway.
Failures end the activity rather than leaving it spinning.

**PencilKit** (`SignaturePadView`)
`PKCanvasView` gives pressure, tilt and palm rejection on iPad. `drawingPolicy` is
`.anyInput` by default so finger signing still works on iPhone, with an Apple Pencil–only
toggle on iPad. Ink is cropped to its bounding box before rasterising at 3×.

**PDFKit** (`ReceiptDetailView`)
Saved memos render to a real PDF and display in `PDFView`, so pinch-zoom, text
selection, Markup and the standard share sheet all behave as they do in Files. The same
`CashMemoView` produces the on-screen preview and the exported file.

---

## Every memo is two pages

Rebuilt to match the reference Cash Memer PDF exactly: a 600pt cream sheet
(`#FAF9F6`) on a warm grey margin (`#DCDCD2`), navy `CASH MEMO` title (`#102C57`),
black body, and the double/single rule rhythm between blocks. `MemoExporter`
renders both pages into one PDF with independent page heights.

| | Page 1 | Page 2 — `CASH MEMO (Page 2)` |
|---|:---:|:---:|
| Receipt No `#41`, date, time, Place/Store, category, method | ✅ | ✅ |
| Customer — **name only**, one line | ✅ | — |
| **Customer Details** — name, phone, email, **address** | — | ✅ |
| Items, `@ Rs12.00 each`, subtotal, discount, `Tax (15.0%)`, grand total | ✅ | ✅ |
| Cash Given, Change Amount | ✅ | ✅ |
| `Note:` (Note 1) | ✅ | — |
| `Saved Location:` + GPS | ✅ | — |
| `Note (Page 2):` (Note 2) | — | ✅ |
| `Issuer Account:` — Google name + email | — | ✅ |
| Signature, QR, `Thank you for shopping with us!` | ✅ | ✅ |

**Two address fields, deliberately.** `customerAddress` is the customer's own
address and prints on page 2 only. `address` is the GPS-captured transaction
location, printed as *Saved Location* on page 1. They are not the same thing.

**Receipt numbers are sequential**, like a paper book — `CDReceipt.nextNumber(in:)`
takes one past the highest already issued, and the memo prints it as `#41`.

**Note 1** is pre-filled with `MemoDefaults.noteOne` — *"Thank You for shopping !!!"* —
on every new receipt, including ones Siri creates. Edit or clear it freely.
**Note 2** starts empty and only ever reaches page 2.

**Issued By** is captured from the signed-in Google account at generation time and
stored on the receipt, so signing out later does not strip it off historic memos.

**Exported filename** matches the reference:
`Receipt #41 - Mart (Example) - 20260801_22_32_29 - Cash Memer.pdf`
The timestamp is the moment of export, not the receipt's own time.

---

**Watch app** (`CashMemerWatch/`)
History and Dashboard only — creating a memo needs a keyboard and a signature. The phone
pushes a trimmed `WatchPayload` via `updateApplicationContext`, cached to disk so History
still has content out of range. The watch target deliberately does not link Core Data,
PDFKit or the scanner.

**Widgets** — `TodaySummaryWidget` covers Home Screen (small/medium) and Lock Screen
(rectangular/inline/circular) families.

---

## Layout

- **iPad** — `NavigationSplitView`: sidebar (destinations + Quick Overview + contact
  footer), and New Receipt runs three columns with a **live CASH MEMO preview** that
  redraws on every keystroke.
- **iPhone** — six-tab bar; the memo preview sits inline at the foot of the form.

## Bilingual EN ⇄ اردو

Strings live in Swift dictionaries (`Shared/Localization/`) rather than `.strings`
files, because the toggle has to flip the language **and** the layout direction with no
relaunch. `.appLanguage(_:)` sets the language, `layoutDirection` and `locale` together.

---

## Repo layout

```
Shared/            Models, Core Data stack, localization, theme, memo renderer,
                   App Intents, Spotlight, Live Activity attributes, watch payload
CashMemer/         iOS/iPadOS app — App, Features/, Services/, Resources/
CashMemerWidgets/  Widget + Live Activity extension
CashMemerWatch/    watchOS app (History + Dashboard)
```

## Google Sign-In

Configured and ready. Bundle identifier **`com.cashmemer.app`**, Firebase project
**`cash-memer`**. `GoogleService-Info.plist` is in `CashMemer/Resources/` and its
`REVERSED_CLIENT_ID` is already wired as a URL scheme in `Info.plist`.

**The Firebase SDK is deliberately not used.** Signing in only needs an OAuth client
id, which `GoogleAuthService` reads straight out of `GoogleService-Info.plist`. The
only dependency is `GoogleSignIn-iOS` over SPM, pinned to 7.0.0 — the last release
verified against Xcode 14. Pulling in `firebase-ios-sdk` would add a large
dependency tree, and its current releases require Xcode 15.

The one remaining console step is **Authentication → Sign-in method → Google →
Enable**, if the Android app has not already turned it on.

The signed-in account is what stamps `Issuer Account` onto page 2 of each memo.

## Not yet wired

- **Restore from backup** — `BackupArchive.restore(from:into:)` is implemented and
  idempotent; it needs a file-importer button in Settings.
- **Cloud upload** — the Drive call itself. `BackupArchive.export` already produces
  the JSON it would send, and sign-in now provides the account.
