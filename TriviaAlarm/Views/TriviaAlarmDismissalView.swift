import SwiftUI

struct TriviaAlarmDismissalView: View {
    @EnvironmentObject private var scheduler: AlarmSchedulingService
    @Bindable var alarm: AlarmItem

    @State private var question: TriviaQuestion
    @State private var wrongAnswer: String?

    init(alarm: AlarmItem) {
        self.alarm = alarm
        _question = State(initialValue: TriviaService.shared.nextQuestion(categoryIDs: alarm.categoryIDs, difficulty: alarm.difficulty))
    }

    var body: some View {
        ZStack {
            AppTheme.sunriseBackground

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(alarm.label.isEmpty ? "Alarm: Trivia" : alarm.label)
                        .font(.title2.weight(.black))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(DateFormatter.alarmHeader.string(from: alarm.timeDate))
                        .font(.largeTitle.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(18)
                .floatingCard()

                VStack(alignment: .leading, spacing: 14) {
                    Text(question.category.title.uppercased())
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.accent)

                    Text(question.prompt)
                        .font(.title2.weight(.black))
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .floatingCard()

                VStack(spacing: 12) {
                    ForEach(question.answers, id: \.self) { answer in
                        Button {
                            choose(answer)
                        } label: {
                            HStack(spacing: 12) {
                                Text(answer)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                            .background(buttonBackground(for: answer), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(answerBorder(for: answer), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if wrongAnswer != nil {
                    Text("Wrong answer. Try another question.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 4)
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .interactiveDismissDisabled(true)
    }

    private func choose(_ answer: String) {
        if answer == question.correctAnswer {
            StreakStore.shared.recordCompletion()
            scheduler.dismiss(alarm: alarm)
            if alarm.repeatDays.isEmpty {
                alarm.isEnabled = false
            }
        } else {
            wrongAnswer = answer
            question = TriviaService.shared.nextQuestion(
                categoryIDs: alarm.categoryIDs,
                difficulty: alarm.difficulty,
                excluding: question.id
            )
        }
    }

    private func buttonBackground(for answer: String) -> Color {
        wrongAnswer == answer ? AppTheme.accent.opacity(0.14) : Color.white.opacity(0.60)
    }

    private func answerBorder(for answer: String) -> Color {
        wrongAnswer == answer ? AppTheme.accent.opacity(0.28) : AppTheme.cardBorder
    }
}

private extension DateFormatter {
    static let alarmHeader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
