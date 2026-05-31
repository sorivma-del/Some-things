import SwiftUI

struct MenuBarPopoverView: View {
    @ObservedObject var timerManager: TimerManager

    var body: some View {
        ZStack {
            Color(red: 1.0, green: 0.91, blue: 0.93).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Cat + title ───────────────────────────────────
                VStack(spacing: 6) {
                    CatView(isStretching: false)
                        .frame(width: 90, height: 110)

                    Text("Stretchy")
                        .font(.system(size: 22, weight: .bold))

                    HStack(spacing: 5) {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Next: \(timerManager.nextStretchFormatted)")
                            .font(.system(size: 13))
                    }

                    Text(timerManager.intervalLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.5))
                }
                .padding(.top, 18)
                .padding(.bottom, 14)

                Divider().padding(.horizontal, 16)

                // ── Status row ────────────────────────────────────
                HStack(spacing: 10) {
                    Text("✦")
                        .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.5))
                        .font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ready for your next stretch")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Stretchy will pop up when it is time.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // ── Stretch now ───────────────────────────────────
                Button(action: { timerManager.stretchNow() }) {
                    Label("Stretch now", systemImage: "figure.walk")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color(red: 0.93, green: 0.3, blue: 0.52))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // ── Snooze chips ──────────────────────────────────
                HStack(spacing: 8) {
                    ForEach([10, 20, 30], id: \.self) { min in
                        Button(action: { timerManager.snooze(minutes: min) }) {
                            Label("\(min) min", systemImage: "clock")
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.65))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Divider().padding(.horizontal, 16)

                // ── Bottom bar ────────────────────────────────────
                HStack {
                    Button("Settings") { showSettings() }
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 280, height: 390)
    }

    private func showSettings() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Stretchy Settings"
        win.center()
        win.contentView = NSHostingView(rootView: SettingsView(timerManager: timerManager))
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @ObservedObject var timerManager: TimerManager

    private let options: [(label: String, minutes: Int)] = [
        ("20 min", 20), ("30 min", 30), ("45 min", 45),
        ("1 hr", 60), ("2 hr", 120)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remind me every")
                .font(.system(size: 13, weight: .semibold))

            Picker("", selection: $timerManager.intervalMinutes) {
                ForEach(options, id: \.minutes) { opt in
                    Text(opt.label).tag(opt.minutes)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text("Ergonomics tip: standing up and moving every 30 minutes keeps your posture happy.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 340, height: 160)
    }
}
