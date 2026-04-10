import SwiftUI

struct LovedOnesView: View {
    @ObservedObject var store: AppStore
    @Binding var selectedTab: TabItem
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var searchQuery = ""
    @State private var selectedPerson: LovedOne? = nil

    private var filteredLovedOnes: [LovedOne] {
        if searchQuery.isEmpty {
            return store.lovedOnes
        }
        return store.lovedOnes.filter { person in
            person.fullName.localizedCaseInsensitiveContains(searchQuery) ||
            person.relationship.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header with gradient accent
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("loved_ones_title".localized)
                            .font(.system(size: Theme.FontSize.h1, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)

                        if !store.lovedOnes.isEmpty {
                            Text("loved_ones_count".localized(with: store.lovedOnes.count))
                                .font(.system(size: Theme.FontSize.caption))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    Spacer()

                    // Add button
                    Button {
                        selectedTab = .add
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Theme.Gradients.primary)
                                .frame(width: 44, height: 44)
                                .shadow(color: Theme.Colors.primary.opacity(0.3), radius: 8, y: 4)

                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }

                if store.lovedOnes.isEmpty {
                    // Empty State
                    EmptyStateView(
                        icon: "person.fill.badge.plus",
                        title: "loved_ones_empty_title".localized,
                        message: "loved_ones_empty_subtitle".localized,
                        ctaLabel: "loved_ones_add_first".localized
                    ) {
                        selectedTab = .add
                    }
                    .padding(.top, 24)
                } else {
                    // Search with enhanced styling
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.primaryLight)
                                .frame(width: 36, height: 36)

                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Theme.Colors.primary)
                        }

                        TextField("loved_ones_search_placeholder".localized, text: $searchQuery)
                            .font(.system(size: Theme.FontSize.body))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.large)
                    .themeShadow(Theme.Shadows.small)

                    // List
                    VStack(spacing: 12) {
                        if filteredLovedOnes.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 32))
                                    .foregroundColor(Theme.Colors.textMuted)

                                Text("loved_ones_no_matches".localized(with: searchQuery))
                                    .font(.system(size: Theme.FontSize.body))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                        } else {
                            ForEach(filteredLovedOnes) { person in
                                PersonListItem(
                                    name: person.displayName,
                                    relationship: person.relationship
                                ) {
                                    selectedPerson = person
                                }
                            }
                        }
                    }
                }

            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 100)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background.ignoresSafeArea())
        .fullScreenCover(item: $selectedPerson) { person in
            // Fetch the latest version from store in case it was updated
            if let currentPerson = store.getLovedOne(byId: person.id) {
                LovedOneDetailView(store: store, lovedOne: currentPerson)
            }
        }
        .id(languageManager.currentLanguage) // Force refresh when language changes
    }
}

#Preview {
    LovedOnesView(store: AppStore.shared, selectedTab: .constant(.lovedOnes))
}
