import Foundation
import CoreData

/// One message as it is saved on the device.
struct StoredMessage: Codable, Equatable {
    let fromUser: Bool
    let text: String
}

/// One saved conversation. Kept only on this device, the latest 20.
struct SavedChat: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let updatedAt: Date
    let messages: [StoredMessage]
    /// The conversation as Gemini sees it, so a reopened chat carries on in context.
    let gemini: String
}

/// Ask AI: Gemini answers a question, calling read-only tools that read the app's data.
@MainActor
final class AskAIService: ObservableObject {
    struct Message: Identifiable {
        let id = UUID()
        let fromUser: Bool
        let text: String
    }

    @Published private(set) var messages: [Message] = []
    @Published private(set) var busy = false
    @Published private(set) var chats: [SavedChat] = []

    /// The conversation as Gemini sees it. Saved with the chat.
    private var history: [[String: Any]] = []
    private var currentID = UUID().uuidString
    private let exchange = ExchangeRateService()

    private static let storageKey = "ai_chat_history"
    private static let limit = 20

    private static let systemPrompt =
        "You are the assistant inside Cash Memer, a receipt app. Answer questions about the " +
        "user's receipts and exchange rates by calling the tools; never invent figures. " +
        "Dates are yyyy-MM-dd. Keep answers short and clear."

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() {
        chats = Self.loadChats()
    }

    func ask(_ question: String, failedText: String, context: NSManagedObjectContext) {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy else { return }
        messages.append(Message(fromUser: true, text: text))
        history.append(["role": "user", "parts": [["text": text]]])
        busy = true
        Task {
            let reply = await runConversation(failedText: failedText, context: context)
            messages.append(Message(fromUser: false, text: reply))
            busy = false
            persist()
        }
    }

    /// Starts an empty conversation. The current one stays in the history.
    func newChat() {
        guard !busy else { return }
        currentID = UUID().uuidString
        history = []
        messages = []
    }

    /// Reopens a saved conversation, with its context.
    func open(_ chat: SavedChat) {
        guard !busy else { return }
        currentID = chat.id
        history = Self.decodeHistory(chat.gemini)
        messages = chat.messages.map { Message(fromUser: $0.fromUser, text: $0.text) }
    }

    func delete(_ id: String) {
        chats.removeAll { $0.id == id }
        Self.saveChats(chats)
        if id == currentID { newChat() }
    }

    private func persist() {
        let first = messages.first(where: { $0.fromUser })?.text ?? ""
        let title = String(first.prefix(60))
        let chat = SavedChat(
            id: currentID,
            title: title.isEmpty ? "Untitled chat" : title,
            updatedAt: Date(),
            messages: messages.map { StoredMessage(fromUser: $0.fromUser, text: $0.text) },
            gemini: Self.encodeHistory(history)
        )
        chats = Array(([chat] + chats.filter { $0.id != currentID }).prefix(Self.limit))
        Self.saveChats(chats)
    }

    private static func loadChats() -> [SavedChat] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SavedChat].self, from: data) else { return [] }
        return decoded
    }

    private static func saveChats(_ chats: [SavedChat]) {
        if let data = try? JSONEncoder().encode(chats) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private static func encodeHistory(_ history: [[String: Any]]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: history) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private static func decodeHistory(_ text: String) -> [[String: Any]] {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return object
    }

    private func runConversation(failedText: String, context: NSManagedObjectContext) async -> String {
        for _ in 0..<6 {
            let body: [String: Any] = [
                "system_instruction": ["parts": [["text": Self.systemPrompt]]],
                "contents": history,
                "tools": [["functionDeclarations": Self.declarations]],
                "generationConfig": ["temperature": 0.2, "maxOutputTokens": 1024],
            ]
            guard let reply = try? await GeminiChat.generate(body),
                  let candidates = reply["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else { return failedText }
            history.append(["role": "model", "parts": parts])

            let calls = parts.compactMap { $0["functionCall"] as? [String: Any] }
            if calls.isEmpty {
                let answer = parts.compactMap { $0["text"] as? String }.joined()
                return answer.isEmpty ? failedText : answer
            }
            var responses: [[String: Any]] = []
            for call in calls {
                let name = call["name"] as? String ?? ""
                let args = call["args"] as? [String: Any] ?? [:]
                let output = await runTool(name, args, context: context)
                responses.append(["functionResponse": ["name": name, "response": ["result": output]]])
            }
            history.append(["role": "user", "parts": responses])
        }
        return failedText
    }

    private func runTool(_ name: String, _ args: [String: Any], context: NSManagedObjectContext) async -> String {
        switch name {
        case "get_exchange_rates":
            return await ratesJSON()
        case "search_receipts":
            return json(matching(args, context: context).prefix(30).map { summary($0) })
        case "total_spending":
            return json(totals(matching(args, context: context)))
        default:
            return "{\"error\":\"unknown tool\"}"
        }
    }

    private func ratesJSON() async -> String {
        guard let snapshot = try? await exchange.rates(base: "PKR") else { return "[]" }
        let rows = snapshot.rates
            .sorted { $0.key < $1.key }
            .map { ["code": $0.key, "rate": NSDecimalNumber(decimal: $0.value).doubleValue] as [String: Any] }
        return json(rows)
    }

    private func matching(_ args: [String: Any], context: NSManagedObjectContext) -> [CDReceipt] {
        guard let all = try? context.fetch(CDReceipt.fetchRequest()) else { return [] }
        let calendar = Calendar.current
        let from = (args["from"] as? String).flatMap { Self.dayFormatter.date(from: $0) }
        let to = (args["to"] as? String).flatMap { Self.dayFormatter.date(from: $0) }
            .flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
        let store = (args["store"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let category = (args["category"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let payment = (args["payment"] as? String ?? "").trimmingCharacters(in: .whitespaces)

        return all.filter { r in
            let date: Date = r.createdAt ?? .distantPast
            if let from, date < from { return false }
            if let to, date >= to { return false }
            if !store.isEmpty, !(r.storeName ?? "").localizedCaseInsensitiveContains(store) { return false }
            if !category.isEmpty, !(r.categoryRaw ?? "").localizedCaseInsensitiveContains(category) { return false }
            if !payment.isEmpty, !(r.paymentMethodRaw ?? "").localizedCaseInsensitiveContains(payment) { return false }
            return true
        }
        .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    private func summary(_ r: CDReceipt) -> [String: Any] {
        let memo = MemoSnapshot(receipt: r)
        let date: Date = r.createdAt ?? .distantPast
        return [
            "date": Self.dayFormatter.string(from: date),
            "store": r.storeName ?? "",
            "total": CurrencyFormatter.string(memo.totals.grandTotal, currency: memo.currency),
            "category": r.categoryRaw ?? "",
            "payment": r.paymentMethodRaw ?? "",
        ]
    }

    private func totals(_ receipts: [CDReceipt]) -> [[String: Any]] {
        var sums: [String: Decimal] = [:]
        for r in receipts {
            let memo = MemoSnapshot(receipt: r)
            sums[memo.currency.code, default: 0] += memo.totals.grandTotal
        }
        return sums.sorted { $0.key < $1.key }.map { code, sum in
            let currency = Currency.allCases.first { $0.code == code } ?? .pkr
            return ["currency": code, "receipts": receipts.count,
                    "total": CurrencyFormatter.string(sum, currency: currency)]
        }
    }

    private func json(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else { return "[]" }
        return text
    }

    private static let declarations: [[String: Any]] = [
        [
            "name": "get_exchange_rates",
            "description": "The exchange rates the app holds, per 1 PKR.",
            "parameters": ["type": "OBJECT", "properties": [String: Any]()],
        ],
        [
            "name": "search_receipts",
            "description": "Find past receipts, newest first. All filters are optional.",
            "parameters": filters,
        ],
        [
            "name": "total_spending",
            "description": "Total spent on receipts matching the same optional filters, per currency.",
            "parameters": filters,
        ],
    ]

    private static let filters: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "from": ["type": "STRING", "description": "Start date, yyyy-MM-dd"],
            "to": ["type": "STRING", "description": "End date, yyyy-MM-dd"],
            "store": ["type": "STRING", "description": "Part of the store name"],
            "category": ["type": "STRING", "description": "Category, for example Groceries or Food"],
            "payment": ["type": "STRING", "description": "Payment method, for example Card or Cash"],
        ],
    ]
}
