<div align="center">
  <img src="./assets/logo.png" width="96" alt="LibrePaste Logo" />

  # LibrePaste

  *A fast, native, and subscription-free clipboard history manager for macOS.*

  [![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma%20%7C%20Sequoia-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
  [![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift)](https://swift.org)
  [![Universal Binary](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%7C%20Intel)-blue?style=flat-square)](https://github.com/bihv/LibrePaste)
  [![Languages](https://img.shields.io/badge/Languages-EN%20%7C%20VI-teal?style=flat-square)](LibrePaste/Resources/Localizable.xcstrings)
  [![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

  [Key Features](#key-features) • [Keyboard Shortcuts](#keyboard-shortcuts) • [Display & Layout Modes](#display--layout-modes) • [Sequential Paste Queue](#sequential-paste-queue) • [Security & Privacy](#security--privacy) • [Building from Source](#building-from-source)

</div>

---

**LibrePaste** is a lightweight, visual, and privacy-focused clipboard history manager for macOS built natively with Swift, SwiftUI, and AppKit. It provides instant access to copied text, code snippets, formatted rich text, links, colors, and high-resolution images with zero subscriptions, zero telemetry, and minimal system resource footprint.

## Key Features

- **Pure Native Performance**: Written natively in Swift and SwiftUI for buttery-smooth 120Hz ProMotion animations and low CPU/memory overhead.
- **Adaptive Layouts**: Seamlessly switch between a horizontal card carousel with dominant app color extraction and a high-density vertical compact list.
- **Flexible Presentation Modes**: Dock the panel as a bottom shelf, menu bar popover, centered spotlight palette, or attach it directly at your mouse cursor.
- **Sequential Paste Queue**: Collect multiple clippings in batch and paste them consecutively across apps in FIFO, LIFO, or continuous Loop mode.
- **Intelligent Sensitive Data Shield**: Real-time multi-occurrence detection and masking for API keys (OpenAI, AWS, GitHub, Stripe, Slack), credit cards (Luhn validated), PII (Email addresses, Phone numbers, CCCD, SSN), passwords, and custom user-defined regex rules.
- **Biometric Security & App Lock**: Lock clipboard history behind Touch ID, Apple Watch, or Mac password with customizable auto-lock timeouts and wake/sleep protection.
- **AES-256 GCM Disk Encryption**: Stored media assets and sensitive cache payloads are encrypted using Apple CryptoKit with master keys secured in macOS Keychain.
- **Rich Text & WYSIWYG Editor**: Built-in editor supporting plain text, styled RTF, sanitized HTML editing, and JSON formatting/validation.
- **Instant Quick Look**: Press <kbd>Space</kbd> or <kbd>P</kbd> to inspect full-resolution media, structured JSON trees, color hex codes, URLs, and word/character analytics.
- **Smart Pinboards & Organization**: Pin favorite clippings, organize items into custom-colored boards, and filter by type (Text, Link, Image, Code, Color).
- **Drag & Drop Integration**: Drag clippings directly into text editors, IDEs, browsers, Figma, or design tools with rich native data representations.
- **Multi-Language Support**: Full internationalization with runtime switching between English (`en`) and Vietnamese (`vi`), alongside System Default.
- **App Appearance Controls**: Seamlessly toggle between System Default, Always Light, and Always Dark appearance modes.
- **Privacy by Design**: Automatically ignores password managers (1Password, Bitwarden, Apple Keychain, KeePassXC), transient/concealed pasteboards, and user-excluded apps.
- **Robust SQLite Storage**: High-performance SQLite database in WAL mode with auto-pruning limits, configurable retention (7–365 days or forever), and one-click database vacuuming.

## Keyboard Shortcuts

### Global Hotkeys

| Shortcut | Action | Configurable |
|---|---|:---:|
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>V</kbd> | Toggle LibrePaste clipboard panel | Yes |
| <kbd>⌘</kbd> + <kbd>⌥</kbd> + <kbd>V</kbd> | Paste next item from Paste Queue | Yes |
| <kbd>⌥</kbd> + <kbd>⇧</kbd> + <kbd>Q</kbd> | Toggle Paste Queue HUD overlay | Yes |

### In-App Navigation & Actions

| Shortcut | Action |
|---|---|
| <kbd>↵</kbd> (Return) | Paste selected clip to active application |
| <kbd>⌥</kbd> + <kbd>↵</kbd> | Paste selected clip as plain text (strips formatting) |
| <kbd>1</kbd> – <kbd>9</kbd> | Quick paste clip by index position |
| <kbd>←</kbd> / <kbd>→</kbd> or <kbd>↑</kbd> / <kbd>↓</kbd> | Navigate clip cards / list items |
| <kbd>⌘</kbd> + <kbd>F</kbd> or <kbd>/</kbd> | Focus instant search bar |
| <kbd>Space</kbd> or <kbd>P</kbd> | Toggle Quick Look preview window |
| <kbd>E</kbd> | Open Rich Text / HTML / JSON editor |
| <kbd>Q</kbd> | Add to / Remove selected clip from Paste Queue |
| <kbd>⌘</kbd> + <kbd>⌫</kbd> | Delete selected clip from history |
| <kbd>Esc</kbd> | Clear search / Close floating panel |

## Display & Layout Modes

LibrePaste adapts to any screen layout and workflow preference:

### Presentation Anchors

- **Bottom Shelf**: Expansive floating HUD docked at the bottom edge of the display.
- **Menu Bar Popover**: Compact window attached directly below the status bar icon.
- **Center Palette**: Spotlight-style floating search palette centered on your active screen.
- **At Mouse Cursor**: Appears directly at your cursor location for zero mouse travel.

### Clip Layout Styles

- **Horizontal Cards**: Visual card carousel featuring app source icons and dominant color branding.
- **Vertical Compact List**: Single-column list with configurable line density (1-line ultra-dense or 2-line standard) and number badge overlays.

## Sequential Paste Queue

The **Paste Queue** enables multi-item clipboard collection and sequential pasting:

1. **Enqueue Clips**: Press <kbd>Q</kbd> on any clip in the history panel, or activate **Collect Mode** to automatically append new copies as you work.
2. **Review in HUD**: The floating queue HUD displays queued items with remaining counts, drag-to-reorder, and skip capabilities.
3. **Sequential Pasting**: Press <kbd>⌘</kbd> + <kbd>⌥</kbd> + <kbd>V</kbd> in your target document to paste items consecutively.
4. **Flexible Behaviors**: Supports **FIFO** (First-In, First-Out), **LIFO** (Last-In, First-Out), and continuous **Cycle / Loop** mode.

## Security & Privacy

> [!IMPORTANT]
> LibrePaste operates 100% locally and offline on your Mac. No clipboard data, metadata, or telemetry is ever transmitted over the network.

- **Sensitive Data Detection**: Automated identification and multi-occurrence masking of secrets with customizable masking strategies:
  - *Keep Prefix & Suffix* (e.g., `sk-proj-••••••••••••3aB8`, `j••••e@example.com`)
  - *Keep Last 4 Only* (e.g., `••••••••••••1234`, `•••• •••• 5678`)
  - *Mask All* (e.g., `••••••••••••••••`)
- **Custom Regex Rules**: Add custom regex pattern rules in Settings to automatically mask proprietary tokens, internal URLs, or custom credentials.
- **Biometric Guard**: Require Touch ID, Apple Watch, or device password to unlock clipboard history or reveal masked credentials.
- **Auto-Purge Timers**: Option to automatically delete sensitive unpinned clips after 1 hour, 24 hours, or 7 days.
- **Excluded Apps & Concealed Data**: Automatic exclusion of password managers, apps marked with transient flags, and user-defined blacklisted applications.
- **Encrypted Local Storage**: Disk image thumbnails and sensitive payloads are encrypted using AES-GCM 256-bit with Keychain-backed master keys.

## System Requirements

- **Operating System**: macOS 14.0 (Sonoma) or later (including macOS Sequoia)
- **Architecture**: Universal binary for Apple Silicon (M1/M2/M3/M4) and Intel x86_64
- **Permissions**: Accessibility permission required for direct paste simulation into target apps

> [!NOTE]
> On the first launch, macOS will prompt for **Accessibility** permissions under *System Settings → Privacy & Security → Accessibility*. This is required for LibrePaste to paste clippings directly into your active apps via simulated key events.

## Building from Source

### Prerequisites

- Xcode 15.0 or later
- Swift 5.9 or later
- macOS 14.0+ SDK

### Development Build

1. Clone the repository:
   ```bash
   git clone https://github.com/bihv/LibrePaste.git
   cd LibrePaste
   ```

2. Open the project in Xcode:
   ```bash
   open LibrePaste.xcodeproj
   ```

3. Build and run using Xcode (<kbd>⌘</kbd> + <kbd>R</kbd>), or compile via command line:
   ```bash
   xcodebuild -scheme LibrePaste -configuration Release build
   ```

### Release Packaging

To build a notarization-ready Universal `.app`, DMG image, ZIP archive, and generate SHA256 checksums:

```bash
chmod +x scripts/build_release.sh
./scripts/build_release.sh
```

The packaged artifacts will be output to the `build/release/` directory.

## Project Structure

```
LibrePaste/
├── Controllers/    # Window management (SettingsWindowController, FloatingPanel)
├── Models/         # Data structures (ClipRecord, DisplayMode, AppLanguage, AppAppearance, KeyboardShortcut)
├── Resources/      # Localization catalogs (Localizable.xcstrings) and assets
├── Services/       # Core services (DatabaseManager SQLite WAL, ClipboardWatcher, SecurityManager, CryptoService, SensitiveDataService, PasteQueueManager)
├── ViewModels/     # Observable stores (ClipboardStore, filter & search coordination)
├── Views/          # SwiftUI views (ClipboardView, ClipCardView, ClipCompactRowView, QuickLook, Editor, HUD, Settings tabs)
└── Utilities/      # Helpers (LocalizationService, HotkeyManager, AppColorHelper, PasteSimulator, ThumbnailManager)
```
