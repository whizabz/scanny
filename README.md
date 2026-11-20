# Scanny

A very simple document scanner for iPhone and iPad. Open it, scan, share. Nothing is saved.

- Scans with Apple's built-in document scanner (VisionKit): auto-detect pages, crop, filters.
- Review pages: rotate, filter, perspective crop, delete.
- Share as a single PDF or as images through the system share sheet.
- Editable file name with a configurable template (prefix, date/time order and format).
- Optional: open the scanner at launch, apply a default filter, clear an old scan after time away.
- No history, no accounts, no network. Scans live in memory and a temporary export folder.

Built with SwiftUI and the iOS 26 Liquid Glass components.

## Build

Requires Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
echo "DEVELOPMENT_TEAM = YOUR_TEAM_ID" > Config/Local.xcconfig
xcodegen generate
open Scanny.xcodeproj
```

The simulator has no camera, so scanning needs a real device. In debug simulator builds, a
"Load Sample Pages" button on the start screen lets you try the review screen.

## License

MIT. See [LICENSE](LICENSE).
