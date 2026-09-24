import SwiftUI
import WidgetKit

struct TimerEntry: TimelineEntry {
    let date: Date
    let snapshot: TimerSnapshot

    var remaining: TimeInterval { snapshot.remaining(at: date) }
    var isRunning: Bool { snapshot.isRunning(at: date) }
}

/// Widgets can't redraw continuously, so a running timer gets one entry per minute
/// (the disk steps down each minute) while the readout counts down on its own.
struct TimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerEntry {
        TimerEntry(date: Date(), snapshot: .initial)
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> Void) {
        completion(TimerEntry(date: Date(), snapshot: SharedStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> Void) {
        let snapshot = SharedStore.load()
        let now = Date()
        guard snapshot.isRunning(at: now), let end = snapshot.endDate else {
            completion(Timeline(entries: [TimerEntry(date: now, snapshot: snapshot)], policy: .never))
            return
        }
        var entries = [TimerEntry(date: now, snapshot: snapshot)]
        // Align entries to whole minutes before the end so the disk lands on tick marks.
        var next = end.addingTimeInterval(-(end.timeIntervalSince(now) / 60).rounded(.down) * 60)
        if next <= now { next = next.addingTimeInterval(60) }
        while next < end {
            entries.append(TimerEntry(date: next, snapshot: snapshot))
            next = next.addingTimeInterval(60)
        }
        entries.append(TimerEntry(date: end, snapshot: snapshot))
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct TimerHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PomodoroTimer", provider: TimerProvider()) { entry in
            TimerWidgetView(entry: entry)
        }
        .configurationDisplayName("Pomodoro Timer")
        .description("See the time left at a glance.")
        .supportedFamilies([.systemSmall, .systemLarge, .accessoryCircular])
        .contentMarginsDisabled()
    }
}

struct TimerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimerEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            lockScreenDial
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        default:
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                TimerFace(remaining: entry.remaining,
                          isRunning: entry.isRunning,
                          theme: entry.snapshot.theme,
                          size: side,
                          showsBezel: false,
                          showsGlyph: false,
                          readout: entry.isRunning ? .live(end: entry.snapshot.endDate ?? entry.date) : .fixed)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .containerBackground(for: .widget) { entry.snapshot.theme.bezelGradient }
        }
    }

    /// Monochrome pie for the Lock Screen.
    private var lockScreenDial: some View {
        ZStack {
            Circle().stroke(lineWidth: 1.5).opacity(0.5)
            RemainingWedge(minutes: entry.remaining / 60)
                .padding(4)
        }
        .padding(2)
        .widgetAccentable()
    }
}
