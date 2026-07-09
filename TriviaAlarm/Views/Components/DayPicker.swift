import SwiftUI

struct DayPicker: View {
    @Binding var selectedDays: Set<RepeatDay>

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RepeatDay.allCases) { day in
                Button {
                    toggle(day)
                } label: {
                    Text(day.shortName.prefix(1))
                        .font(.caption.weight(.black))
                        .frame(width: 38, height: 38)
                        .foregroundStyle(selectedDays.contains(day) ? .white : AppTheme.textPrimary)
                        .background(
                            Circle()
                                .fill(selectedDays.contains(day) ? AppTheme.accent : Color.white.opacity(0.58))
                        )
                        .overlay(
                            Circle()
                                .stroke(selectedDays.contains(day) ? AppTheme.accent.opacity(0.20) : AppTheme.cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.longName)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggle(_ day: RepeatDay) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
}
