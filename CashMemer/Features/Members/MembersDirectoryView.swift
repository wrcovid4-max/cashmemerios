import CoreData
import SwiftUI

struct MembersDirectoryView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(fetchRequest: CDMember.allRequest()) private var members: FetchedResults<CDMember>

    @State private var editing: CDMember?
    @State private var isCreating = false
    @State private var exportURL: URL?
    @State private var isSharing = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if members.isEmpty {
                EmptyStateView(
                    systemImage: "person.2",
                    titleKey: .noMembersYet,
                    messageKey: .noMembersHint
                )
            } else {
                List {
                    ForEach(members) { member in
                        MemberRow(member: member) { editing = member }
                            .listRowBackground(Theme.card)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Theme.background)
            }

            Button {
                isCreating = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 58, height: 58)
                    .background(Theme.brand, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Theme.brand.opacity(0.3), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .padding(Theme.Spacing.xl)
            .accessibilityLabel(L10n.string(.addMember, language: language))
        }
        .background(Theme.background)
        .navigationTitle(L10n.string(.membersDirectory, language: language))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: exportCSV) {
                    Image(systemName: "square.and.arrow.down")
                }
                .accessibilityLabel(L10n.string(.exportMembers, language: language))
                .disabled(members.isEmpty)
            }
        }
        .sheet(isPresented: $isCreating) {
            MemberEditorSheet(member: nil)
        }
        .sheet(item: $editing) { member in
            MemberEditorSheet(member: member)
        }
        .sheet(isPresented: $isSharing) {
            if let exportURL = exportURL { ShareSheet(items: [exportURL]) }
        }
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { members[$0] }.forEach(context.delete)
        try? context.save()
    }

    private func exportCSV() {
        let rows = [CDMember.csvHeader] + members.map(\.csvRow)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CashMemer-Members")
            .appendingPathExtension("csv")
        guard (try? rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)) != nil else { return }
        exportURL = url
        isSharing = true
    }
}

private struct MemberRow: View {
    @ObservedObject var member: CDMember
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            MemberAvatar(member: member)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.body.weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                if !member.phone.isEmpty {
                    Text(member.phone)
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Spacer(minLength: Theme.Spacing.s)

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct MemberAvatar: View {
    @ObservedObject var member: CDMember
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(Theme.brandSoft)
            if let data = member.avatarPNG, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else if member.initials.isEmpty {
                Image(systemName: "person.fill")
                    .foregroundColor(Theme.brandDeep)
            } else {
                Text(member.initials)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundColor(Theme.brandDeep)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Create/edit form for a directory entry.
struct MemberEditorSheet: View {
    let member: CDMember?

    @Environment(\.managedObjectContext) private var context
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField(L10n.string(.name, language: language), text: $name)
                TextField(L10n.string(.phone, language: language), text: $phone)
                    .keyboardType(.phonePad)
                TextField(L10n.string(.email, language: language), text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField(L10n.string(.notes, language: language), text: $notes, axis: .vertical)
            }
            .navigationTitle(L10n.string(member == nil ? .addMember : .editMember, language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.cancel, language: language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string(.save, language: language), action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let member = member else { return }
        name = member.name
        phone = member.phone
        email = member.email
        notes = member.notes
    }

    private func save() {
        let target = member ?? CDMember(context: context)
        if member == nil {
            target.id = UUID()
            target.createdAt = Date()
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.phone = phone
        target.email = email
        target.notes = notes
        try? context.save()
        dismiss()
    }
}

/// Picker presented from the New Receipt form's "Select Member" row.
struct MemberPickerSheet: View {
    let onSelect: (CDMember) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @FetchRequest(fetchRequest: CDMember.allRequest()) private var members: FetchedResults<CDMember>
    @State private var search = ""

    private var filtered: [CDMember] {
        guard !search.isEmpty else { return Array(members) }
        return members.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.phone.contains(search)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if members.isEmpty {
                    EmptyStateView(
                        systemImage: "person.2",
                        titleKey: .noMembersYet,
                        messageKey: .noMembersHint
                    )
                } else {
                    List(filtered) { member in
                        Button {
                            onSelect(member)
                            dismiss()
                        } label: {
                            HStack(spacing: Theme.Spacing.m) {
                                MemberAvatar(member: member, size: 38)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(member.name)
                                        .foregroundColor(Theme.textPrimary)
                                    if !member.phone.isEmpty {
                                        Text(member.phone)
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .searchable(text: $search)
                }
            }
            .navigationTitle(L10n.string(.selectMember, language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.cancel, language: language)) { dismiss() }
                }
            }
        }
    }
}
