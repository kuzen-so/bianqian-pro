# QuickNote 📝

A lightweight macOS menu-bar sticky notes app. Click the status bar icon to pop up a whiteboard for quick thoughts, or pin notes to the desktop for easy access.

## Features

- **Menu Bar Whiteboard**: Click the status bar icon to pop up a floating whiteboard and quickly capture ideas
- **Desktop Sticky Notes**: Convert any note to a desktop sticky note that floats above all Spaces
- **Colorful Themes**: 8 colors available to differentiate notes at a glance
- **Position Memory**: Sticky note positions and sizes are automatically saved and restored after restart
- **Data Persistence**: All notes are saved locally automatically, no worry about losing data
- **Minimal Interaction**: No Dock icon, pure menu bar app that doesn't disturb your workflow

## Project Structure

```
QuickNote/
├── Package.swift              # Swift Package configuration
├── README.md
├── build_app.sh               # Build script
└── Sources/QuickNote/
    ├── QuickNote.swift        # App entry point
    ├── AppDelegate.swift      # Status bar, Popover, event monitor
    ├── PopoverView.swift      # Whiteboard popover UI
    ├── StickyNoteWindow.swift # Desktop sticky note window
    ├── NoteModel.swift        # Data model
    └── NoteStore.swift        # Data storage
```

## Getting Started

### Development

```bash
cd QuickNote
swift run
```

The app launches in accessory mode with a ✏️ icon in the status bar.

### Build as .app

```bash
cd QuickNote
./build_app.sh
```

After building, `QuickNote.app` will be generated in the current directory. Drag it to `/Applications` to install.

## Usage

| Action | Description |
|--------|-------------|
| Click status bar icon | Open/close the whiteboard popover |
| Type content + click "Record" | Save to the whiteboard list |
| Type content + click "Create Sticky" | Create a desktop sticky note directly |
| Hover over a note → click 📌 | Convert an existing note to a desktop sticky |
| Hover over sticky title bar | Show close/edit/color buttons |
| Drag a sticky note | Freely adjust position |

## Tech Stack

- **Swift 5.9+**
- **SwiftUI** — UI building
- **AppKit** — Status bar, borderless windows, drag & drop
- **UserDefaults** — Local data persistence

## Requirements

- macOS 13.0+

## License

MIT
