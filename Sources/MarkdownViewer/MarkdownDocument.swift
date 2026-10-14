import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

struct MarkdownDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.markdown, .plainText]

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = decodeText(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

/// Decodes as UTF-8, falling back to Latin-1 so odd encodings still display.
func decodeText(_ data: Data) -> String {
    String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
}
