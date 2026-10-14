import SwiftUI

struct MarkdownViewerApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.document, fileURL: file.fileURL)
        }
        .defaultSize(width: 900, height: 1000)
        .commands {
            ViewerCommands()
        }
    }
}

struct ContentView: View {
    let document: MarkdownDocument
    let fileURL: URL?
    @StateObject private var controller = DocumentController()

    var body: some View {
        MarkdownWebView(controller: controller)
            .frame(minWidth: 480, minHeight: 360)
            .onAppear { controller.open(text: document.text, fileURL: fileURL) }
            .onChange(of: document.text) { controller.open(text: document.text, fileURL: fileURL) }
            .onChange(of: fileURL) { controller.open(text: document.text, fileURL: fileURL) }
            .focusedSceneObject(controller)
    }
}

struct ViewerCommands: Commands {
    @FocusedObject private var controller: DocumentController?

    var body: some Commands {
        CommandGroup(replacing: .printItem) {
            Button("Export as PDF…") { controller?.exportPDF() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(controller == nil)
            Button("Print…") { controller?.print() }
                .keyboardShortcut("p")
                .disabled(controller == nil)
        }
        CommandGroup(before: .toolbar) {
            Button("Actual Size") { controller?.resetZoom() }
                .keyboardShortcut("0")
            Button("Zoom In") { controller?.zoomIn() }
                .keyboardShortcut("+")
            Button("Zoom Out") { controller?.zoomOut() }
                .keyboardShortcut("-")
            Divider()
        }
    }
}
