# Setting up from a clean Mac

Everything needed is in this repository. If the machine is wiped, clone it again
and start from step 1 — nothing here depends on local state that is not in git.

---

## 1. Install Xcode 14.2

**Do not install Xcode from the App Store.** That always gives the newest version,
and this project targets Swift 5.7 / the iOS 16.2 SDK.

1. Sign in at <https://developer.apple.com/download/all/> with your Apple ID
2. Search **Xcode 14.2**
3. Download the `.xip` (about 7 GB), double-click to expand
4. Drag `Xcode.app` into `/Applications`
5. Open it once and accept the licence — the first launch installs components and
   takes a few minutes

Then install the command line tools:

```bash
xcode-select --install
```

Requires macOS 12.5 Monterey or later.

---

## 2. Add your Apple ID to Xcode

**Xcode → Settings → Accounts → +  → Apple ID** and sign in.

A free Apple ID is enough to run on your own device. See step 6 for the two
features that need a paid account.

---

## 2b. If you have never used Terminal

Steps 3, 4 and 5 are typed into **Terminal**, not Xcode.

Open it with **⌘ + Space**, type `Terminal`, press Return. Paste a command with
**⌘V** and press Return to run it.

**Paste one line at a time.** Wait for the prompt (`yourname@Mac ~ %`) to come back
before the next. This matters more than it looks: the Homebrew installer stops
half-way to ask you to press Return, and if a second line is already pasted it gets
swallowed as that keypress and the install aborts with a confusing
`command not found: brew` afterwards.

Three things that look broken but are not:

- **Homebrew asks for your Mac password, and typing shows nothing** — no dots, no
  stars. That is deliberate. Type it and press Return.
- **Homebrew takes 5–10 minutes** and prints a lot of output. It may pause and ask
  you to press Return to continue.
- **When it finishes it may print a "Next steps" block** with a couple of commands
  to run. Run them, or `brew` will not be found afterwards.

If this repository is **private**, `git clone` in step 4 will ask for a username
and password, and GitHub no longer accepts passwords. Run this first:

```bash
brew install gh
gh auth login
```

Choose **GitHub.com → HTTPS → Login with a web browser**. After that `git clone`
works without prompting.

---

## 3. Install Homebrew and XcodeGen

There is no `.xcodeproj` in this repository on purpose — Xcode project files
corrupt easily and conflict on every change. The project is generated from
`project.yml` instead.

Paste this **on its own**, press Return, then press Return again when it asks
`Press RETURN/ENTER to continue`:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

It takes 5–10 minutes. Only once the prompt is back, run:

```bash
brew install xcodegen
```

If Homebrew is already installed, skip its line. Follow any "Next steps" Homebrew
prints about adding itself to your `PATH`.

On macOS 12 Homebrew prints a warning that the version is old and unsupported.
It installs and works regardless — and macOS 12.5+ is all Xcode 14.2 needs.

---

## 4. Get the code

```bash
cd ~/Documents
git clone https://github.com/wrcovid4-max/cashmemerios.git
cd cashmemerios
git checkout claude/untitled-session-kzaqp5
```

The last line matters. **The code is not on `main`.**

---

## 5. Generate and open the project

```bash
xcodegen generate
open CashMemer.xcodeproj
```

Xcode starts resolving Swift packages the moment it opens — GoogleSignIn and
Firebase. **The first resolve is slow**, several minutes, because Firebase pulls
gRPC, abseil and leveldb. It is not stuck. Wait for the progress bar at the top to
finish before doing anything else.

> Re-run `xcodegen generate` after every `git pull`. It is also the fix if the
> project ever looks wrong — deleting `CashMemer.xcodeproj` and regenerating
> loses nothing.

---

## 6. Set signing on all three targets

Click the blue **CashMemer** project icon at the top of the left sidebar. A list of
TARGETS appears. Do this for **each** of `CashMemer`, `CashMemerWidgets` and
`CashMemerWatch`:

1. **Signing & Capabilities** tab
2. Tick **Automatically manage signing**
3. **Team** → your Apple ID

### If you are on a free Apple ID

Two capabilities need a paid Apple Developer account ($99/yr):

- **App Groups** — click the small **×** on the App Groups capability in all three
  targets to remove it. The app works fine; the widget and watch app just cannot
  read the phone's receipts. The code already falls back to per-app storage when
  the group is unavailable, so nothing crashes.
- **WeatherKit** — the sidebar weather tile shows `—`. Nothing else changes.

Also note a free account's builds **expire after 7 days** and need a rebuild from
Xcode. A paid account lasts a year.

---

## 7. Run it

Pick **CashMemer** and a device or simulator in the toolbar, press **⌘R**.

To run the watch app, change the scheme dropdown to **CashMemerWatch**.

On a physical device the first run needs one extra step: **Settings → General →
VPN & Device Management → your Apple ID → Trust**.

---

## What is already configured

Nothing below needs doing — it is all committed:

| | |
|---|---|
| Gemini, ExchangeRate, Google Maps keys | `CashMemer/Resources/Info.plist` |
| `GoogleService-Info.plist` | `CashMemer/Resources/` |
| Google Sign-In URL scheme | `Info.plist` |
| `FirebaseApp.configure()` | `CashMemer/App/CashMemerApp.swift` |
| App icon, watch icons, in-app logo | `Assets.xcassets` |
| Firebase SDK and GoogleSignIn | `project.yml` |

And in the Firebase console, already done: iOS app registered as
`com.cashmemer.app`, Google sign-in enabled, Firestore rules published.

---

## When the build fails

It probably will the first time — this project was written without a compiler
available, so expect mistakes.

In Xcode's left sidebar, click the **⚠️ / ❌ icon** (Issue Navigator, or **⌘5**).
Copy the errors and hand them over to be fixed.

**Errors worth trying yourself first:**

| Error | Fix |
|---|---|
| `Multiple commands produce Info.plist` | `xcodegen generate` again |
| Package resolution fails on Firebase | Lower `exactVersion` in `project.yml` — try `10.24.0`, then `10.15.0` |
| Package resolution fails on GoogleSignIn | Try `7.1.0` in `project.yml` |
| `No such module 'FirebaseAuth'` | Packages have not finished resolving. **File → Packages → Resolve Package Versions** |
| Signing errors | A target was missed in step 6 |

---

## Keeping your work

**Nothing is backed up anywhere except GitHub.** After any change:

```bash
git add -A
git commit -m "what changed"
git push
```

If the Mac is wiped, everything above reproduces from step 1. The only things not
in git are Xcode itself and your Apple ID login.
