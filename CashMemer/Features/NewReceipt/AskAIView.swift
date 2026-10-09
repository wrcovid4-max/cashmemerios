import SwiftUI

/// The chat screen: messages and a box to type a question in.
struct AskAIView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.managedObjectContext) private var context
    @StateObject private var ai = AskAIService()
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if ai.messages.isEmpty {
                        Text(L10n.string(.aiHint, language: language))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(ai.messages) { message in
                        bubble(message)
                    }
                    if ai.busy {
                        Text(L10n.string(.aiThinking, language: language))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding()
            }
            HStack {
                TextField(L10n.string(.aiPlaceholder, language: language), text: $draft)
                    .textFieldStyle(.roundedBorder)
                Button(L10n.string(.aiSend, language: language)) {
                    ai.ask(draft, failedText: L10n.string(.aiError, language: language), context: context)
                    draft = ""
                }
                .disabled(ai.busy || draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle(L10n.string(.aiTitle, language: language))
    }

    private func bubble(_ message: AskAIService.Message) -> some View {
        Text(message.text)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: message.fromUser ? .trailing : .leading)
            .background(message.fromUser ? Theme.brandSoft : Theme.cardAlt,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// The small circle AI button in the bottom-right corner. Opens the chat as a sheet.
struct AskAIButton: View {
    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Theme.brand, in: Circle())
                .shadow(radius: 3)
        }
        .sheet(isPresented: $showing) {
            NavigationStack {
                AskAIView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .cancel) {
                                showing = false
                            } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
        }
    }
}
