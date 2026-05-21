import Foundation
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers

/// Exporta uma nota como PDF de página única (largura letter, altura variável).
/// Usa SwiftUI `ImageRenderer` + `CGContext` PDF.
enum NotePDFExporter {
    enum ExporterError: Error { case writeFailed }

    /// Roda no MainActor (ImageRenderer exige). Retorna URL em temp directory.
    @MainActor
    static func makePDF(
        title: String,
        body: String,
        tag: String,
        updatedAt: Date,
        wordCount: Int,
        fileName: String
    ) throws -> URL {
        let printable = NotePrintableView(
            title: title,
            bodyText: body,
            tag: tag,
            updatedAt: updatedAt,
            wordCount: wordCount
        )

        let renderer = ImageRenderer(content: printable)
        renderer.proposedSize = .init(width: 612, height: nil) // 8.5" portrait
        renderer.scale = 2.0

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)

        var didWrite = false
        renderer.render { size, drawClosure in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL) else { return }
            guard let pdfContext = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            pdfContext.beginPDFPage(nil)
            drawClosure(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
            didWrite = true
        }

        guard didWrite else { throw ExporterError.writeFailed }
        return url
    }
}

// MARK: - Printable view (offscreen, just to render)

/// View renderizada pra PDF. Não usa o Theme global (paperBackground etc)
/// pra forçar fundo branco e tinta escura — padrão "impressão".
private struct NotePrintableView: View {
    let title: String
    let bodyText: String      // não nomear "body" — colide com View protocol
    let tag: String
    let updatedAt: Date
    let wordCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title.isEmpty ? "Sem título" : title)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(.black)

            HStack(spacing: 8) {
                Text(tag.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                Text("·")
                Text("\(wordCount) palavras")
                Text("·")
                Text(updatedAt.formatted(.dateTime.day().month(.wide).year()))
            }
            .font(.system(size: 11, design: .serif))
            .foregroundStyle(.gray)

            Divider()
                .background(Color.gray.opacity(0.4))

            Text(bodyText)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(.black)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(48)
        .frame(width: 612, alignment: .topLeading)
        .background(Color.white)
    }
}

// MARK: - Transferable wrapper for ShareLink

/// Wrapper Transferable que evita acoplar @Model (Note) ao protocolo.
/// Carrega só o snapshot dos campos necessários.
struct NotePDFDocument: Transferable {
    let title: String
    let body: String
    let tag: String
    let updatedAt: Date
    let wordCount: Int
    let fileName: String

    init(note: Note) {
        self.title = note.title
        self.body = note.body
        self.tag = note.tag.rawValue
        self.updatedAt = note.updatedAt
        self.wordCount = note.wordCount
        let safe = note.displayTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.fileName = (safe.isEmpty ? "Nota" : safe) + ".pdf"
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { doc in
            let url = try await MainActor.run {
                try NotePDFExporter.makePDF(
                    title: doc.title,
                    body: doc.body,
                    tag: doc.tag,
                    updatedAt: doc.updatedAt,
                    wordCount: doc.wordCount,
                    fileName: doc.fileName
                )
            }
            return SentTransferredFile(url)
        }
        .suggestedFileName { $0.fileName }
    }
}
