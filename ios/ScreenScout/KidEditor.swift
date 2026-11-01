import SwiftUI

/// Add or edit a kid profile. Pass nil to add a new one.
struct KidEditorSheet: View {
    let kid: Kid?

    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var age = 5
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    @State private var saved = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Avatar(
                            initials: trimmedName.first.map { String($0).uppercased() } ?? "?",
                            color: kid?.themeColor ?? Theme.mint,
                            size: 48
                        )
                        TextField("First name", text: $name)
                            .font(.title3.weight(.semibold))
                            .textContentType(.givenName)
                            .submitLabel(.done)
                    }
                } header: {
                    Text("Name")
                }

                Section {
                    Picker("Age", selection: $age) {
                        ForEach(1...17, id: \.self) { value in
                            Text(value == 1 ? "1 year old" : "\(value) years old").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                } header: {
                    Text("Age")
                } footer: {
                    Text("Ages go up on their own each year.")
                }

                if let kid {
                    Section {
                        Button("Remove \(kid.name)", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.coral)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(kid == nil ? "Add a Kid" : "Edit Kid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .bold()
                            .disabled(trimmedName.isEmpty)
                    }
                }
            }
            .onAppear {
                if let kid {
                    name = kid.name
                    age = min(max(kid.age, 1), 17)
                }
            }
            .confirmationDialog(
                "Remove \(kid?.name ?? "this kid")?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) { remove() }
            } message: {
                Text("Their past reviews stay in your family's list.")
            }
            .sensoryFeedback(.success, trigger: saved)
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let newName = trimmedName
        let newAge = age
        Task { @MainActor in
            busy = true
            defer { busy = false }
            do {
                if let kid {
                    try await auth.perform { try await APIClient.shared.updateKid(kid.id, name: newName, age: newAge) }
                } else {
                    try await auth.perform { try await APIClient.shared.addKid(name: newName, age: newAge) }
                }
                saved = true
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func remove() {
        guard let kid else { return }
        Task { @MainActor in
            busy = true
            defer { busy = false }
            do {
                try await auth.perform { try await APIClient.shared.deleteKid(kid.id) }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
