import CoreTransferable
import Foundation
import UniformTypeIdentifiers

enum CSVExporter {
    static func csv(for expenses: [Expense], currency: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        dateFormatter.timeZone = .current

        var lines = ["Date,Title,Amount,Currency,Category,Payment Method,Tags,Repeats,Notes"]
        for expense in expenses {
            let fields = [
                dateFormatter.string(from: expense.date),
                escape(expense.displayTitle),
                String(format: "%.2f", expense.amount),
                currency,
                escape(expense.category?.name ?? "Uncategorized"),
                escape(expense.paymentMethod.title),
                escape(expense.tags.joined(separator: "; ")),
                escape(expense.recurrence.title),
                escape(expense.notes),
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

struct CSVDocument: Transferable {
    let csv: String
    let fileName: String

    init(expenses: [Expense], currency: String, fileName: String = "Expenses") {
        self.csv = CSVExporter.csv(for: expenses, currency: currency)
        let stamp = Date.now.formatted(.iso8601.year().month().day())
        self.fileName = "\(fileName)-\(stamp).csv"
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { document in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(document.fileName)
            try document.csv.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
