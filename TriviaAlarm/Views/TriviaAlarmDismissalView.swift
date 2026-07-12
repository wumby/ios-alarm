import SwiftUI
import AVFoundation

struct TriviaAlarmDismissalView: View {
    @EnvironmentObject private var scheduler: AlarmSchedulingService
    @Bindable var alarm: AlarmItem

    @State private var question: TriviaQuestion
    @State private var wrongAnswer: String?
    @State private var showingSuccess = false
    @State private var wasAlreadyCompletedToday = false
    @StateObject private var successSoundPlayer = SuccessSoundPlayer()

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
                    isContinuing: wasAlreadyCompletedToday,
                    title: alarm.triviaEnabled ? "Correct answer" : "Good morning",
                    showsStreak: alarm.triviaEnabled
                )
            } else if alarm.triviaEnabled {
                VStack(alignment: .leading, spacing: 24) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
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
            } else {
                Color.clear
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            if !alarm.triviaEnabled {
                completeWithoutTrivia()
            }
        }
        .onDisappear {
            successSoundPlayer.stop()
        }
    }

    private func choose(_ answer: String) {
        if answer == question.correctAnswer {
            wasAlreadyCompletedToday = StreakStore.shared.isCompleted(Date())
            StreakStore.shared.recordCompletion()
            if alarm.repeatDays.isEmpty {
                alarm.isEnabled = false
            }
            scheduler.stopSound(alarm: alarm)
            successSoundPlayer.play()
            showingSuccess = true

            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
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

    private func completeWithoutTrivia() {
        guard !showingSuccess else { return }

        if alarm.repeatDays.isEmpty {
            alarm.isEnabled = false
        }
        scheduler.stopSound(alarm: alarm)
        successSoundPlayer.play()
        showingSuccess = true

        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            scheduler.dismiss(alarm: alarm)
        }
    }

    private func buttonBackground(for answer: String) -> Color {
        wrongAnswer == answer ? AppTheme.accent.opacity(0.14) : Color.white.opacity(0.60)
    }

    private func answerBorder(for answer: String) -> Color {
        wrongAnswer == answer ? AppTheme.accent.opacity(0.28) : AppTheme.cardBorder
    }
}

@MainActor
private final class SuccessSoundPlayer: ObservableObject {
    private var player: AVAudioPlayer?

    func play() {
        stop()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            player = try AVAudioPlayer(data: Self.chimeData())
            player?.volume = 0.7
            player?.prepareToPlay()
            player?.play()
        } catch {
            player = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    private static func chimeData() -> Data {
        let sampleRate = 44_100
        let duration = 3.8
        let frameCount = Int(Double(sampleRate) * duration)
        var samples = Data(capacity: frameCount * 2)
        let notes: [(frequency: Double, start: Double, end: Double)] = [
            (523.25, 0.00, 1.55),
            (659.25, 0.72, 2.65),
            (783.99, 1.65, 3.80)
        ]

        for frame in 0..<frameCount {
            let time = Double(frame) / Double(sampleRate)
            var value = 0.0
            for note in notes where time >= note.start && time < note.end {
                let noteTime = time - note.start
                let noteDuration = note.end - note.start
                let attack = min(noteTime / 0.18, 1.0)
                let release = min((noteDuration - noteTime) / 0.55, 1.0)
                let envelope = max(0, min(attack, release))
                value += sin(2.0 * .pi * note.frequency * noteTime) * envelope
            }

            let fadeOut = min((duration - time) / 0.7, 1.0)
            let sample = Int16(max(-1.0, min(1.0, value * 0.13 * fadeOut)) * Double(Int16.max))
            samples.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Data($0) })
        }

        var wav = Data()
        wav.append(contentsOf: Array("RIFF".utf8))
        wav.append(contentsOf: littleEndianBytes(UInt32(36 + samples.count)))
        wav.append(contentsOf: Array("WAVEfmt ".utf8))
        wav.append(contentsOf: littleEndianBytes(UInt32(16)))
        wav.append(contentsOf: littleEndianBytes(UInt16(1)))
        wav.append(contentsOf: littleEndianBytes(UInt16(1)))
        wav.append(contentsOf: littleEndianBytes(UInt32(sampleRate)))
        wav.append(contentsOf: littleEndianBytes(UInt32(sampleRate * 2)))
        wav.append(contentsOf: littleEndianBytes(UInt16(2)))
        wav.append(contentsOf: littleEndianBytes(UInt16(16)))
        wav.append(contentsOf: Array("data".utf8))
        wav.append(contentsOf: littleEndianBytes(UInt32(samples.count)))
        wav.append(samples)
        return wav
    }

    private static func littleEndianBytes<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        withUnsafeBytes(of: value.littleEndian) { Array($0) }
    }
}

private struct CorrectAnswerView: View {
    let streak: Int
    let isContinuing: Bool
    let title: String
    let showsStreak: Bool
    @State private var checkmarkScale = 0.4
    @State private var contentOpacity = 0.0

    var body: some View {
        ZStack {
            SuccessSunriseBackground()

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
                    Text(title)
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(successMessage)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .multilineTextAlignment(.center)
                .opacity(contentOpacity)
            }
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
        if !showsStreak {
            return "Your alarm is dismissed. Have a great morning."
        }

        if isContinuing {
            return streak == 1 ? "Streak is still 1 day." : "Streak is still \(streak) days."
        }

        return streak == 1 ? "Your streak is now 1 day." : "Your streak is now \(streak) days."
    }
}

private struct SuccessSunriseBackground: View {
    @State private var sunRise = 0.0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.sunriseBackground

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.warmOrange.opacity(0.95), AppTheme.accent.opacity(0.45), .clear],
                            center: .center,
                            startRadius: 12,
                            endRadius: 145
                        )
                    )
                    .frame(width: 250, height: 250)
                    .position(
                        x: proxy.size.width * 0.5,
                        y: proxy.size.height * (0.88 - (0.44 * sunRise))
                    )

                Circle()
                    .fill(AppTheme.warmOrange)
                    .frame(width: 88, height: 88)
                    .shadow(color: AppTheme.warmOrange.opacity(0.65), radius: 26)
                    .position(
                        x: proxy.size.width * 0.5,
                        y: proxy.size.height * (0.88 - (0.44 * sunRise))
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2)) {
                sunRise = 1
            }
        }
    }
}
