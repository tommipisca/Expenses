<p align="center">
  <img src="AppIcon.png" alt="Expenses icon" width="128" height="128">
</p>

<h1 align="center">Expenses</h1>

<p align="center">
  An iOS and iPadOS app to track monthly spending by tag, with budgets, recurring expenses and Home Screen widgets.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17%2B-0A84FF?style=flat-square" alt="iOS 17+">
  <img src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/SwiftUI-UI-1F4E79?style=flat-square" alt="SwiftUI">
  <img src="https://img.shields.io/badge/WidgetKit-Widgets-6C63FF?style=flat-square" alt="WidgetKit">
  <img src="https://img.shields.io/badge/Built_with-xtool-0EA5A4?style=flat-square" alt="Built with xtool">
  <img src="https://img.shields.io/badge/License-MIT-2E8B57?style=flat-square" alt="MIT License">
</p>

Expenses shows how much you spent this month and on what, as a ring split by tag. Amounts are in euros with Italian formatting, and the interface is in Italian. It is a sister app of [ExamsTrack](https://github.com/tommipisca/ExamsTrack) and shares its "ink" theme. It is written entirely in SwiftUI and developed on Linux (Ubuntu on WSL) with [xtool](https://github.com/xtool-org/xtool), without Xcode or a Mac.

## Features

**Month view**
- Monthly total as a ring split by tag (or as a segmented bar), with the comparison against the same day of the previous month
- Day-by-day spending strip and the latest expenses of the month, laid out like a receipt
- Swipe between months; on iPad in landscape, a two-column layout

**Expenses and tags**
- Expenses with amount, merchant, note, date and tag; only the amount is required
- Tags with a colour and an optional monthly budget; the tag of a merchant is suggested from its last expense
- Weekly, monthly or yearly recurring expenses, generated automatically on their due dates
- History by year and month, with search and filters on one or more tags

**Budgets**
- Optional monthly budget for the total and for each tag
- Local notifications at 80% and 100%, sent once per budget and month across devices

**System integration**
- Home Screen widgets in every size (including extra-large on iPad) and Lock Screen widgets: total, ring by tag, budget and latest expenses
- "Aggiungi spesa" Shortcuts action, designed for the Wallet "Transaction" automation: card payments are saved without opening the app and wait in a "to confirm" list
- `expenses://add?amount=…&merchant=…` URL to open the form prefilled

**Data**
- Local JSON storage shared between app and widgets through an App Group
- Sync between iPhone and iPad via a file in a user-chosen folder (for example iCloud Drive), merged item by item
- Automatic daily backups in the sync folder

## Tech stack

<p align="center">
  <a href="https://skillicons.dev">
    <img src="https://skillicons.dev/icons?i=swift,linux,git" alt="Swift, Linux and Git">
  </a>
</p>

- [Swift 6](https://www.swift.org) + [SwiftUI](https://developer.apple.com/xcode/swiftui/), with no storyboards or `.xcodeproj`
- [WidgetKit](https://developer.apple.com/widgets/) and [App Intents](https://developer.apple.com/documentation/appintents) for widgets and the Shortcuts action
- [xtool](https://github.com/xtool-org/xtool) to build, sign and install on a device from Linux
- Swift Package Manager, with the business logic in a separate, fully tested `ExpensesCore` package

## Getting started

The only thing to install is [xtool](https://github.com/xtool-org/xtool), set up with `xtool setup` and an Apple ID. A free account works, but it needs the patched build described in [Patched xtool](#patched-xtool). You also need an iPhone or iPad connected via USB.

```bash
# 1. Clone the repository
git clone https://github.com/tommipisca/Expenses.git
cd Expenses

# 2. Build, add the App Intents metadata and install on the connected device
scripts/install.sh

# Or build without installing
scripts/install.sh --no-install
```

`scripts/install.sh` replaces `xtool dev`. It runs `xtool dev build`, then `scripts/appintents.sh`, then `xtool install`. On WSL it also points xtool to the Windows Apple Mobile Device service through the WSL gateway, if `USBMUXD_SOCKET_ADDRESS` is not set.

### App Intents metadata

Xcode generates `Metadata.appintents`, the file iOS reads to find an app's App Intents actions. xtool does not. Without it the app still runs, but the "Aggiungi spesa" action does not show up in Shortcuts.

`scripts/appintents.sh` generates the metadata for the app and for every extension listed in `xtool.yml`. It uses [re-appintentsmetadataprocessor](https://codeberg.org/viraptor/re-appintentsmetadataprocessor), an open-source reimplementation of Apple's tool. A prebuilt Linux x86_64 binary is included in [`tools/appintentsmetadataprocessor`](tools/appintentsmetadataprocessor), together with instructions for building it on other platforms.

### Patched xtool

The widgets read the app's data through an App Group. Upstream xtool marks the App Group capability as unavailable on free accounts (`isFree: false`) and drops the entitlement while signing. The widget then fails with `client is not entitled` and stays empty. Apple actually accepts one App Group on a free account, so [`tools/xtool/app-groups-free-account.patch`](tools/xtool/app-groups-free-account.patch) changes a single line in `Sources/XKit/DeveloperServices/App IDs/Entitlements/DeveloperServicesCapability.swift`:

```diff
 extension AppGroupEntitlement: EntitlementWithCapability {
     var capability: DeveloperServicesCapability {
-        DeveloperServicesCapability(.appGroups, isFree: false)
+        DeveloperServicesCapability(.appGroups, isFree: true)
     }
 }
```

The patch was used with xtool 1.21.0 and still applies to 1.24.0. To build a patched AppImage (requires Docker):

```bash
scripts/build-xtool.sh          # or: scripts/build-xtool.sh 1.24.0
ln -sf "$PWD/xtool-1.21.0-appgroups.AppImage" ~/.local/bin/xtool
xtool --version                 # 1.21.0-appgroups
```

With a paid Apple account the patch is not needed.

> [!NOTE]
> xtool adds an `XTL-<team ID>.` prefix to bundle IDs when signing, which also renames the App Group. The app derives the real group name from its running bundle ID (see `ExpensesCore/Sources/ExpensesCore/AppGroup.swift`).

With a free Apple account the installed app expires after 7 days and must be reinstalled (data is kept); Expenses shows the expiration date in its settings. The free account also limits the number of App IDs, so reuse the bundle IDs in `xtool.yml` (or change them to your own).

### Running the tests

The logic in `ExpensesCore` has no UI dependencies, so its test suite runs on Linux as well:

```bash
cd ExpensesCore
swift test
```

## Project structure

```
Expenses/
├── Sources/
│   ├── Expenses/            # SwiftUI app: month, history, tags, settings, sync, Shortcuts action
│   └── ExpensesWidget/      # Home Screen and Lock Screen widgets
├── ExpensesCore/            # Shared logic: models, store, budgets, recurrences, sync merge, widget summary
│   ├── Sources/ExpensesCore/
│   └── Tests/ExpensesCoreTests/
├── scripts/
│   ├── install.sh           # Build + App Intents metadata + install (use instead of `xtool dev`)
│   ├── appintents.sh        # Generates Metadata.appintents for the app and the widget
│   └── build-xtool.sh       # Builds xtool with the App Group patch
├── tools/
│   ├── appintentsmetadataprocessor/  # Prebuilt metadata generator (Linux x86_64)
│   └── xtool/               # xtool patch for App Groups on free accounts
├── Package.swift            # SwiftPM manifest (app + widget targets)
├── xtool.yml                # xtool config: bundle IDs, plists, entitlements, icon
├── App-Info.plist           # App Info.plist (also declares the expenses:// URL scheme)
├── Widget-Info.plist        # Widget extension Info.plist
├── App.entitlements         # App Group shared by app and widget
└── AppIcon.png              # 1024×1024 app icon
```

## Disclaimer

Expenses is an independent personal project. It is not affiliated with, endorsed by or sponsored by Apple Inc. Apple, iPhone, iPad, iOS, iPadOS, iCloud, Wallet, Xcode and Swift are trademarks of Apple Inc.

- **No Apple software is included.** This repository contains no Apple SDK, Xcode component or signed app. `xtool setup` builds the iOS SDK on your machine from an `Xcode.xip` that you download from Apple yourself. By downloading Xcode you accept Apple's license terms, including any limits on where the SDK may be used. Make sure your use complies with them.
- **Apple developer services.** xtool talks to Apple's developer services the way Xcode does, and the [patch](tools/xtool/app-groups-free-account.patch) only asks those services for a capability that Apple then grants or refuses. You build, sign and install the app with your own Apple ID. You are responsible for complying with the Apple Developer Agreement and any other terms you have accepted.
- **No app distribution.** No prebuilt or signed iOS app is distributed. Apps signed with a free account are meant to be installed on your own devices.
- **Third-party tools.** [xtool](https://github.com/xtool-org/xtool) and [re-appintentsmetadataprocessor](https://codeberg.org/viraptor/re-appintentsmetadataprocessor) are independent projects released under the MIT license by their authors.
- **No warranty.** The software is provided "as is", without warranty of any kind, as stated in the [license](LICENSE). Keep backups of your data.

## License

Distributed under the [MIT license](LICENSE).
