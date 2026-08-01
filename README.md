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
2. **Gemini key** — paste your key into `GEMINI_API_KEY` in
   `CashMemer/Resources/Info.plist`. Without it the scanner silently falls back to
   on-device Vision OCR, which recovers the store name and total but not line items.
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

`CashMemoView.Page` decides what each page carries; `MemoExporter` renders both into
one PDF with independent page heights, since page 2 always runs longer.

| | Page 1 — Customer Copy | Page 2 — Full Record |
|---|:---:|:---:|
| Receipt no, date, time, category, method | ✅ | ✅ |
| **Customer name** | ✅ | ✅ |
| Items, totals, discount, tax, cash, change | ✅ | ✅ |
| Note 1 | ✅ | ✅ |
| Signature, QR code | ✅ | ✅ |
| Customer phone | — | ✅ |
| Customer email | — | ✅ |
| Saved Location + GPS | — | ✅ |
| **Note 2** | — | ✅ |
| **Issued By** (Google account + email) | — | ✅ |

**Note 1** is pre-filled with `MemoDefaults.noteOne` — *"Thank You for shopping !!!"* —
on every new receipt, including ones Siri creates. Edit it or clear it; an empty Note 1
simply prints nothing.

**Note 2** starts empty by design. It is the private note and never reaches the
customer copy.

**Issued By** is captured from the signed-in Google account **at the moment the receipt
is generated** and stored on the receipt (`issuedByName` / `issuedByEmail`), so signing
out later does not strip the issuer off historic memos.

> One caveat: the app has a single address field — `address`, captured from GPS and
> printed as *Saved Location*. That is what page 1 withholds. There is no separate
> customer-address field; add one if the customer's own address should be distinct
> from the transaction location.

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

## Not yet wired

- **Google Sign-In** — the button and account UI are in place; drop in the GoogleSignIn
  SDK and populate `settings.googleAccountEmail` / `Name`. Local backup export
  (`BackupArchive`) already produces the JSON that upload would send.
- **Restore from backup** — `BackupArchive.restore(from:into:)` is implemented and
  idempotent; it needs a file-importer button in Settings.
