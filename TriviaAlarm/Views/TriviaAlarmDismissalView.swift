import SwiftUI

struct TriviaAlarmDismissalView: View {
    @EnvironmentObject private var scheduler: AlarmSchedulingService
    @Bindable var alarm: AlarmItem

    @State private var question: TriviaQuestion
    @State private var wrongAnswer: String?
    @State private var showingSuccess = false
    @State private var wasAlreadyCompletedToday = false

    init(alarm: AlarmItem) {
        self.alarm = alarm
        _question = State(initialValue: TriviaService.shared.nextQuestion(categoryIDs: alarm.categoryIDs, difficulty: alarm.difficulty))
    }

    var body: some View {
        ZStack {
            AppTheme.sunriseBackground

            if showingSuccess {
                CorrectAnswerView(
                    streak: StreakStore.shared.currentStreak,
                    isContinuing: wasAlreadyCompletedToday
                )
            } else {
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
        }
        .interactiveDismissDisabled(true)
    }

    private func choose(_ answer: String) {
        if answer == question.correctAnswer {
            wasAlreadyCompletedToday = StreakStore.shared.isCompleted(Date())
            StreakStore.shared.recordCompletion()
            if alarm.repeatDays.isEmpty {
                alarm.isEnabled = false
            }
            showingSuccess = true

            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                scheduler.dismiss(alarm: alarm)
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

private struct CorrectAnswerView: View {
    let streak: Int
    let isContinuing: Bool
    @State private var checkmarkScale = 0.4
    @State private var contentOpacity = 0.0

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(AppTheme.warmOrange.opacity(0.20))
                    .frame(width: 150, height: 150)

                Circle()
                    .fill(AppTheme.cardSurface)
                    .frame(width: 112, height: 112)
                    .overlay {
                        Circle()
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    }

                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(AppTheme.accent)
                    .scaleEffect(checkmarkScale)
            }

            VStack(spacing: 8) {
                Text("Correct answer")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(successMessage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .multilineTextAlignment(.center)
            .opacity(contentOpacity)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) {
                checkmarkScale = 1
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.18)) {
                contentOpacity = 1
            }
        }
    }

    private var successMessage: String {
        if isContinuing {
            return streak == 1 ? "Streak is still 1 day." : "Streak is still \(streak) days."
        }

        return streak == 1 ? "Your streak is now 1 day." : "Your streak is now \(streak) days."
    }
}

private extension DateFormatter {
    static let alarmHeader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
