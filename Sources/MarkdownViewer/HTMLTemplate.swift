import Foundation
import WebKit

enum HTMLTemplate {
    /// Loads a rendered document into `webView`.
    ///
    /// The page goes through a temp file rather than `loadHTMLString` because
    /// only file loads can grant WebKit read access to local images. A `<base>`
    /// tag makes relative paths resolve against the document's folder.
    @MainActor
    static func load(markdown: String, fileURL: URL?, into webView: WKWebView) {
        let title = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        let html = page(body: HTMLRenderer.render(markdown), title: title, baseURL: fileURL?.deletingLastPathComponent())
        let pageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkdownViewer-\(UUID().uuidString).html")
        do {
            try html.write(to: pageURL, atomically: true, encoding: .utf8)
            webView.loadFileURL(pageURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))
            // WebKit has read the file once the load commits; clean up shortly after.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                try? FileManager.default.removeItem(at: pageURL)
            }
        } catch {
            webView.loadHTMLString(html, baseURL: fileURL?.deletingLastPathComponent())
        }
    }

    static func page(body: String, title: String, baseURL: URL?) -> String {
        let base = baseURL.map { "<base href=\"\(escape($0.absoluteString))\">" } ?? ""
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        \(base)
        <meta name="color-scheme" content="light dark">
        <title>\(escape(title))</title>
        <style>\(css)</style>
        <script>
        function updateContent(html) {
            document.getElementById('content').innerHTML = html;
        }
        function scrollToAnchor(id) {
            const el = document.getElementById(id);
            if (el) el.scrollIntoView({ behavior: 'smooth' });
        }
        </script>
        </head>
        <body>
        <article id="content" class="markdown-body">
        \(body)
        </article>
        </body>
        </html>
        """
    }

    static let css = """
    :root {
        --fg: #1f2328;
        --fg-muted: #59636e;
        --bg: #ffffff;
        --bg-subtle: #f6f8fa;
        --border: #d1d9e0;
        --border-muted: #d1d9e0b3;
        --link: #0969da;
        --code-bg: #818b981f;
        --mark: #fff8c5;
    }
    @media (prefers-color-scheme: dark) {
        :root {
            --fg: #e6edf3;
            --fg-muted: #9198a1;
            --bg: #0d1117;
            --bg-subtle: #151b23;
            --border: #3d444d;
            --border-muted: #3d444db3;
            --link: #4493f8;
            --code-bg: #656c7633;
            --mark: #bb800926;
        }
    }
    @media print {
        :root {
            --fg: #1f2328;
            --fg-muted: #59636e;
            --bg: #ffffff;
            --bg-subtle: #f6f8fa;
            --border: #d1d9e0;
            --border-muted: #d1d9e0b3;
            --link: #0969da;
            --code-bg: #818b981f;
            --mark: #fff8c5;
        }
    }

    html { background: var(--bg); }
    body {
        margin: 0;
        color: var(--fg);
        background: var(--bg);
        font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
        -webkit-font-smoothing: antialiased;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
        word-wrap: break-word;
    }
    .markdown-body {
        max-width: 860px;
        margin: 0 auto;
        padding: 40px 48px 80px;
    }
    .markdown-body > :first-child { margin-top: 0 !important; }

    h1, h2, h3, h4, h5, h6 {
        margin: 1.5em 0 0.6em;
        font-weight: 600;
        line-height: 1.25;
    }
    h1 { font-size: 2em; padding-bottom: .3em; border-bottom: 1px solid var(--border-muted); }
    h2 { font-size: 1.5em; padding-bottom: .3em; border-bottom: 1px solid var(--border-muted); }
    h3 { font-size: 1.25em; }
    h4 { font-size: 1em; }
    h5 { font-size: .875em; }
    h6 { font-size: .85em; color: var(--fg-muted); }

    p, blockquote, ul, ol, dl, table, pre, details { margin: 0 0 16px; }

    a { color: var(--link); text-decoration: none; }
    a:hover { text-decoration: underline; }

    hr {
        height: .25em;
        margin: 24px 0;
        padding: 0;
        border: 0;
        background: var(--border);
    }

    blockquote {
        margin-left: 0;
        padding: 0 1em;
        color: var(--fg-muted);
        border-left: .25em solid var(--border);
    }
    blockquote > :last-child { margin-bottom: 0; }

    ul, ol { padding-left: 2em; }
    li + li { margin-top: .25em; }
    li > ul, li > ol { margin-top: .25em; margin-bottom: 0; }
    li > p { margin-top: 16px; }
    ul.task-list { list-style: none; padding-left: 1.2em; }
    .task-list-item input {
        appearance: none;
        position: relative;
        width: 1em;
        height: 1em;
        margin: 0 .4em 0 -1.4em;
        vertical-align: -.15em;
        border: 1.5px solid var(--fg-muted);
        border-radius: 4px;
    }
    .task-list-item input:checked { background: var(--link); border-color: var(--link); }
    .task-list-item input:checked::after {
        content: "";
        position: absolute;
        left: .28em;
        top: .08em;
        width: .25em;
        height: .5em;
        border: solid #fff;
        border-width: 0 2px 2px 0;
        transform: rotate(45deg);
    }

    code, pre {
        font-family: ui-monospace, "SF Mono", SFMono-Regular, Menlo, monospace;
        font-size: 85%;
    }
    code {
        padding: .2em .4em;
        border-radius: 6px;
        background: var(--code-bg);
    }
    pre {
        padding: 16px;
        overflow: auto;
        line-height: 1.45;
        border-radius: 6px;
        background: var(--bg-subtle);
    }
    pre code {
        padding: 0;
        font-size: 100%;
        background: transparent;
        white-space: pre;
    }

    table {
        display: block;
        width: max-content;
        max-width: 100%;
        overflow: auto;
        border-spacing: 0;
        border-collapse: collapse;
    }
    th, td { padding: 6px 13px; border: 1px solid var(--border); }
    th { font-weight: 600; }
    tr { background: var(--bg); border-top: 1px solid var(--border-muted); }
    tr:nth-child(2n) { background: var(--bg-subtle); }

    img { max-width: 100%; box-sizing: content-box; }
    mark { background: var(--mark); color: inherit; }
    kbd {
        display: inline-block;
        padding: 3px 5px;
        font: 11px ui-monospace, Menlo, monospace;
        line-height: 10px;
        border: 1px solid var(--border);
        border-bottom-width: 2px;
        border-radius: 6px;
        background: var(--bg-subtle);
    }

    @media print {
        .markdown-body { max-width: none; padding: 0; }
        pre, blockquote, table, img, tr, li { break-inside: avoid; }
        h1, h2, h3, h4, h5, h6 { break-after: avoid; }
        pre { white-space: pre-wrap; }
        pre code { white-space: pre-wrap; }
        table { display: table; width: auto; }
    }
    """
}
