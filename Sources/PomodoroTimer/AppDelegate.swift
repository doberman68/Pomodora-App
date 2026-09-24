import AppKit
import Combine
import SwiftUI
import UserNotifications

/// Borderless panel that can take clicks without activating the app.
final class TimerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    private let model = TimerModel()
    private let dragger = WindowDragger()
    private var panel: TimerPanel!
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let sizeMenu = NSMenu()
    private let colorMenu = NSMenu()
    private var customColorTarget = ColorTarget.disk
    private var opacitySlider: NSSlider!
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    private static let presets: [(title: String, minutes: Int)] = [
        ("Focus — 25 min", 25),
        ("Short Break — 5 min", 5),
        ("Long Break — 15 min", 15),
        ("Deep Work — 50 min", 50),
    ]
    private static let sizes: [(title: String, side: Int)] = [
        ("Small", 220), ("Medium", 300), ("Large", 420),
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Alarm.notificationsAvailable {
            UNUserNotificationCenter.current().delegate = self
        }
        Alarm.requestAuthorization()
        buildPanel()
        buildMenu()
        buildStatusItem()
        installEventMonitor()
        bindModel()
        panel.orderFrontRegardless()
    }

    // MARK: - Window

    private func buildPanel() {
        panel = TimerPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
                           styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered,
                           defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        dragger.window = panel
        let host = NSHostingView(rootView: TimerView(model: model, dragger: dragger))
        host.sizingOptions = []
        panel.contentView = host

        panel.center()
        // Restores the last position and size, and saves future changes.
        panel.setFrameAutosaveName("PomodoroTimerWindow")
    }

    private func bindModel() {
        model.$opacity
            .sink { [weak self] value in
                self?.panel.alphaValue = value
                self?.opacitySlider.doubleValue = value * 100
            }
            .store(in: &cancellables)

        model.$alwaysOnTop
            .sink { [weak self] onTop in
                self?.panel.level = onTop ? .floating : .normal
            }
            .store(in: &cancellables)

        model.$remaining.combineLatest(model.$isRunning)
            .map { remaining, running in running ? " " + TimerFace.format(remaining) : "" }
            .removeDuplicates()
            .sink { [weak self] title in
                self?.statusItem.button?.title = title
            }
            .store(in: &cancellables)
    }

    /// Scroll over the timer to fade it; right-click (or control-click) for the menu.
    private func installEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.scrollWheel, .rightMouseDown, .leftMouseDown]
        ) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            switch event.type {
            case .scrollWheel:
                let step = event.hasPreciseScrollingDeltas ? 0.004 : 0.03
                self.model.opacity += Double(event.scrollingDeltaY) * step
                return nil
            case .rightMouseDown:
                self.showContextMenu(event)
                return nil
            case .leftMouseDown where event.modifierFlags.contains(.control):
                self.showContextMenu(event)
                return nil
            default:
                return event
            }
        }
    }

    private func showContextMenu(_ event: NSEvent) {
        guard let view = panel.contentView else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    // MARK: - Menu (shared by the menu bar icon and right-click)

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Pomodoro Timer")
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        }
        statusItem.menu = menu
    }

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        menu.addItem(item("Start", #selector(toggleTimer), key: " ", tag: MenuTag.toggle))
        menu.addItem(item("Reset", #selector(resetTimer), key: "r"))
        menu.addItem(.separator())

        for (index, preset) in Self.presets.enumerated() {
            let presetItem = item(preset.title, #selector(startPreset(_:)))
            presetItem.tag = preset.minutes
            presetItem.keyEquivalent = "\(index + 1)"
            menu.addItem(presetItem)
        }
        menu.addItem(.separator())

        let label = NSMenuItem(title: "Transparency", action: nil, keyEquivalent: "")
        label.isEnabled = false
        menu.addItem(label)
        menu.addItem(sliderItem())

        menu.addItem(item("Float on Top", #selector(toggleFloat), tag: MenuTag.float))

        let colorItem = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        for (index, preset) in Theme.presets.enumerated() {
            let entry = item(preset.name, #selector(setTheme(_:)))
            entry.tag = index
            entry.image = preset.theme.swatch
            colorMenu.addItem(entry)
        }
        colorMenu.addItem(.separator())
        colorMenu.addItem(item("Custom Disk Color…", #selector(pickCustomColor(_:)), tag: ColorTarget.disk.rawValue))
        colorMenu.addItem(item("Custom Frame Color…", #selector(pickCustomColor(_:)), tag: ColorTarget.frame.rawValue))
        colorItem.submenu = colorMenu
        menu.addItem(colorItem)

        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        for size in Self.sizes {
            let entry = item(size.title, #selector(setSize(_:)))
            entry.tag = size.side
            sizeMenu.addItem(entry)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(item("Hide Timer", #selector(toggleVisibility), key: "h", tag: MenuTag.visibility))
        menu.addItem(.separator())
        menu.addItem(item("Quit Pomodoro Timer", #selector(quit), key: "q"))
    }

    private enum MenuTag {
        static let toggle = 9001
        static let float = 9002
        static let visibility = 9003
    }

    private enum ColorTarget: Int {
        case disk = 1
        case frame = 2
    }

    private func item(_ title: String, _ action: Selector, key: String = "", tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.tag = tag
        return item
    }

    private func sliderItem() -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 28))
        let slider = NSSlider(value: model.opacity * 100, minValue: TimerLimits.minOpacity * 100,
                              maxValue: 100, target: self, action: #selector(opacityChanged(_:)))
        slider.frame = NSRect(x: 18, y: 4, width: 184, height: 20)
        slider.isContinuous = true
        container.addSubview(slider)
        opacitySlider = slider
        let item = NSMenuItem()
        item.view = container
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.item(withTag: MenuTag.toggle)?.title = model.isRunning ? "Pause" : "Start"
        menu.item(withTag: MenuTag.float)?.state = model.alwaysOnTop ? .on : .off
        menu.item(withTag: MenuTag.visibility)?.title = panel.isVisible ? "Hide Timer" : "Show Timer"
        let side = Int(panel.frame.width.rounded())
        for entry in sizeMenu.items {
            entry.state = entry.tag == side ? .on : .off
        }
        for entry in colorMenu.items where entry.action == #selector(setTheme(_:)) {
            entry.state = Theme.presets[entry.tag].theme == model.theme ? .on : .off
        }
    }

    // MARK: - Actions

    @objc private func toggleTimer() { model.toggle() }

    @objc private func resetTimer() {
        withAnimation(.easeInOut(duration: 0.5)) { model.reset() }
    }

    @objc private func startPreset(_ sender: NSMenuItem) {
        model.startPreset(minutes: sender.tag)
        panel.orderFrontRegardless()
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        model.opacity = sender.doubleValue / 100
    }

    @objc private func setTheme(_ sender: NSMenuItem) {
        model.theme = Theme.presets[sender.tag].theme
    }

    /// Opens the system color picker; colors apply live as you pick.
    @objc private func pickCustomColor(_ sender: NSMenuItem) {
        customColorTarget = ColorTarget(rawValue: sender.tag) ?? .disk
        let picker = NSColorPanel.shared
        picker.setTarget(nil)
        picker.showsAlpha = false
        picker.color = (customColorTarget == .disk ? model.theme.disk : model.theme.frame).nsColor
        picker.title = customColorTarget == .disk ? "Disk Color" : "Frame Color"
        picker.setTarget(self)
        picker.setAction(#selector(customColorChanged(_:)))
        picker.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        picker.makeKeyAndOrderFront(nil)
    }

    @objc private func customColorChanged(_ sender: NSColorPanel) {
        guard let rgb = RGB(nsColor: sender.color) else { return }
        switch customColorTarget {
        case .disk: model.theme.disk = rgb
        case .frame: model.theme.frame = rgb
        }
    }

    @objc private func toggleFloat() { model.alwaysOnTop.toggle() }

    @objc private func setSize(_ sender: NSMenuItem) {
        let side = CGFloat(sender.tag)
        let frame = panel.frame
        panel.setFrame(NSRect(x: frame.midX - side / 2, y: frame.midY - side / 2, width: side, height: side),
                       display: true, animate: true)
    }

    @objc private func toggleVisibility() {
        if panel.isVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Notifications

    /// Show the banner even while the app is frontmost.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}
