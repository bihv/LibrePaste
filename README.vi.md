<div align="center">
  <img src="./assets/logo.png" width="96" alt="LibrePaste Logo" />

  # LibrePaste

  *Trình quản lý lịch sử clipboard nhanh, native và không phí thuê bao cho macOS.*

  [![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma%20%7C%20Sequoia-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
  [![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift)](https://swift.org)
  [![Universal Binary](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%7C%20Intel)-blue?style=flat-square)](https://github.com/bihv/LibrePaste)
  [![Languages](https://img.shields.io/badge/Languages-EN%20%7C%20VI-teal?style=flat-square)](LibrePaste/Resources/Localizable.xcstrings)
  [![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

  [English](README.md) • [Tiếng Việt](README.vi.md)

  [Tính năng nổi bật](#tính-năng-nổi-bật) • [Phím tắt](#phím-tắt) • [Chế độ hiển thị & Bố cục](#chế-độ-hiển-thị--bố-cục) • [Paste Queue](#sequential-paste-queue-hàng-đợi-dán) • [Bảo mật & Quyền riêng tư](#bảo-mật--quyền-riêng-tư) • [Build từ mã nguồn](#build-từ-mã-nguồn)

</div>

---

**LibrePaste** là ứng dụng quản lý lịch sử clipboard trực quan, gọn nhẹ và bảo mật cho macOS, được phát triển 100% native bằng Swift, SwiftUI và AppKit. Ứng dụng giúp bạn truy cập tức thì vào văn bản đã copy, code snippet, rich text, link, mã màu và hình ảnh độ phân giải cao — hoàn toàn không có phí thuê bao, không thu thập dữ liệu (zero telemetry) và tiêu thụ cực ít tài nguyên hệ thống.

## Tính năng nổi bật

- **Hiệu năng Native tối đa**: Viết 100% bằng Swift và SwiftUI cho trải nghiệm mượt mà 120Hz ProMotion, mức chiếm dụng CPU và RAM cực thấp.
- **Bố cục linh hoạt (Adaptive Layouts)**: Chuyển đổi linh hoạt giữa dạng Card Carousel ngang (tự động trích xuất màu app) và dạng Compact List dọc siêu gọn.
- **Đa dạng chế độ hiển thị (Presentation Modes)**: Neo panel ở cạnh dưới màn hình (Bottom Shelf), popover trên Menu Bar, bảng tìm kiếm trung tâm kiểu Spotlight (Center Palette), hoặc mở ngay tại vị trí con trỏ chuột.
- **Sequential Paste Queue**: Gom nhiều clip cùng lúc và dán tuần tự sang các ứng dụng khác theo chế độ FIFO, LIFO hoặc Loop liên tục.
- **Tự động nhận diện & Mask dữ liệu nhạy cảm**: Tự động phát hiện theo thời gian thực và mask nhiều vị trí chứa API key (OpenAI, AWS, GitHub, Stripe, Slack), thẻ tín dụng (Luhn validation), PII (Email, Số điện thoại, CCCD, SSN), mật khẩu cùng các regex rules tùy chỉnh.
- **Bảo mật Touch ID & Khóa ứng dụng**: Khóa lịch sử clipboard bằng Touch ID, Apple Watch hoặc mật khẩu máy Mac, hỗ trợ tự động khóa sau timeout hoặc khi sleep/wake.
- **Mã hóa AES-256 GCM**: Media assets và dữ liệu nhạy cảm được mã hóa an toàn bằng Apple CryptoKit với master key lưu trong macOS Keychain.
- **Trình soạn thảo Rich Text & WYSIWYG**: Tích hợp sẵn editor hỗ trợ plain text, RTF, sanitized HTML và format/validate JSON ngay trong app.
- **Quick Look tức thì**: Nhấn <kbd>Space</kbd> hoặc <kbd>P</kbd> để xem nhanh ảnh full-resolution, cấu trúc cây JSON, color swatch hex, favicon URL và thống kê word/character.
- **Pinboard thông minh & Đổi tên Clip**: Ghim clip yêu thích, đổi alias/tên clip (<kbd>R</kbd>), phân loại theo board màu tùy chỉnh và filter theo type (Text, Link, Image, Code, Color).
- **Tự động fetch Favicon & Preview màu sắc**: Tự động fetch favicon sắc nét cho URL, hiển thị swatch màu kèm chuyển đổi định dạng nhanh (HEX, RGB, HSL).
- **Kéo & Thả (Drag & Drop)**: Hỗ trợ kéo thả trực tiếp clip vào text editor, IDE, browser, Figma hoặc các ứng dụng thiết kế.
- **Hỗ trợ đa ngôn ngữ**: Hỗ trợ chuyển đổi trực tiếp giữa tiếng Anh (`en`), tiếng Việt (`vi`) hoặc theo System Default.
- **Tùy biến giao diện (Appearance)**: Tùy chỉnh linh hoạt giữa System Default, Always Light và Always Dark.
- **Bảo vệ quyền riêng tư**: Tự động bỏ qua password managers (1Password, Bitwarden, Apple Keychain, KeePassXC), transient/concealed pasteboards và các app trong danh sách exclude.
- **Lưu trữ SQLite WAL tối ưu**: Sử dụng SQLite ở chế độ WAL hiệu năng cao, tự động dọn dẹp theo giới hạn số lượng, tùy chỉnh thời gian lưu trữ (7–365 ngày hoặc vĩnh viễn) và hỗ trợ vacuum database 1-click.

## Phím tắt

### Phím tắt toàn cục (Global Hotkeys)

| Phím tắt | Thao tác | Tùy biến |
|---|---|:---:|
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>V</kbd> | Bật / tắt bảng lịch sử LibrePaste | Có |
| <kbd>⌘</kbd> + <kbd>⌥</kbd> + <kbd>V</kbd> | Dán mục tiếp theo từ Paste Queue | Có |
| <kbd>⌥</kbd> + <kbd>⇧</kbd> + <kbd>Q</kbd> | Bật / tắt HUD Paste Queue | Có |

### Phím tắt trong ứng dụng

| Phím tắt | Thao tác |
|---|---|
| <kbd>↵</kbd> (Return) | Dán clip đang chọn vào ứng dụng hiện tại |
| <kbd>⌥</kbd> + <kbd>↵</kbd> | Dán clip dưới dạng plain text (loại bỏ định dạng) |
| <kbd>1</kbd> – <kbd>9</kbd> | Dán nhanh clip theo số thứ tự |
| <kbd>←</kbd> / <kbd>→</kbd> hoặc <kbd>↑</kbd> / <kbd>↓</kbd> | Điều hướng giữa các thẻ clip / danh sách |
| <kbd>⌘</kbd> + <kbd>F</kbd> hoặc <kbd>/</kbd> | Focus vào thanh tìm kiếm |
| <kbd>Space</kbd> hoặc <kbd>P</kbd> | Bật / tắt cửa sổ Quick Look |
| <kbd>R</kbd> | Đổi tên / đặt alias cho clip đang chọn |
| <kbd>E</kbd> | Mở trình soạn thảo Rich Text / HTML / JSON |
| <kbd>Q</kbd> | Thêm vào / Bỏ clip khỏi Paste Queue |
| <kbd>⌘</kbd> + <kbd>⌫</kbd> | Xóa clip khỏi lịch sử |
| <kbd>Esc</kbd> | Xóa tìm kiếm / Đóng panel |

## Chế độ hiển thị & Bố cục

LibrePaste linh hoạt thích ứng với mọi kích thước màn hình và phong cách làm việc:

### Vị trí neo giao diện (Presentation Anchors)

- **Bottom Shelf**: Panel mở rộng cố định ở cạnh đáy màn hình.
- **Menu Bar Popover**: Cửa sổ popover gắn ngay dưới icon trên thanh Menu Bar.
- **Center Palette**: Bảng tìm kiếm nổi giữa màn hình theo phong cách Spotlight.
- **At Mouse Cursor**: Xuất hiện ngay tại vị trí trỏ chuột, tiết kiệm tối đa thao tác di chuyển chuột.

### Kiểu hiển thị danh sách clip (Clip Layout Styles)

- **Horizontal Cards**: Băng chuyền thẻ ngang trực quan hiển thị icon app và màu thương hiệu nổi bật.
- **Vertical Compact List**: Danh sách dọc 1 cột với mật độ tùy chỉnh (1 dòng siêu gọn hoặc 2 dòng chuẩn) kèm số thứ tự dán nhanh.

## Sequential Paste Queue (Hàng đợi dán)

Tính năng **Paste Queue** cho phép gom nhiều mục copy và dán tuần tự từng mục:

1. **Thêm clip vào hàng đợi**: Nhấn <kbd>Q</kbd> trên bất kỳ clip nào trong panel lịch sử, hoặc bật **Collect Mode** để tự động gom mọi nội dung mới copy khi làm việc.
2. **Quản lý trên HUD**: Bảng HUD nổi hiển thị danh sách các mục trong hàng đợi, số lượng còn lại, cho phép kéo thả sắp xếp lại thứ tự hoặc skip mục.
3. **Dán tuần tự**: Nhấn <kbd>⌘</kbd> + <kbd>⌥</kbd> + <kbd>V</kbd> trong tài liệu hoặc ứng dụng đích để dán lần lượt từng mục.
4. **Chế độ linh hoạt**: Hỗ trợ dán theo thứ tự **FIFO** (First-In, First-Out), **LIFO** (Last-In, First-Out) hoặc **Loop** lặp lại tuần hoàn.

## Bảo mật & Quyền riêng tư

> [!IMPORTANT]
> LibrePaste hoạt động 100% offline trên máy Mac của bạn. Tuyệt đối không có bất kỳ dữ liệu clipboard, metadata hay telemetry nào được gửi qua mạng.

- **Tự động nhận diện & Mask dữ liệu nhạy cảm**: Tự động phát hiện và mask các thông tin bí mật với nhiều chiến lược:
  - *Giữ phần đầu & cuối* (ví dụ: `sk-proj-••••••••••••3aB8`, `j••••e@example.com`)
  - *Chỉ giữ 4 ký tự cuối* (ví dụ: `••••••••••••1234`, `•••• •••• 5678`)
  - *Mask toàn bộ* (ví dụ: `••••••••••••••••`)
- **Tùy chỉnh Regex Rules**: Thêm các quy tắc regex trong Settings để tự động mask các token nội bộ, URL bảo mật hoặc credentials đặc thù.
- **Bảo mật Touch ID / Mật khẩu**: Yêu cầu xác thực Touch ID, Apple Watch hoặc mật khẩu máy để mở khóa lịch sử clipboard hoặc hiển thị thông tin nhạy cảm đã bị mask.
- **Tự động xóa theo thời gian**: Tùy chọn tự động xóa các clip nhạy cảm chưa ghim sau 1 giờ, 24 giờ hoặc 7 ngày.
- **Exclude ứng dụng & Dữ liệu ẩn**: Tự động bỏ qua các app quản lý mật khẩu, dữ liệu gắn cờ transient/concealed và các app trong danh sách exclude do bạn thiết lập.
- **Mã hóa lưu trữ cục bộ**: Toàn bộ thumbnail ảnh và dữ liệu nhạy cảm trên ổ đĩa được mã hóa bằng thuật toán AES-GCM 256-bit với master key được bảo vệ bởi Keychain.

## Yêu cầu hệ thống

- **Hệ điều hành**: macOS 14.0 (Sonoma) trở lên (bao gồm macOS Sequoia)
- **Kiến trúc**: Universal binary hỗ trợ cả Apple Silicon (M1/M2/M3/M4) và Intel x86_64
- **Quyền hạn**: Cần cấp quyền Accessibility để ứng dụng có thể mô phỏng phím tắt dán trực tiếp vào các phần mềm khác

> [!NOTE]
> Khi mở ứng dụng lần đầu, macOS sẽ yêu cầu cấp quyền **Accessibility** tại *System Settings → Privacy & Security → Accessibility*. Quyền này là bắt buộc để LibrePaste có thể paste nội dung trực tiếp vào app đang hoạt động.

## Build từ mã nguồn

### Yêu cầu môi trường

- Xcode 15.0 trở lên
- Swift 5.9 trở lên
- macOS 14.0+ SDK

### Development Build

1. Clone repository:
   ```bash
   git clone https://github.com/bihv/LibrePaste.git
   cd LibrePaste
   ```

2. Mở project trong Xcode:
   ```bash
   open LibrePaste.xcodeproj
   ```

3. Build và chạy bằng Xcode (<kbd>⌘</kbd> + <kbd>R</kbd>), hoặc biên dịch bằng command line:
   ```bash
   xcodebuild -scheme LibrePaste -configuration Release build
   ```

### Đóng gói Release

Để đóng gói bản Universal `.app` hoàn chỉnh, tạo file ảnh đĩa DMG, file ZIP và mã hash SHA256:

```bash
chmod +x scripts/build_release.sh
./scripts/build_release.sh
```

Các file sau khi đóng gói sẽ được xuất ra thư mục `build/release/`.

## Cấu trúc dự án

```
LibrePaste/
├── Controllers/    # Quản lý window (SettingsWindowController, FloatingPanel)
├── Models/         # Data models (ClipRecord, DisplayMode, AppLanguage, AppAppearance, KeyboardShortcut)
├── Resources/      # Localization (Localizable.xcstrings) và assets
├── Services/       # Core services (DatabaseManager SQLite WAL, ClipboardWatcher, SecurityManager, CryptoService, SensitiveDataService, PasteQueueManager)
├── ViewModels/     # Observable stores (ClipboardStore, quản lý filter & search)
├── Views/          # Giao diện SwiftUI (ClipboardView, ClipCardView, ClipCompactRowView, QuickLook, Editor, HUD, Settings tabs)
└── Utilities/      # Helpers (LocalizationService, HotkeyManager, AppColorHelper, PasteSimulator, ThumbnailManager)
```
