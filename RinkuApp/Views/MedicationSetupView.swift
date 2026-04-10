import SwiftUI

// MARK: - MedicationSetupView

struct MedicationSetupView: View {
    @ObservedObject private var service = MedicationService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showAddSheet     = false
    @State private var justLoggedId: String? = nil  // brief green-flash feedback per row

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // Today's status summary card
                    MedicationStatusCard(service: service)

                    // Schedule section
                    VStack(spacing: 12) {
                        ProfileSectionHeader(title: "Schedule")

                        if service.entries.isEmpty {
                            MedicationEmptyState()
                        } else {
                            ForEach(service.entries) { entry in
                                MedicationEntryRow(
                                    entry: entry,
                                    isTakenToday: isTakenToday(entry),
                                    justLogged: justLoggedId == entry.id,
                                    onLogDose: { logDose(for: entry) }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        service.deleteEntry(id: entry.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    // Add button
                    RinkuButton(
                        title: "Add Medication",
                        icon: "plus",
                        variant: .primary,
                        size: .large
                    ) {
                        showAddSheet = true
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Medications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddMedicationSheet()
        }
    }

    // MARK: - Helpers

    private func isTakenToday(_ entry: MedicationEntry) -> Bool {
        service.todayLog().contains { $0.entryId == entry.id }
    }

    private func logDose(for entry: MedicationEntry) {
        service.logDose(confirmedBy: .caregiverManual, entryId: entry.id)
        withAnimation(.easeInOut(duration: 0.2)) { justLoggedId = entry.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { justLoggedId = nil }
        }
    }
}

// MARK: - Status Card

private struct MedicationStatusCard: View {
    @ObservedObject var service: MedicationService

    private var status: MedicationStatus { service.queryStatus() }

    private var cardColor: Color {
        switch status {
        case .taken:    return Theme.Colors.success
        case .notTaken: return Theme.Colors.warning
        case .unknown:  return Theme.Colors.primary
        }
    }

    private var iconName: String {
        switch status {
        case .taken:    return "checkmark.circle.fill"
        case .notTaken: return "exclamationmark.circle.fill"
        case .unknown:  return "clock.fill"
        }
    }

    private var headline: String {
        switch status {
        case .taken:    return "Taken Today"
        case .notTaken: return "Not Yet Taken"
        case .unknown:  return "Nothing Scheduled Yet"
        }
    }

    private var detail: String {
        switch status {
        case .taken(let at):
            return "Confirmed at \(formattedTime(at))"
        case .notTaken:
            if let next = service.entries.filter({ $0.applies(on: Calendar.current.component(.weekday, from: .now)) }).min(by: { $0.startMinuteOfDay < $1.startMinuteOfDay }) {
                return "\(next.name) was due at \(formattedScheduledTime(next))"
            }
            return "A scheduled dose has passed with no confirmation"
        case .unknown:
            return service.entries.isEmpty
                ? "Add a medication schedule below"
                : "No doses are scheduled for right now"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(cardColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: iconName)
                    .font(.system(size: 26))
                    .foregroundColor(cardColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(headline)
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(detail)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(cardColor.opacity(0.3), lineWidth: 1.5)
        )
        .themeShadow(Theme.Shadows.small)
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func formattedScheduledTime(_ entry: MedicationEntry) -> String {
        let h = entry.scheduledHour
        let m = entry.scheduledMinute
        let suffix = h < 12 ? "AM" : "PM"
        let displayH = h == 0 ? 12 : h > 12 ? h - 12 : h
        return String(format: "%d:%02d %@", displayH, m, suffix)
    }
}

// MARK: - Entry Row

private struct MedicationEntryRow: View {
    let entry: MedicationEntry
    let isTakenToday: Bool
    let justLogged: Bool
    let onLogDose: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(isTakenToday ? Theme.Colors.success.opacity(0.15) : Theme.Colors.primaryLight)
                    .frame(width: 46, height: 46)
                Image(systemName: isTakenToday ? "checkmark.circle.fill" : "pills.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isTakenToday ? Theme.Colors.success : Theme.Colors.primary)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(formattedTime)
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundColor(Theme.Colors.primary)

                    Text("·")
                        .foregroundColor(Theme.Colors.textMuted)

                    Text(weekdaySummary)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // Log Dose button
            Button(action: onLogDose) {
                HStack(spacing: 4) {
                    if justLogged {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Logged")
                            .font(.system(size: 12, weight: .semibold))
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("Log Dose")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .foregroundColor(justLogged ? Theme.Colors.success : Theme.Colors.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    (justLogged ? Theme.Colors.success : Theme.Colors.primary).opacity(0.1)
                )
                .cornerRadius(Theme.CornerRadius.pill)
                .overlay(
                    Capsule()
                        .stroke(
                            (justLogged ? Theme.Colors.success : Theme.Colors.primary).opacity(0.3),
                            lineWidth: 1
                        )
                )
            }
            .animation(.easeInOut(duration: 0.2), value: justLogged)
            .disabled(justLogged)
        }
        .padding(14)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(
                    isTakenToday ? Theme.Colors.success.opacity(0.3) : Theme.Colors.border,
                    lineWidth: 1
                )
        )
        .themeShadow(Theme.Shadows.small)
    }

    // MARK: Formatting helpers

    private var formattedTime: String {
        let h = entry.scheduledHour
        let m = entry.scheduledMinute
        let suffix = h < 12 ? "AM" : "PM"
        let displayH = h == 0 ? 12 : h > 12 ? h - 12 : h
        return String(format: "%d:%02d %@", displayH, m, suffix)
    }

    private var weekdaySummary: String {
        if entry.weekdays.isEmpty { return "Every day" }
        let sorted = entry.weekdays.sorted { $0.rawValue < $1.rawValue }
        // Common shortcuts
        if entry.weekdays.count == 5,
           !entry.weekdays.contains(.saturday),
           !entry.weekdays.contains(.sunday) {
            return "Weekdays"
        }
        if entry.weekdays.count == 2,
           entry.weekdays.contains(.saturday),
           entry.weekdays.contains(.sunday) {
            return "Weekends"
        }
        return sorted.map { $0.shortName }.joined(separator: ", ")
    }
}

// MARK: - Empty State

private struct MedicationEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primaryLight)
                    .frame(width: 72, height: 72)
                Image(systemName: "pills")
                    .font(.system(size: 32))
                    .foregroundColor(Theme.Colors.primary.opacity(0.6))
            }

            Text("No Medications Scheduled")
                .font(.system(size: Theme.FontSize.h3, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)

            Text("Tap \"Add Medication\" to set up the patient's\nmedication schedule and daily reminders.")
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.borderLight, lineWidth: 1)
        )
    }
}

// MARK: - Add Medication Sheet

struct AddMedicationSheet: View {
    @ObservedObject private var service = MedicationService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name        = ""
    @State private var scheduleDate: Date = {
        // Default to 8:00 AM today
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = 8; comps.minute = 0
        return Calendar.current.date(from: comps) ?? .now
    }()
    @State private var selectedDays: Set<Weekday> = []   // empty = every day
    @State private var nameError: String? = nil

    private var isAllDays: Bool { selectedDays.isEmpty }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {

                    // Medication name
                    RinkuTextField(
                        label: "Medication Name",
                        text: $name,
                        placeholder: "e.g. Blood pressure pill, morning vitamin",
                        errorText: nameError,
                        isRequired: true
                    )
                    .onChange(of: name) { _, _ in
                        if !(name.trimmingCharacters(in: .whitespaces).isEmpty) {
                            nameError = nil
                        }
                    }

                    // Time picker
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 4) {
                            Text("Scheduled Time")
                                .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                        }

                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.primaryLight)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Theme.Colors.primary)
                            }

                            DatePicker(
                                "",
                                selection: $scheduleDate,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .tint(Theme.Colors.primary)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                .stroke(Theme.Colors.borderLight, lineWidth: 1)
                        )
                    }

                    // Weekday selector
                    WeekdaySelector(selectedDays: $selectedDays)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Add Medication")
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
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            nameError = "Medication name is required"
            return
        }

        let comps  = Calendar.current.dateComponents([.hour, .minute], from: scheduleDate)
        let entry  = MedicationEntry(
            name:            trimmedName,
            scheduledHour:   comps.hour   ?? 8,
            scheduledMinute: comps.minute ?? 0,
            weekdays:        selectedDays
        )
        service.addEntry(entry)
        dismiss()
    }
}

// MARK: - Weekday Selector

private struct WeekdaySelector: View {
    @Binding var selectedDays: Set<Weekday>

    /// Display order: Mon through Sun (clinical week order)
    private let orderedDays: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Label
            HStack(spacing: 4) {
                Text("Days")
                    .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text(selectedDays.isEmpty ? "Every day" : "\(selectedDays.count) day\(selectedDays.count == 1 ? "" : "s")")
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundColor(Theme.Colors.primary)
            }

            // "Every day" shortcut pill
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { selectedDays = [] }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selectedDays.isEmpty ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundColor(selectedDays.isEmpty ? Theme.Colors.primary : Theme.Colors.textSecondary)
                    Text("Every day")
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundColor(selectedDays.isEmpty ? Theme.Colors.primary : Theme.Colors.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selectedDays.isEmpty ? Theme.Colors.primaryLight : Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.pill)
                .overlay(
                    Capsule().stroke(
                        selectedDays.isEmpty ? Theme.Colors.primary.opacity(0.4) : Theme.Colors.border,
                        lineWidth: 1
                    )
                )
            }

            // Day pills
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
                spacing: 8
            ) {
                ForEach(orderedDays, id: \.rawValue) { day in
                    let isOn = selectedDays.contains(day)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if isOn {
                                selectedDays.remove(day)
                            } else {
                                selectedDays.insert(day)
                            }
                        }
                    } label: {
                        Text(day.shortName)
                            .font(.system(size: 11, weight: isOn ? .bold : .medium))
                            .foregroundColor(isOn ? .white : Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                isOn
                                    ? Theme.Gradients.primary
                                    : LinearGradient(colors: [Theme.Colors.cardBackground], startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isOn ? Color.clear : Theme.Colors.border,
                                        lineWidth: 1
                                    )
                            )
                            .shadow(
                                color: isOn ? Theme.Colors.primary.opacity(0.3) : .clear,
                                radius: 4, y: 2
                            )
                    }
                }
            }

            // Helper text
            Text(selectedDays.isEmpty
                 ? "The medication will be scheduled every day."
                 : "Tap days to toggle. Deselect all to schedule every day.")
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(16)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.borderLight, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    MedicationSetupView()
}

#Preview("Add Sheet") {
    AddMedicationSheet()
}
