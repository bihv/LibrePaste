<div align="center">
  <img src="./assets/logo.png" width="96" alt="LibrePaste Logo" />

  # LibrePaste

  *A lightweight, native, and subscription-free clipboard history manager for macOS.*

  [![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma%20%7C%20Sequoia-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
  [![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift)](https://swift.org)
  [![Platform Universal](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%7C%20Intel)-blue?style=flat-square)](https://github.com/bihv/LibrePaste)
  [![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

  [Features](#features) • [Keyboard Shortcuts](#keyboard-shortcuts) • [Display Modes](#display-modes) • [Sequential Paste Queue](#sequential-paste-queue) • [Security & Privacy](#security--privacy) • [Build from Source](#building-from-source)

</div>

---

**LibrePaste** is a fast, visual, and privacy-focused clipboard history manager for macOS built natively with Swift, SwiftUI, and AppKit. It provides instant access to copied text, code snippets, formatted rich text, links, and high-resolution images with zero subscriptions, zero telemetry, and minimal system resource footprint.

## Features

- **Pure Native Performance**: Built exclusively with Swift and SwiftUI for buttery-smooth animations and minimal CPU/memory usage.
- **Adaptive Layouts**: Switch effortlessly between a horizontal card carousel with dominant app color extraction and a high-density vertical compact list.
- **Flexible Presentation Modes**: Dock the panel as a bottom shelf, menu bar popover, centered spotlight palette, or attach it directly at your mouse cursor.
- **Sequential Paste Queue**: Collect multiple clippings in batch and paste them consecutively across apps in FIFO or LIFO order.
- **Intelligent Sensitive Data Shield**: Detects and masks API keys (OpenAI, AWS, GitHub), credit cards (Luhn validated), database connection strings, credentials, and custom regex rules.
- **Biometric Security & App Lock**: Secure clipboard history with Touch ID, Apple Watch, or Mac password with auto-lock timeouts and wake/sleep protection.
- **AES-256 GCM Disk Encryption**: Stored media assets and sensitive cache payloads are encrypted using Apple CryptoKit with keys secured in macOS Keychain.
- **Drag & Drop Integration**: Drag clippings directly into text editors, IDEs, browsers, Figma, or design tools with rich native data representations.
- **Rich Text & WYSIWYG Editor**: Built-in editor supporting plain text, styled RTF, raw HTML editing, and JSON formatting/validation.
- **Instant Quick Look**: Press <kbd>Space</kbd> or <kbd>P</kbd> to inspect full-resolution media, structured JSON, URLs, and word/character analytics.
- **Smart Pinboards & Organization**: Pin favorite clippings, organize items into custom-colored boards, and filter by type (Text, Link, Image, Code, Color).
- **Privacy by Design**: Automatically ignores password managers (1Password, Bitwarden, Keychain, KeePass), transient/concealed pasteboards, and user-excluded apps.
- **Robust SQLite Storage**: High-performance SQLite database in WAL mode with auto-pruning limits, configurable retention (7–365 days or forever), and one-click database vacuuming.

## Keyboard Shortcuts

### Global Hotkeys

| Shortcut | Action |
|---|---|
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>V</kbd> | Toggle LibrePaste clipboard panel *(configurable)* |
| <kbd>⌘</kbd> + <kbd>⌥</kbd> + <kbd>V</kbd> | Paste next item from Paste Queue *(configurable)* |
| <kbd>⌥</kbd> + <kbd>⇧</kbd> + <kbd>Q</kbd> | Toggle Paste Queue HUD overlay *(configurable)* |

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

## Display Modes

LibrePaste adapts to any screen layout and workflow preference:

### Presentation Anchors
- **Bottom Shelf**: Expansive floating HUD docked at the bottom screen edge.
- **Menu Bar Popover**: Compact window attached directly below the status bar icon.
- **Center Palette**: Spotlight-style floating search palette in the center of the display.
- **At Mouse Cursor**: Appears directly at your cursor location for zero mouse travel.

### Clip Layout Styles
- **Horizontal Cards**: Visual card carousel featuring app source icons and dominant color branding.
- **Vertical Compact List**: Single-column list with configurable line density (1-line ultra dense or 2-line standard) and number badge overlays.

## Sequential Paste Queue

The **Paste Queue** enables multi-item clipboard collection and sequential pasting:

1. **Enqueue Clips**: Press <kbd>Q</kbd> on any clip in the history panel, or activate **Collect Mode** to automatically append new copies as you work.
2. **Review in HUD**: The floating queue HUD displays queued items with remaining counts, drag-to-reorder, and skip capabilities.
3. **Sequential Pasting**: Press <kbd>⌘</kbd> + <kbd>⌥</kbd> + <kbd>V</kbd> in your target document to paste items one after another.
4. **Flexible Behaviors**: Supports **FIFO** (First-In, First-Out), **LIFO** (Last-In, First-Out), and continuous **Cycle / Loop** mode.

## Security & Privacy

> [!IMPORTANT]
> LibrePaste operates entirely offline on your Mac. No clipboard data, metadata, or telemetry is ever transmitted over the network.

- **Sensitive Data Detection**: Real-time identification of secrets with customizable masking strategies:
  - *Keep Prefix & Suffix* (e.g., `sk-proj-••••••••••••3aB8`)
  - *Keep Last 4 Only* (e.g., `••••••••••••1234`)
  - *Mask All* (e.g., `••••••••••••••••`)
- **Biometric Guard**: Require Touch ID, Apple Watch, or device password to unlock clipboard history or reveal masked credentials.
- **Auto-Purge Timers**: Option to automatically delete sensitive unpinned clips after 1 hour, 24 hours, or 7 days.
- **Excluded Apps & Concealed Data**: Automatic exclusion of password managers, apps marked with transient flags, and user-defined blacklisted applications.
- **Encrypted Local Storage**: Disk image thumbnails and sensitive payloads are encrypted using AES-GCM 256-bit with Keychain-backed master keys.

## System Requirements

- **Operating System**: macOS 14.0 (Sonoma) or later (including macOS Sequoia)
- **Architecture**: Universal binary for Apple Silicon (M1/M2/M3/M4) and Intel x86_64
- **Permissions**: Accessibility permission required for direct paste simulation into target apps

## Building from Source

### Prerequisites
- Xcode 15.0 or later
- Swift 5.9 or later
- macOS 14.0+ SDK

### Steps

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

> [!NOTE]
> On the first launch, macOS will prompt for **Accessibility** permissions under *System Settings → Privacy & Security → Accessibility*. This is required for LibrePaste to paste clippings directly into your active apps via simulated key events.

## Project Structure

```
LibrePaste/
├── Controllers/    # Window management (SettingsWindowController, Panel delegates)
├── Models/         # Data structures (ClipRecord, DisplayMode, KeyboardShortcut, PasteQueueItem)
├── Services/       # Core services (DatabaseManager SQLite WAL, ClipboardWatcher, SecurityManager, CryptoService, PasteQueueManager)
├── ViewModels/     # Observable stores (ClipboardStore, filter & search coordination)
├── Views/          # SwiftUI views (ClipboardView, ClipCardView, ClipCompactRowView, QuickLook, Editor, HUD, Settings tabs)
└── Utilities/      # Helpers (Image downsampling & caching, HotkeyManager, AppColorHelper, PasteSimulator)
```
