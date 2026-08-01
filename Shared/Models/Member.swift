import Foundation
import SwiftData

/// An entry in the Members Directory — a saved customer that can be attached to a
/// receipt instead of retyping name, phone and email each time.
@Model
final class Member {
    @Attribute(.unique) var id: UUID
    var name: String
    var phone: String
    var email: String
    var notes: String
    var createdAt: Date
    @Attribute(.externalStorage) var avatarPNG: Data?

    init(
        id: UUID = UUID(),
        name: String,
        phone: String = "",
        email: String = "",
        notes: String = "",
        createdAt: Date = .now,
        avatarPNG: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.notes = notes
        self.createdAt = createdAt
        self.avatarPNG = avatarPNG
    }

    /// Initials shown when a member has no avatar image.
    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }
}

extension Member {
    /// CSV row for the directory export button.
    var csvRow: String {
        [name, phone, email, notes]
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            .joined(separator: ",")
    }

    static let csvHeader = "Name,Phone,Email,Notes"
}
