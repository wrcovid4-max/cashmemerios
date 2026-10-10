import SwiftUI

/// The chat screen: an empty state with example questions, the conversation, and a writing bar.
struct AskAIView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.managedObjectContext) private var context
    @StateObject private var ai = AskAIService()
    @StateObject private var speech = SpeechInput()
    @State private var draft = ""
    @State private var showingHistory = false

    private var canSend: Bool {
        !ai.busy && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if ai.messages.isEmpty {
                emptyState
            } else {
                conversation
            }
            inputBar
            Text(speech.listening
                 ? L10n.string(.aiListening, language: language)
                 : L10n.string(.aiDisclaimer, language: language)
                    .replacingOccurrences(of: "%@", with: "gemini-3.8-flash"))
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)
        }
        .background(Theme.background)
        .onAppear { speech.onText = { draft = $0 } }
        .onDisappear { speech.stop() }
        .navigationTitle(L10n.string(.aiTitle, language: language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                InfoButton(
                    title: L10n.string(.aiTitle, language: language),
                    message: L10n.string(.aiModelInfo, language: language)
                        .replacingOccurrences(of: "%@", with: "gemini-3.8-flash")
                )
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    ai.newChat()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel(L10n.string(.aiNewChat, language: language))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(Theme.brand)
                }
                .accessibilityLabel(L10n.string(.aiHistory, language: language))
            }
        }
        .sheet(isPresented: $showingHistory) {
            AskAIHistorySheet(
                chats: ai.chats,
                onOpen: { chat in
                    ai.open(chat)
                    showingHistory = false
                },
                onDelete: { ai.delete($0) }
            )
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.brandSoft)
                        .frame(width: 72, height: 72)
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.brand)
                }
                .padding(.top, 24)

                Text(L10n.string(.aiEmptyTitle, language: language))
                    .font(.title3.weight(.semibold))
                Text(L10n.string(.aiHint, language: language))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    suggestion(L10n.string(.aiSuggest1, language: language))
                    suggestion(L10n.string(.aiSuggest2, language: language))
                    suggestion(L10n.string(.aiSuggest3, language: language))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
        }
    }

    private func suggestion(_ text: String) -> some View {
        Button {
            ai.ask(text, failedText: L10n.string(.aiError, language: language), context: context)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.brand)
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardAlt.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(ai.messages) { message in
                        bubble(message)
                            .id(message.id)
                    }
                    if ai.busy {
                        Text(L10n.string(.aiThinking, language: language))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .id("thinking")
                    }
                }
                .padding(16)
            }
            .onChange(of: ai.messages.count) { _ in
                if let last = ai.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func bubble(_ message: AskAIService.Message) -> some View {
        HStack {
            if message.fromUser { Spacer(minLength: 40) }
            Text(message.text)
                .font(.body)
                .foregroundStyle(message.fromUser ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.fromUser ? Theme.brand : Theme.cardAlt,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            if !message.fromUser { Spacer(minLength: 40) }
        }
    }

    // MARK: - Writing bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(L10n.string(.aiPlaceholder, language: language), text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().stroke(Theme.separator.opacity(0.5), lineWidth: 1))

            Button {
                speech.toggle()
            } label: {
                Image(systemName: speech.listening ? "mic.fill" : "mic")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(speech.listening ? Color.red : Theme.brand)
                    .frame(width: 44, height: 44)
            }
            .disabled(ai.busy)
            .accessibilityLabel(L10n.string(.aiVoice, language: language))

            Button {
                ai.ask(draft, failedText: L10n.string(.aiError, language: language), context: context)
                draft = ""
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(canSend ? Theme.brand : Color.secondary.opacity(0.35), in: Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel(L10n.string(.aiSend, language: language))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

/// The recent chats, newest first. Tap one to reopen it; swipe a row to delete it.
private struct AskAIHistorySheet: View {
    @Environment(\.appLanguage) private var language
    let chats: [SavedChat]
    let onOpen: (SavedChat) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                if chats.isEmpty {
                    Text(L10n.string(.aiHistoryEmpty, language: language))
                        .foregroundStyle(Theme.textSecondary)
                }
                ForEach(chats) { chat in
                    Button {
                        onOpen(chat)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chat.title)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                            Text(chat.updatedAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .onDelete { offsets in
                    offsets.map { chats[$0].id }.forEach(onDelete)
                }
            }
            .navigationTitle(L10n.string(.aiHistory, language: language))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
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
