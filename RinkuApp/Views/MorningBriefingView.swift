import SwiftUI

// MARK: - MorningBriefingView

struct MorningBriefingView: View {
    @ObservedObject private var service      = DailyBriefingService.shared
    @ObservedObject private var audioService = AudioService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showAddEvent       = false
    @State private var showAddGrounding   = false
    @State private var tomorrowMemoryText = ""
    @State private var memorySavedFlash   = false

    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
    }

    private var tomorrowMemory: PositiveMemory? {
        service.memoryForDate(tomorrow)
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // Replay card — top of page, primary action
                    ReplayBriefingCard(service: service, audioService: audioService)

                    // TODAY'S EVENTS ──────────────────────────────────────────
                    VStack(spacing: 12) {
                        HStack {
                            ProfileSectionHeader(title: "Today's Events")
                            Spacer()
                            Button {
                                showAddEvent = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("Add")
                                        .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                                }
                                .foregroundColor(Theme.Colors.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.primaryLight)
                                .cornerRadius(Theme.CornerRadius.pill)
                            }
                        }

                        let todayEvents = service.eventsForDate()
                        if todayEvents.isEmpty {
                            BriefingEmptyState(
                                icon: "calendar",
                                text: "No events scheduled for today.\nTap Add to include a visitor or appointment."
                            )
                        } else {
                            ForEach(todayEvents) { event in
                                EventRow(event: event) {
                                    service.deleteEvent(id: event.id)
                                }
                            }
                        }
                    }

                    // TONIGHT'S MEMORY NOTE ───────────────────────────────────
                    VStack(spacing: 12) {
                        ProfileSectionHeader(title: "Tonight's Memory Note")

                        // Context blurb
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.accentLight)
                                    .frame(width: 40, height: 40)
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Theme.Colors.accent)
                            }
                            Text("Write something positive that happened today — this will be read aloud tomorrow morning.")
                                .font(.system(size: Theme.FontSize.caption))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                .stroke(Theme.Colors.accentLight, lineWidth: 1)
                        )

                        // Text editor
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 4) {
                                Text("Memory for Tomorrow Morning")
                                    .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                            }

                            ZStack(alignment: .topLeading) {
                                if tomorrowMemoryText.isEmpty {
                                    Text("e.g. Yesterday you had lunch with Carlos and he made you laugh.")
                                        .font(.system(size: Theme.FontSize.body))
                                        .foregroundColor(Theme.Colors.textMuted)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                        .allowsHitTesting(false)
                                }

                                TextEditor(text: $tomorrowMemoryText)
                                    .font(.system(size: Theme.FontSize.body))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 100, maxHeight: 150)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                    .stroke(
                                        tomorrowMemoryText.isEmpty ? Theme.Colors.borderLight : Theme.Colors.primary.opacity(0.4),
                                        lineWidth: tomorrowMemoryText.isEmpty ? 1 : 2
                                    )
                            )
                        }

                        // Save memory button
                        RinkuButton(
                            title: memorySavedFlash ? "Saved for Tomorrow" : "Save Memory Note",
                            icon: memorySavedFlash ? "checkmark" : "moon.stars.fill",
                            variant: memorySavedFlash ? .secondary : .primary,
                            size: .medium,
                            isDisabled: tomorrowMemoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            saveMemoryNote()
                        }

                        // Show what was read this morning (if anything)
                        if let todayMemory = service.memoryForDate(.now) {
                            TodayMemoryCard(memory: todayMemory)
                        }
                    }

                    // GROUNDING DETAILS ────────────────────────────────────────
                    VStack(spacing: 12) {
                        HStack {
                            ProfileSectionHeader(title: "Grounding Details")
                            Spacer()
                            Button {
                                showAddGrounding = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("Add")
                                        .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                                }
                                .foregroundColor(Theme.Colors.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.primaryLight)
                                .cornerRadius(Theme.CornerRadius.pill)
                            }
                        }

                        // Helper text
                        Text("One detail plays each morning and rotates automatically. Add things that are comforting and unchanging.")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, 4)

                        if service.groundingDetails.isEmpty {
                            BriefingEmptyState(
                                icon: "house.fill",
                                text: "No grounding details yet.\nTap Add for things like \u{201C}Your cat Milo is home\u{201D} or \u{201C}You\u{2019}ve lived here for 30 years.\u{201D}"
                            )
                        } else {
                            ForEach(Array(service.groundingDetails.enumerated()), id: \.element.id) { index, detail in
                                GroundingDetailRow(detail: detail, index: index) {
                                    service.deleteGroundingDetail(id: detail.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Morning Briefing")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventSheet()
        }
        .sheet(isPresented: $showAddGrounding) {
            AddGroundingDetailSheet()
        }
        .onAppear {
            // Pre-fill the memory field if one already exists for tomorrow
            if let existing = tomorrowMemory {
                tomorrowMemoryText = existing.text
            }
        }
    }

    // MARK: - Actions

    private func saveMemoryNote() {
        let trimmed = tomorrowMemoryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let memory = PositiveMemory(text: trimmed, forDate: tomorrow)
        service.saveMemory(memory)

        withAnimation { memorySavedFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { memorySavedFlash = false }
        }
    }
}

// MARK: - Replay Briefing Card

private struct ReplayBriefingCard: View {
    @ObservedObject var service: DailyBriefingService
    @ObservedObject var audioService: AudioService

    private var playedToday: Bool {
        service.lastBriefingDate.map { Calendar.current.isDateInToday($0) } ?? false
    }

    private var statusLine: String {
        if audioService.isSpeaking { return "Playing now…" }
        if let date = service.lastBriefingDate, Calendar.current.isDateInToday(date) {
            let f = DateFormatter(); f.dateFormat = "h:mm a"
            return "Played this morning at \(f.string(from: date))"
        }
        if service.lastBriefingText != nil { return "Tap to replay" }
        return "Plays automatically when the glasses are first put on after 5 AM"
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Warm header strip ──────────────────────────────────────────
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.25))
                        .frame(width: 46, height: 46)
                    Image(systemName: audioService.isSpeaking ? "speaker.wave.3.fill" : "sunrise.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .symbolEffect(.variableColor.iterative.dimInactiveLayers,
                                      isActive: audioService.isSpeaking)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Morning Briefing")
                        .font(.system(size: Theme.FontSize.body, weight: .bold))
                        .foregroundColor(.white)
                    Text(statusLine)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)

                if playedToday && !audioService.isSpeaking {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(18)
            .background(Theme.Gradients.primary)

            // ── Briefing text preview ──────────────────────────────────────
            if let text = service.lastBriefingText {
                Text(text)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.borderLight.opacity(0.4))
            }

            // ── Replay button ──────────────────────────────────────────────
            Button {
                service.replayBriefing()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: audioService.isSpeaking ? "speaker.wave.2.fill" : "play.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                    Text(audioService.isSpeaking ? "Playing…" : "Play Briefing Again")
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                }
                .foregroundColor(service.lastBriefingText == nil ? Theme.Colors.textMuted : Theme.Colors.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    service.lastBriefingText == nil
                        ? Theme.Colors.cardBackground
                        : Theme.Colors.primaryLight
                )
            }
            .disabled(audioService.isSpeaking || service.lastBriefingText == nil)
            .animation(.easeInOut(duration: 0.2), value: audioService.isSpeaking)

            // ── Siri shortcut hint ─────────────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 11))
                Text("You can also say: \u{201C}Hey Siri, replay my morning briefing\u{201D}")
                    .font(.system(size: 11))
            }
            .foregroundColor(Theme.Colors.textMuted)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 1)
        )
        .themeShadow(Theme.Shadows.medium)
    }
}

// MARK: - Event Row

private struct EventRow: View {
    let event: DailyEvent
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Type icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: event.type.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(event.type.displayName)
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundColor(iconColor)

                    if let time = event.time {
                        Text("·")
                            .foregroundColor(Theme.Colors.textMuted)
                        Text(formattedTime(time))
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
        .themeShadow(Theme.Shadows.small)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var iconColor: Color {
        switch event.type {
        case .visitor:      return Theme.Colors.primary
        case .appointment:  return Theme.Colors.warning
        case .activity:     return Theme.Colors.success
        case .other:        return Theme.Colors.textSecondary
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

// MARK: - Today Memory Card (what was read this morning)

private struct TodayMemoryCard: View {
    let memory: PositiveMemory

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(Theme.Colors.success)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Read this morning")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.Colors.success)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(memory.text)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.Colors.success.opacity(0.06))
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.success.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Grounding Detail Row

private struct GroundingDetailRow: View {
    let detail: GroundingDetail
    let index: Int
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Rotation badge
            ZStack {
                Circle()
                    .fill(Theme.Colors.primaryLight)
                    .frame(width: 36, height: 36)
                Text("\(index + 1)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Gradients.primary)
            }

            Text(detail.text)
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
        .themeShadow(Theme.Shadows.small)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Shared Empty State

private struct BriefingEmptyState: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
            Text(text)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.borderLight, lineWidth: 1)
        )
    }
}

// MARK: - Add Event Sheet

struct AddEventSheet: View {
    @ObservedObject private var service = DailyBriefingService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var title        = ""
    @State private var selectedType: DailyEventType = .visitor
    @State private var hasTime      = false
    @State private var selectedTime: Date = {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = 10; comps.minute = 0
        return Calendar.current.date(from: comps) ?? .now
    }()
    @State private var titleError: String? = nil

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {

                    // Event type selector
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Event Type")
                            .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        HStack(spacing: 8) {
                            ForEach(DailyEventType.allCases, id: \.rawValue) { type in
                                EventTypePill(
                                    type: type,
                                    isSelected: selectedType == type
                                ) {
                                    selectedType = type
                                }
                            }
                        }
                    }

                    // Title
                    RinkuTextField(
                        label: "Description",
                        text: $title,
                        placeholder: placeholderForType,
                        errorText: titleError,
                        isRequired: true
                    )
                    .onChange(of: title) { _, _ in
                        if !title.trimmingCharacters(in: .whitespaces).isEmpty {
                            titleError = nil
                        }
                    }

                    // Optional time
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $hasTime) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.Colors.primaryLight)
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Theme.Colors.primary)
                                }
                                Text("Add a time")
                                    .font(.system(size: Theme.FontSize.body, weight: .medium))
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                        }
                        .tint(Theme.Colors.primary)
                        .padding(16)
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                .stroke(Theme.Colors.borderLight, lineWidth: 1)
                        )

                        if hasTime {
                            DatePicker(
                                "Time",
                                selection: $selectedTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .tint(Theme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                    .stroke(Theme.Colors.borderLight, lineWidth: 1)
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: hasTime)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
    }

    private var placeholderForType: String {
        switch selectedType {
        case .visitor:      return "e.g. Carlos is visiting"
        case .appointment:  return "e.g. Doctor's appointment at the clinic"
        case .activity:     return "e.g. Art class at the community center"
        case .other:        return "e.g. Package delivery expected"
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            titleError = "Please enter a description"
            return
        }

        let event = DailyEvent(
            title:   trimmed,
            time:    hasTime ? selectedTime : nil,
            type:    selectedType,
            forDate: .now
        )
        service.addEvent(event)
        dismiss()
    }
}

// MARK: - Event Type Pill

private struct EventTypePill: View {
    let type: DailyEventType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: type.iconName)
                    .font(.system(size: 16))
                Text(type.displayName)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Theme.Gradients.primary : LinearGradient(colors: [Theme.Colors.cardBackground], startPoint: .top, endPoint: .bottom))
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(isSelected ? Color.clear : Theme.Colors.border, lineWidth: 1)
            )
            .shadow(
                color: isSelected ? Theme.Colors.primary.opacity(0.3) : .clear,
                radius: 4, y: 2
            )
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Add Grounding Detail Sheet

struct AddGroundingDetailSheet: View {
    @ObservedObject private var service = DailyBriefingService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var text      = ""
    @State private var textError: String? = nil

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    RinkuTextField(
                        label: "Grounding Detail",
                        text: $text,
                        placeholder: "e.g. Your cat Milo is home.",
                        helperText: "A short, comforting fact. It will rotate with others each morning.",
                        errorText: textError,
                        isRequired: true
                    )
                    .onChange(of: text) { _, _ in
                        if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                            textError = nil
                        }
                    }

                    // Examples card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Examples")
                            .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        ForEach([
                            "Your cat Milo is home.",
                            "You've lived in this house for 30 years.",
                            "Your daughter Maria calls every Wednesday.",
                            "Your favorite chair is in the living room.",
                        ], id: \.self) { example in
                            Button {
                                text = example
                                textError = nil
                            } label: {
                                HStack {
                                    Text(example)
                                        .font(.system(size: Theme.FontSize.caption))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Theme.Colors.primary.opacity(0.6))
                                }
                                .padding(12)
                                .background(Theme.Colors.cardBackground)
                                .cornerRadius(Theme.CornerRadius.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                        .stroke(Theme.Colors.borderLight, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Add Grounding Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            textError = "Please enter a grounding detail"
            return
        }
        service.addGroundingDetail(GroundingDetail(text: trimmed))
        dismiss()
    }
}

// MARK: - Previews

#Preview("Morning Briefing") {
    MorningBriefingView()
}

#Preview("Add Event") {
    AddEventSheet()
}

#Preview("Add Grounding") {
    AddGroundingDetailSheet()
}
