import StoreKit
import SwiftUI

/// Public pages served by the Screen Scout server.
enum AppLinks {
    static var privacy: URL { Config.baseURL.appending(path: "privacy") }
    static var support: URL { Config.baseURL.appending(path: "support") }
}

struct AccountView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(HistoryStore.self) private var history
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @State private var joinCode = ""
    @State private var nameDraft = ""
    @State private var familyNameDraft = ""
    @State private var showEditName = false
    @State private var showEditFamilyName = false
    @State private var confirmLeave = false
    @State private var confirmDelete = false
    @State private var memberToRemove: Member?
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var toast: String?
    @State private var editingKid: Kid?
    @State private var addingKid = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if let me = auth.me {
                        profileCard(me.user)
                            .popIn()
                        usageCard(me.family.usage)
                            .popIn(delay: 0.04)
                        kidsCard(me.family)
                            .popIn(delay: 0.06)
                        familyCard(me.family)
                            .popIn(delay: 0.08)
                        inviteCard(me.family)
                            .popIn(delay: 0.12)
                        joinCard
                            .popIn(delay: 0.16)
                        aboutCard
                            .popIn(delay: 0.18)
                        accountActions(me.family)
                            .popIn(delay: 0.2)
                    } else {
                        ProgressView()
                            .padding(.top, 80)
                    }
                }
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
            .task { await auth.refreshMe() }
            .sheet(item: $editingKid) { kid in
                KidEditorSheet(kid: kid)
            }
            .sheet(isPresented: $addingKid) {
                KidEditorSheet(kid: nil)
            }
            .sensoryFeedback(trigger: toast) { _, message in message == nil ? nil : .success }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Theme.mint.gradient, in: Capsule())
                        .shadow(radius: 8, y: 4)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4), value: toast)
            .overlay {
                if busy {
                    ProgressView()
                        .controlSize(.large)
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            // Edit your name
            .alert("Your name", isPresented: $showEditName) {
                TextField("Name", text: $nameDraft)
                Button("Save") {
                    let name = nameDraft
                    run { try await auth.perform { try await APIClient.shared.updateName(name) } }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This is how you'll show up to your family.")
            }
            // Rename family
            .alert("Family name", isPresented: $showEditFamilyName) {
                TextField("Family name", text: $familyNameDraft)
                Button("Save") {
                    let name = familyNameDraft
                    run { try await auth.perform { try await APIClient.shared.renameFamily(name) } }
                }
                Button("Cancel", role: .cancel) {}
            }
            // Leave family
            .confirmationDialog("Leave this family?", isPresented: $confirmLeave, titleVisibility: .visible) {
                Button("Leave Family", role: .destructive) {
                    run {
                        try await auth.perform { try await APIClient.shared.leaveFamily() }
                        await history.refresh()
                        showToast("You've started your own family")
                    }
                }
            } message: {
                Text("You'll stop seeing this family's reviews. You can rejoin later with an invite code.")
            }
            // Remove a member
            .confirmationDialog(
                "Remove \(memberToRemove?.name ?? "this person")?",
                isPresented: Binding(get: { memberToRemove != nil }, set: { if !$0 { memberToRemove = nil } }),
                titleVisibility: .visible
            ) {
                Button("Remove from Family", role: .destructive) {
                    if let member = memberToRemove {
                        run { try await auth.perform { try await APIClient.shared.removeMember(member.id) } }
                    }
                }
            } message: {
                Text("They'll stop seeing your family's reviews.")
            }
            // Delete account
            .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) {
                    run {
                        try await auth.deleteAccount()
                        dismiss()
                    }
                }
            } message: {
                Text("This permanently deletes your Screen Scout account and signs you out. Reviews you shared stay with your family.")
            }
            .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: Cards

    private func profileCard(_ user: UserInfo) -> some View {
        HStack(spacing: 14) {
            Avatar(initials: user.initials, color: Theme.grape, size: 60)
            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                if let email = user.email, !email.contains("privaterelay") {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(Theme.softInk)
                } else {
                    Label("Signed in with Apple", systemImage: "apple.logo")
                        .font(.subheadline)
                        .foregroundStyle(Theme.softInk)
                }
            }
            Spacer(minLength: 0)
            Button {
                nameDraft = user.name ?? ""
                showEditName = true
            } label: {
                Image(systemName: "pencil")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.grape)
                    .frame(width: 40, height: 40)
                    .background(Theme.grape.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("Edit your name")
        }
        .cardStyle()
    }

    private func kidsCard(_ family: FamilyInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Kids", symbol: "figure.and.child.holdinghands", color: Theme.mint)
                Spacer(minLength: 0)
                Button {
                    addingKid = true
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Theme.mint.gradient, in: Circle())
                }
                .accessibilityLabel("Add a kid")
            }

            if family.kidList.isEmpty {
                Text("Add your kids so you can tap their name instead of picking an age. Everyone in your family sees them.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.softInk)
            } else {
                VStack(spacing: 10) {
                    ForEach(family.kidList) { kid in
                        Button {
                            editingKid = kid
                        } label: {
                            HStack(spacing: 12) {
                                Avatar(initials: kid.initial, color: kid.themeColor, size: 42)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kid.name)
                                        .font(.headline)
                                        .foregroundStyle(Theme.ink)
                                    Text(kid.age == 1 ? "1 year old" : "\(kid.age) years old")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.softInk)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.heavy))
                                    .foregroundStyle(Theme.softInk.opacity(0.6))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edit")
                    }
                }
            }
        }
        .cardStyle(tint: Theme.mint)
    }

    private var aboutCard: some View {
        VStack(spacing: 0) {
            Link(destination: AppLinks.privacy) {
                aboutRow("Privacy Policy", symbol: "hand.raised.fill", color: Theme.sky)
            }
            Divider().padding(.leading, 52)
            Link(destination: AppLinks.support) {
                aboutRow("Help & Support", symbol: "questionmark.circle.fill", color: Theme.grape)
            }
            Divider().padding(.leading, 52)
            Button {
                requestReview()
            } label: {
                aboutRow("Rate Screen Scout", symbol: "star.fill", color: Theme.sunshine)
            }
            Divider().padding(.leading, 52)
            HStack(spacing: 14) {
                Image(systemName: "info.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.softInk)
                    .frame(width: 28)
                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.softInk)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
        }
        .cardStyle(padding: 8)
    }

    private func aboutRow(_ title: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.heavy))
                .foregroundStyle(Theme.softInk.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .contentShape(Rectangle())
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func usageCard(_ usage: Usage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "This month", symbol: "chart.bar.fill", color: Theme.tangerine)
            if usage.isUnlimited {
                Text("Unlimited reviews. Scout away!")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(usage.remaining)")
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundStyle(usage.remaining == 0 ? Theme.coral : Theme.ink)
                    Text("new reviews left")
                        .font(.headline)
                        .foregroundStyle(Theme.softInk)
                }
                ProgressView(value: Double(min(usage.used, usage.limit)), total: Double(max(usage.limit, 1)))
                    .tint(usage.remaining == 0 ? Theme.coral : Theme.tangerine)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                Text("\(usage.used) of \(usage.limit) used by your family. Resets \(usage.resetDate.formatted(.dateTime.month(.wide).day())). Opening saved reviews is always free.")
                    .font(.footnote)
                    .foregroundStyle(Theme.softInk)
            }
        }
        .cardStyle(tint: Theme.tangerine)
    }

    private func familyCard(_ family: FamilyInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: family.name, symbol: "house.fill", color: Theme.coral)
                Spacer(minLength: 0)
                if family.isOwner {
                    Button {
                        familyNameDraft = family.name
                        showEditFamilyName = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.coral)
                            .frame(width: 34, height: 34)
                            .background(Theme.coral.opacity(0.12), in: Circle())
                    }
                    .accessibilityLabel("Rename family")
                }
            }

            VStack(spacing: 10) {
                ForEach(family.members) { member in
                    HStack(spacing: 12) {
                        Avatar(initials: member.initials, color: avatarColor(for: member), size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.isYou ? "\(member.name) (you)" : member.name)
                                .font(.headline)
                                .foregroundStyle(Theme.ink)
                            if member.isOwner {
                                Label("Organizer", systemImage: "crown.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color(hex: 0xD99A00))
                            }
                        }
                        Spacer(minLength: 0)
                        if family.isOwner && !member.isYou {
                            Menu {
                                Button("Remove from Family", systemImage: "person.badge.minus", role: .destructive) {
                                    memberToRemove = member
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.headline)
                                    .foregroundStyle(Theme.softInk)
                                    .frame(width: 36, height: 36)
                            }
                        }
                    }
                }
            }

            Text("\(family.members.count) of \(family.maxMembers) spots filled")
                .font(.footnote)
                .foregroundStyle(Theme.softInk)
        }
        .cardStyle(tint: Theme.coral)
    }

    private func inviteCard(_ family: FamilyInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Invite family", symbol: "envelope.open.fill", color: Theme.grape)
            Text("Share this code with your partner, grandparents, or anyone who helps with the kids.")
                .font(.subheadline)
                .foregroundStyle(Theme.softInk)

            Text(family.formattedInviteCode)
                .font(.system(size: 36, weight: .heavy, design: .rounded).monospaced())
                .foregroundStyle(Theme.grape)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.grape.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                }
                .textSelection(.enabled)

            ShareLink(item: inviteMessage(family)) {
                Label("Send Invite", systemImage: "square.and.arrow.up")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.grape.gradient, in: Capsule())
            }
            .buttonStyle(BouncyButtonStyle())

            if family.isOwner {
                Button {
                    run {
                        try await auth.perform { try await APIClient.shared.resetInviteCode() }
                        showToast("New invite code ready")
                    }
                } label: {
                    Label("Get a new code", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .tint(Theme.grape)
            }
        }
        .cardStyle(tint: Theme.grape)
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Join a family", symbol: "person.badge.plus", color: Theme.sky)
            Text("Got a code from someone? Enter it here. Your saved reviews come with you.")
                .font(.subheadline)
                .foregroundStyle(Theme.softInk)
            HStack(spacing: 10) {
                TextField("ABC-123", text: $joinCode)
                    .font(.title3.weight(.bold).monospaced())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Theme.card, in: Capsule())
                    .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: 1))
                Button {
                    let code = joinCode
                    run {
                        try await auth.perform { try await APIClient.shared.joinFamily(code: code) }
                        joinCode = ""
                        await history.refresh()
                        showToast("Welcome to the family!")
                    }
                } label: {
                    Text("Join")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 50)
                        .background(Theme.sky.gradient, in: Capsule())
                }
                .buttonStyle(BouncyButtonStyle())
                .disabled(joinCode.trimmingCharacters(in: .whitespaces).count < 6)
                .opacity(joinCode.trimmingCharacters(in: .whitespaces).count < 6 ? 0.5 : 1)
            }
        }
        .cardStyle(tint: Theme.sky)
    }

    private func accountActions(_ family: FamilyInfo) -> some View {
        VStack(spacing: 0) {
            if family.members.count > 1 {
                actionRow("Leave Family", symbol: "rectangle.portrait.and.arrow.right", color: Theme.tangerine) {
                    confirmLeave = true
                }
                Divider().padding(.leading, 52)
            }
            actionRow("Sign Out", symbol: "arrow.backward.circle.fill", color: Theme.softInk) {
                run {
                    await auth.signOut()
                    dismiss()
                }
            }
            Divider().padding(.leading, 52)
            actionRow("Delete Account", symbol: "trash.fill", color: Theme.coral) {
                confirmDelete = true
            }
        }
        .cardStyle(padding: 8)
    }

    private func actionRow(_ title: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(color)
                    .frame(width: 28)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(color == Theme.softInk ? Theme.ink : color)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private func inviteMessage(_ family: FamilyInfo) -> String {
        """
        Join \(family.name) on Screen Scout so we can check videos before the kids watch them!

        1. Get Screen Scout and sign in with Apple
        2. Tap your profile, then Join a family
        3. Enter this code: \(family.formattedInviteCode)
        """
    }

    private func avatarColor(for member: Member) -> Color {
        let palette = [Theme.grape, Theme.coral, Theme.sky, Theme.mint, Theme.tangerine, Theme.bubblegum]
        let index = member.id.unicodeScalars.reduce(0) { $0 + Int($1.value) } % palette.count
        return palette[index]
    }

    private func showToast(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if toast == text { toast = nil }
        }
    }

    /// Runs an account action with a spinner and friendly error handling.
    private func run(_ action: @escaping () async throws -> Void) {
        Task { @MainActor in
            busy = true
            defer { busy = false }
            do {
                try await action()
            } catch APIError.unauthorized {
                // Already signed out by the app; nothing to show.
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// A colorful circle with someone's initials.
struct Avatar: View {
    let initials: String
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 2))
            .accessibilityHidden(true)
    }
}
