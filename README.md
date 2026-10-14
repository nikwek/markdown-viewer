# Markdown Viewer

A small native macOS app for reading Markdown files and exporting them to PDF.

- GitHub-flavored Markdown: tables, task lists, strikethrough, fenced code, autolinks, raw HTML
- GitHub-style rendering, with light and dark mode
- Live reload: edits saved in another editor show up immediately, and your scroll position is kept
- Relative images and links work. Links to other `.md` files open in the viewer, and web links open in your browser
- **Export as PDF** (⇧⌘E) produces paginated output. **Print** is ⌘P
- Zoom with ⌘+ / ⌘− / ⌘0

## Build

Requires macOS 14+ and the Xcode Command Line Tools (full Xcode isn't needed).

```sh
./build-app.sh
open "build/Markdown Viewer.app"
```

To install, drag `build/Markdown Viewer.app` into `/Applications`. Then right-click a `.md` file in Finder, choose **Open With → Markdown Viewer**, or set it as the default under **Get Info → Open with**.

## Command line

```sh
APP="build/Markdown Viewer.app/Contents/MacOS/MarkdownViewer"
"$APP" --export notes.md            # writes notes.pdf next to it
"$APP" --export notes.md out.pdf
"$APP" --html notes.md              # prints the rendered HTML body
```

## Layout

| File | Purpose |
|---|---|
| `MarkdownViewerApp.swift` | SwiftUI document app, menu commands |
| `DocumentController.swift` | Per-window state: rendering, live reload, zoom, print/export |
| `HTMLRenderer.swift` | Markdown AST (Apple's swift-markdown) → HTML |
| `HTMLTemplate.swift` | Page shell and stylesheet |
| `PDFExport.swift` | Paginated PDF via WebKit's print pipeline |
| `FileWatcher.swift` | Watches the open file, including atomic saves |
| `CommandLineExport.swift` | Headless `--export` mode |
| `Support/` | Info.plist and icon generator |
