import Foundation
import Markdown

/// Converts a Markdown AST into HTML.
///
/// swift-markdown ships an `HTMLFormatter`, but it doesn't escape text or code,
/// drops HTML blocks and flattens heading content, so we render ourselves.
struct HTMLRenderer: MarkupWalker {
    private(set) var result = ""
    private var tableAlignments: [Table.ColumnAlignment?] = []
    private var inTableHead = false
    private var column = 0
    private var usedSlugs: [String: Int] = [:]

    static func render(_ markdown: String) -> String {
        let document = Document(parsing: markdown)
        var renderer = HTMLRenderer()
        renderer.visit(document)
        return renderer.result
    }

    // MARK: Blocks

    mutating func visitBlockQuote(_ node: BlockQuote) {
        result += "<blockquote>\n"
        descendInto(node)
        result += "</blockquote>\n"
    }

    mutating func visitCodeBlock(_ node: CodeBlock) {
        let lang = node.language.flatMap { $0.isEmpty ? nil : $0 }
        let attr = lang.map { " class=\"language-\(escape($0))\"" } ?? ""
        result += "<pre><code\(attr)>\(escape(node.code))</code></pre>\n"
    }

    mutating func visitHeading(_ node: Heading) {
        let id = slug(for: node.plainText)
        result += "<h\(node.level) id=\"\(id)\">"
        descendInto(node)
        result += "</h\(node.level)>\n"
    }

    mutating func visitThematicBreak(_ node: ThematicBreak) {
        result += "<hr>\n"
    }

    mutating func visitHTMLBlock(_ node: HTMLBlock) {
        result += node.rawHTML
    }

    mutating func visitParagraph(_ node: Paragraph) {
        // Tight list items render their paragraphs without <p> wrappers.
        let tight = (node.parent as? ListItem).map { item in
            (item.parent as? ListItemContainer).map(isTight) ?? false
        } ?? false
        if !tight { result += "<p>" }
        descendInto(node)
        result += tight ? "\n" : "</p>\n"
    }

    mutating func visitOrderedList(_ node: OrderedList) {
        let start = node.startIndex == 1 ? "" : " start=\"\(node.startIndex)\""
        result += "<ol\(start)>\n"
        descendInto(node)
        result += "</ol>\n"
    }

    mutating func visitUnorderedList(_ node: UnorderedList) {
        let isTaskList = node.listItems.contains { $0.checkbox != nil }
        result += isTaskList ? "<ul class=\"task-list\">\n" : "<ul>\n"
        descendInto(node)
        result += "</ul>\n"
    }

    mutating func visitListItem(_ node: ListItem) {
        if let checkbox = node.checkbox {
            let checked = checkbox == .checked ? " checked" : ""
            result += "<li class=\"task-list-item\"><input type=\"checkbox\" disabled\(checked)> "
        } else {
            result += "<li>"
        }
        descendInto(node)
        result += "</li>\n"
    }

    mutating func visitTable(_ node: Table) {
        tableAlignments = node.columnAlignments
        result += "<table>\n"
        descendInto(node)
        result += "</table>\n"
    }

    mutating func visitTableHead(_ node: Table.Head) {
        inTableHead = true
        column = 0
        result += "<thead>\n<tr>\n"
        descendInto(node)
        result += "</tr>\n</thead>\n"
        inTableHead = false
    }

    mutating func visitTableBody(_ node: Table.Body) {
        guard !node.isEmpty else { return }
        result += "<tbody>\n"
        descendInto(node)
        result += "</tbody>\n"
    }

    mutating func visitTableRow(_ node: Table.Row) {
        column = 0
        result += "<tr>\n"
        descendInto(node)
        result += "</tr>\n"
    }

    mutating func visitTableCell(_ node: Table.Cell) {
        let tag = inTableHead ? "th" : "td"
        var attrs = ""
        if column < tableAlignments.count, let alignment = tableAlignments[column] {
            switch alignment {
            case .left: attrs += " style=\"text-align:left\""
            case .center: attrs += " style=\"text-align:center\""
            case .right: attrs += " style=\"text-align:right\""
            }
        }
        if node.colspan > 1 { attrs += " colspan=\"\(node.colspan)\"" }
        if node.rowspan > 1 { attrs += " rowspan=\"\(node.rowspan)\"" }
        column += Int(max(node.colspan, 1))
        // Cells covered by a span are emitted with colspan/rowspan 0; skip them.
        guard node.colspan > 0, node.rowspan > 0 else { return }
        result += "<\(tag)\(attrs)>"
        descendInto(node)
        result += "</\(tag)>\n"
    }

    // MARK: Inlines

    mutating func visitText(_ node: Markdown.Text) {
        if isInsideLink(node) {
            result += escape(node.string)
        } else {
            result += autolinked(node.string)
        }
    }

    mutating func visitInlineCode(_ node: InlineCode) {
        result += "<code>\(escape(node.code))</code>"
    }

    mutating func visitEmphasis(_ node: Emphasis) { wrap("em", node) }
    mutating func visitStrong(_ node: Strong) { wrap("strong", node) }
    mutating func visitStrikethrough(_ node: Strikethrough) { wrap("del", node) }

    mutating func visitInlineHTML(_ node: InlineHTML) {
        result += node.rawHTML
    }

    mutating func visitLineBreak(_ node: LineBreak) {
        result += "<br>\n"
    }

    mutating func visitSoftBreak(_ node: SoftBreak) {
        result += "\n"
    }

    mutating func visitLink(_ node: Link) {
        result += "<a href=\"\(escape(node.destination ?? ""))\""
        if let title = node.title, !title.isEmpty { result += " title=\"\(escape(title))\"" }
        result += ">"
        descendInto(node)
        result += "</a>"
    }

    mutating func visitImage(_ node: Image) {
        result += "<img src=\"\(escape(node.source ?? ""))\" alt=\"\(escape(node.plainText))\""
        if let title = node.title, !title.isEmpty { result += " title=\"\(escape(title))\"" }
        result += ">"
    }

    // MARK: Helpers

    private static let linkDetector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    private func isInsideLink(_ node: Markup) -> Bool {
        var parent = node.parent
        while let current = parent {
            if current is Link { return true }
            parent = current.parent
        }
        return false
    }

    /// GFM-style autolinks for bare `http(s)://` and `www.` URLs.
    private func autolinked(_ text: String) -> String {
        guard text.contains("://") || text.contains("www.") else { return escape(text) }
        var out = ""
        var cursor = text.startIndex
        let matches = Self.linkDetector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let range = Range(match.range, in: text), let url = match.url else { continue }
            let literal = text[range].lowercased()
            guard literal.hasPrefix("http://") || literal.hasPrefix("https://") || literal.hasPrefix("www.") else { continue }
            out += escape(String(text[cursor..<range.lowerBound]))
            out += "<a href=\"\(escape(url.absoluteString))\">\(escape(String(text[range])))</a>"
            cursor = range.upperBound
        }
        out += escape(String(text[cursor...]))
        return out
    }

    private mutating func wrap(_ tag: String, _ node: Markup) {
        result += "<\(tag)>"
        descendInto(node)
        result += "</\(tag)>"
    }

    /// CommonMark: a list is loose if items are separated by blank lines, or an
    /// item has blank lines between its direct children. cmark doesn't expose its
    /// tight flag, so check the source ranges. Item ranges can swallow trailing
    /// blank lines, so measure from each item's last child instead.
    private func isTight(_ list: ListItemContainer) -> Bool {
        var previousEnd: Int?
        for item in list.listItems {
            guard let start = item.range?.lowerBound.line else { return true }
            if let end = previousEnd, start - end > 1 { return false }
            var childEnd: Int?
            for child in item.children {
                guard let range = child.range else { continue }
                if let end = childEnd, range.lowerBound.line - end > 1 { return false }
                childEnd = range.upperBound.line
            }
            previousEnd = childEnd ?? start
        }
        return true
    }

    /// GitHub-style anchor ids so `[link](#some-heading)` works.
    private mutating func slug(for text: String) -> String {
        let base = text.lowercased()
            .map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? String($0) : ($0 == " " ? "-" : "") }
            .joined()
        let count = usedSlugs[base, default: 0]
        usedSlugs[base] = count + 1
        return escape(count == 0 ? base : "\(base)-\(count)")
    }
}

func escape(_ string: String) -> String {
    var out = ""
    out.reserveCapacity(string.utf8.count)
    for ch in string {
        switch ch {
        case "&": out += "&amp;"
        case "<": out += "&lt;"
        case ">": out += "&gt;"
        case "\"": out += "&quot;"
        default: out.append(ch)
        }
    }
    return out
}
