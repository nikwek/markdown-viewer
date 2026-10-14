import AppKit
import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let controller: DocumentController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.setValue(false, forKey: "drawsBackground")
        controller.attach(webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let controller: DocumentController

        init(controller: DocumentController) {
            self.controller = controller
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            MainActor.assumeIsolated { controller.pageDidLoad() }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor action: WKNavigationAction,
            decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
        ) {
            guard action.navigationType == .linkActivated, let url = action.request.url else {
                return decisionHandler(.allow)
            }
            decisionHandler(.cancel)
            // `<base>` points at the document's folder, so in-page anchors arrive
            // as that folder (or the document itself) plus a fragment.
            let target = url.deletingFragment
            let isSamePage = target == webView.url?.deletingFragment
                || target.standardizedFileURL == controller.fileURL?.standardizedFileURL
                || target.standardizedFileURL == controller.fileURL?.deletingLastPathComponent().standardizedFileURL
            if let fragment = url.fragment, isSamePage {
                let id = (try? JSONEncoder().encode(fragment.removingPercentEncoding ?? fragment))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
                webView.evaluateJavaScript("scrollToAnchor(\(id))")
                return
            }
            if url.isFileURL, ["md", "markdown", "mdown", "mkd", "mkdn"].contains(url.pathExtension.lowercased()) {
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
            } else {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

private extension URL {
    var deletingFragment: URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        return components?.url ?? self
    }
}
