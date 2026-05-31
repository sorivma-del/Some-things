import Foundation
import Combine

class TimerManager: ObservableObject {
    @Published var nextStretchDate: Date = Date()
    @Published var intervalMinutes: Int = 30

    var onStretchTime: (() -> Void)?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        $intervalMinutes
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleNext() }
            .store(in: &cancellables)
    }

    func start() {
        scheduleNext()
    }

    func scheduleNext() {
        timer?.invalidate()
        nextStretchDate = Date().addingTimeInterval(Double(intervalMinutes) * 60)
        scheduleTimer(for: nextStretchDate)
    }

    func snooze(minutes: Int) {
        timer?.invalidate()
        nextStretchDate = Date().addingTimeInterval(Double(minutes) * 60)
        scheduleTimer(for: nextStretchDate)
    }

    func stretchNow() {
        onStretchTime?()
        scheduleNext()
    }

    private func scheduleTimer(for date: Date) {
        let interval = max(date.timeIntervalSinceNow, 1)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.onStretchTime?()
            self?.scheduleNext()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    var nextStretchFormatted: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: nextStretchDate)
    }

    var intervalLabel: String {
        if intervalMinutes % 60 == 0 {
            return "Каждые \(intervalMinutes / 60) ч"
        }
        return "Каждые \(intervalMinutes) мин"
    }

    var timeUntilNextStretch: String {
        let interval = nextStretchDate.timeIntervalSinceNow
        if interval <= 0 { return "Now!" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
