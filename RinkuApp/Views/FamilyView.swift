import SwiftUI

/// Main view for managing family
struct FamilyView: View {
    @ObservedObject var familyService: FamilyService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showCreateFamily = false
    @State private var showJoinFamily = false
    @State private var showDeleteConfirmation = false
    @State private var showLeaveConfirmation = false
    @State private var memberToRemove: FamilyMember?
    
    var body: some View {
        NavigationView {
            Group {
                if let family = familyService.currentFamily {
                    // Show family details
                    familyDetailView(family)
                } else {
                    // Show options to create or join
                    noFamilyView
                }
            }
            .navigationTitle(familyService.currentFamily?.name ?? "My Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateFamily) {
            CreateFamilyView(familyService: familyService)
        }
        .sheet(isPresented: $showJoinFamily) {
            JoinFamilyView(familyService: familyService)
        }
    }
    
    // MARK: - No Family View
    
    private var noFamilyView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Illustration
            ZStack {
                Circle()
                    .fill(Theme.Colors.primaryLight)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.primary)
            }
            
            VStack(spacing: 12) {
                Text("No Family Yet")
                    .font(.system(size: Theme.FontSize.h2, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Create a family to share loved ones with caregivers, or join an existing family")
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                RinkuButton(
                    title: "Create Family",
                    icon: "plus.circle.fill",
                    variant: .primary,
                    size: .large
                ) {
                    showCreateFamily = true
                }
                
                RinkuButton(
                    title: "Join Family",
                    icon: "person.badge.plus",
                    variant: .secondary,
                    size: .large
                ) {
                    showJoinFamily = true
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            Spacer()
        }
        .background(Theme.Colors.background)
    }
    
    // MARK: - Family Detail View
    
    private func familyDetailView(_ family: Family) -> some View {
        List {
            // Invite Code Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Invite Code")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    HStack {
                        Text(family.inviteCode)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.Colors.primary)
                            .tracking(4)
                        
                        Spacer()
                        
                        Button {
                            UIPasteboard.general.string = family.inviteCode
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 20))
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }
                    
                    Text("Share this code with family members to let them join")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(.vertical, 8)
            }
            
            // Members Section
            Section(header: Text("Members (\(familyService.familyMembers.count))")) {
                ForEach(familyService.familyMembers) { member in
                    MemberRow(
                        member: member,
                        isCurrentUser: member.userId == AuthService.shared.currentUser?.id,
                        isCreator: family.createdBy == member.userId,
                        canRemove: familyService.isCreator && member.userId != AuthService.shared.currentUser?.id
                    ) {
                        memberToRemove = member
                    }
                }
            }
            
            // Actions Section
            Section {
                if familyService.isCreator {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Family")
                        }
                    }
                } else {
                    Button(role: .destructive) {
                        showLeaveConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Leave Family")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await familyService.loadMyFamily()
        }
        .alert("Delete Family?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    try? await familyService.deleteFamily()
                }
            }
        } message: {
            Text("This will remove all members from the family. Loved ones will become personal to whoever added them.")
        }
        .alert("Leave Family?", isPresented: $showLeaveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                Task {
                    try? await familyService.leaveFamily()
                }
            }
        } message: {
            Text("You will no longer see this family's loved ones. You can rejoin with the invite code.")
        }
        .alert("Remove Member?", isPresented: .init(
            get: { memberToRemove != nil },
            set: { if !$0 { memberToRemove = nil } }
        )) {
            Button("Cancel", role: .cancel) { memberToRemove = nil }
            Button("Remove", role: .destructive) {
                if let member = memberToRemove {
                    Task {
                        try? await familyService.removeMember(memberId: member.id)
                        memberToRemove = nil
                    }
                }
            }
        } message: {
            Text("Remove \(memberToRemove?.displayName ?? "this member") from the family?")
        }
    }
}

// MARK: - Member Row

struct MemberRow: View {
    let member: FamilyMember
    let isCurrentUser: Bool
    let isCreator: Bool
    let canRemove: Bool
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(member.role == .patient ? Theme.Colors.primaryLight : Theme.Colors.successLight)
                    .frame(width: 44, height: 44)
                
                Text(member.initials)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(member.role == .patient ? Theme.Colors.primary : Theme.Colors.success)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: member.role.icon)
                        .font(.system(size: 10))
                    Text(member.role.displayName)
                        .font(.system(size: Theme.FontSize.caption))
                    
                    if isCreator {
                        Text("• Creator")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
                .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
            
            if canRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.Colors.danger.opacity(0.7))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Family View

struct CreateFamilyView: View {
    @ObservedObject var familyService: FamilyService
    @Environment(\.dismiss) private var dismiss
    
    @State private var familyName = ""
    @State private var selectedRole: FamilyRole = .caregiver
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Family Name")) {
                    TextField("e.g., Grandma's Care Circle", text: $familyName)
                }
                
                Section(header: Text("Your Role"), footer: Text(selectedRole.description)) {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(FamilyRole.allCases, id: \.self) { role in
                            HStack {
                                Image(systemName: role.icon)
                                Text(role.displayName)
                            }
                            .tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(Theme.Colors.danger)
                    }
                }
                
                Section {
                    Button {
                        createFamily()
                    } label: {
                        HStack {
                            Spacer()
                            if isCreating {
                                ProgressView()
                            } else {
                                Text("Create Family")
                            }
                            Spacer()
                        }
                    }
                    .disabled(familyName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
            .navigationTitle("Create Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createFamily() {
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await familyService.createFamily(name: familyName.trimmingCharacters(in: .whitespaces), role: selectedRole)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}

// MARK: - Join Family View

struct JoinFamilyView: View {
    @ObservedObject var familyService: FamilyService
    @Environment(\.dismiss) private var dismiss
    
    @State private var inviteCode = ""
    @State private var selectedRole: FamilyRole = .patient
    @State private var isJoining = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Invite Code"), footer: Text("Enter the 6-character code shared by a family member")) {
                    TextField("e.g., ABC123", text: $inviteCode)
                        .textCase(.uppercase)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .onChange(of: inviteCode) { _, newValue in
                            // Limit to 6 characters and uppercase
                            inviteCode = String(newValue.uppercased().prefix(6))
                        }
                }
                
                Section(header: Text("Your Role"), footer: Text(selectedRole.description)) {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(FamilyRole.allCases, id: \.self) { role in
                            HStack {
                                Image(systemName: role.icon)
                                Text(role.displayName)
                            }
                            .tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(Theme.Colors.danger)
                    }
                }
                
                Section {
                    Button {
                        joinFamily()
                    } label: {
                        HStack {
                            Spacer()
                            if isJoining {
                                ProgressView()
                            } else {
                                Text("Join Family")
                            }
                            Spacer()
                        }
                    }
                    .disabled(inviteCode.count != 6 || isJoining)
                }
            }
            .navigationTitle("Join Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func joinFamily() {
        isJoining = true
        errorMessage = nil
        
        Task {
            do {
                try await familyService.joinFamily(inviteCode: inviteCode, role: selectedRole)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isJoining = false
        }
    }
}

#Preview("No Family") {
    FamilyView(familyService: FamilyService.shared)
}
