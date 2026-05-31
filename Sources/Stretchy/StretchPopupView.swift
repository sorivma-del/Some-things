import SwiftUI

struct StretchPopupView: View {
    @ObservedObject var timerManager: TimerManager
    var onDismiss: () -> Void

    @State private var isStretching = false
    @State private var messageVisible = false

    private static let messages = [
        "Get up, stand up!",
        "Time to stretch!",
        "Let's not have the posture of a cashew 🙀",
        "Your body says: please move!",
        "Stretch break! Stand tall!"
    ]
    @State private var message = messages.randomElement()!

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.85, blue: 0.88), Color(red: 1.0, green: 0.75, blue: 0.80)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                CatView(isStretching: isStretching)
                    .frame(width: 200, height: 240)

                Text(message)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .opacity(messageVisible ? 1 : 0)
                    .offset(y: messageVisible ? 0 : 10)
                    .animation(.spring(response: 0.5).delay(0.3), value: messageVisible)

                Spacer()

                // ── Done button ───────────────────────────────────
                Button(action: {
                    timerManager.scheduleNext()
                    onDismiss()
                }) {
                    Text("Done! ✓")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 220)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.93, green: 0.28, blue: 0.50))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                }
                .buttonStyle(.plain)

                // ── Snooze row ────────────────────────────────────
                HStack(spacing: 12) {
                    ForEach([10, 20], id: \.self) { min in
                        Button(action: {
                            timerManager.snooze(minutes: min)
                            onDismiss()
                        }) {
                            Text("Snooze \(min)m")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 9)
                                .background(Color.white.opacity(0.55))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            messageVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isStretching = true
            }
        }
    }
}
