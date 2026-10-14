# Markdown Viewer Sample

A quick tour of what renders. **Bold**, *italic*, ~~strikethrough~~, `inline <code>`,
and a [link to the web](https://commonmark.org). Jump to [the table](#tables).

![App icon](icon.png)

## Lists

- Tight list item one
- Item two
  - Nested item
  - Another nested item
- Item three

1. First
2. Second
3. Third

### Task list

- [x] Render Markdown
- [x] Export to PDF
- [ ] Take over the world

## Code

```swift
struct Greeting {
    func say() -> String { "<hello & goodbye>" }
}
```

> Blockquotes work too.
>
> Across multiple paragraphs.

## Tables

| Feature        | Status | Notes                  |
|:---------------|:------:|-----------------------:|
| Headings       | ✅     | With anchor links      |
| Tables         | ✅     | With alignment         |
| Live reload    | ✅     | Keeps scroll position  |

---

<details>
<summary>Raw HTML blocks pass through</summary>

Hidden content.

</details>

Press <kbd>⇧</kbd><kbd>⌘</kbd><kbd>E</kbd> to export as PDF.
