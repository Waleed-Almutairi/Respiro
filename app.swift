import Cocoa
import UserNotifications

// MARK: - State

enum Phase: Equatable {
    case working
    case resting
}

struct TimerState {
    static let workDuration: Int = 20 * 60  // 1200 seconds
    static let restDuration: Int = 20

    var phase: Phase = .working
    var secondsRemaining: Int = TimerState.workDuration
    var paused: Bool = false

    /// Tick one second. Returns the new phase if a transition happened, nil otherwise.
    mutating func tick() -> Phase? {
        guard !paused else { return nil }
        secondsRemaining -= 1
        if secondsRemaining <= 0 {
            return transition()
        }
        return nil
    }

    /// Force a phase transition. Returns the phase transitioned INTO.
    @discardableResult
    mutating func transition() -> Phase {
        switch phase {
        case .working:
            phase = .resting
            secondsRemaining = TimerState.restDuration
        case .resting:
            phase = .working
            secondsRemaining = TimerState.workDuration
        }
        return phase
    }

    mutating func togglePause() {
        paused.toggle()
    }

    var displayTime: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Overlay Controller

class OverlayController {
    private var windows: [NSWindow] = []
    private var countdownLabels: [NSTextField] = []

    private let funnyPhrases = [
        "Your eyes are begging for mercy!",
        "Oi! Look away from the screen, you goblin!",
        "Twenty minutes! Go stare at a wall or something!",
        "Screen break! Your eyeballs will thank you!",
        "Hydrate those eyes! Look into the distance!",
    ]

    var isShowing: Bool { !windows.isEmpty }

    func show(seconds: Int) {
        dismiss()
        let phrase = funnyPhrases.randomElement()!

        for screen in NSScreen.screens {
            let (window, label) = makeOverlayWindow(frame: screen.frame, phrase: phrase, seconds: seconds)
            windows.append(window)
            countdownLabels.append(label)
            window.orderFrontRegardless()
        }
    }

    func updateCountdown(_ seconds: Int) {
        let text = "\(seconds)"
        for label in countdownLabels {
            label.stringValue = text
        }
    }

    func dismiss() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        countdownLabels.removeAll()
    }

    private func makeOverlayWindow(frame: NSRect, phrase: String, seconds: Int) -> (NSWindow, NSTextField) {
        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.hasShadow = false

        // Background view with semi-transparent dark blue tint
        let bgView = NSView(frame: frame)
        bgView.wantsLayer = true
        bgView.layer?.backgroundColor = NSColor(
            calibratedRed: 0.0, green: 0.05, blue: 0.15, alpha: 0.75
        ).cgColor
        window.contentView = bgView

        // Eye emoji
        let eyeLabel = makeLabel("👀", size: 80, weight: .regular, alpha: 1.0)

        // Message
        let messageLabel = makeLabel("Look away for 20 seconds", size: 32, weight: .medium, alpha: 1.0)

        // Countdown
        let countdownLabel = NSTextField(labelWithString: "\(seconds)")
        countdownLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 72, weight: .bold)
        countdownLabel.textColor = NSColor.white
        countdownLabel.alignment = .center
        countdownLabel.isBordered = false
        countdownLabel.isEditable = false
        countdownLabel.drawsBackground = false
        countdownLabel.isSelectable = false

        // Funny phrase
        let phraseLabel = makeLabel(phrase, size: 18, weight: .regular, alpha: 0.7)

        // Stack them vertically
        let stack = NSStackView(views: [eyeLabel, messageLabel, countdownLabel, phraseLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        bgView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: bgView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: bgView.centerYAnchor),
        ])

        return (window, countdownLabel)
    }

    private func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = NSColor.white.withAlphaComponent(alpha)
        label.alignment = .center
        label.isBordered = false
        label.isEditable = false
        label.drawsBackground = false
        label.isSelectable = false
        return label
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var state = TimerState()

    private var statusMenuItem: NSMenuItem!
    private var toggleMenuItem: NSMenuItem!

    private let overlay = OverlayController()
    private var menuBarIcon: NSImage?

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Re-create overlay windows if screens change (plug/unplug monitor)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        menuBarIcon = loadMenuBarIcon()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeft
        buildMenu()
        startTimer()
        updateDisplay()
    }

    private func loadMenuBarIcon() -> NSImage? {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: "menubar_icon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    // MARK: Notification delegate — show banners even when app is frontmost

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: Menu

    private func buildMenu() {
        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        toggleMenuItem = NSMenuItem(title: "Pause", action: #selector(togglePause), keyEquivalent: "p")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        let transitioned = state.tick()
        updateDisplay()

        switch transitioned {
        case .resting:
            overlay.show(seconds: state.secondsRemaining)
            playWorkDoneSound()
            sendNotification(
                title: "Look away! 👀",
                body: "Stare at something 20 feet away for 20 seconds."
            )
        case .working:
            overlay.dismiss()
            playRestDoneSound()
            sendNotification(
                title: "Back to work!",
                body: "Next break in 20 minutes."
            )
        case nil:
            if state.phase == .resting {
                overlay.updateCountdown(state.secondsRemaining)
            }
        }
    }

    // MARK: Display

    private func updateDisplay() {
        let time = state.displayTime
        statusItem.button?.image = menuBarIcon

        if state.paused {
            statusItem.button?.title = " ⏸"
            let phaseLabel = state.phase == .working ? "Working" : "Resting"
            statusMenuItem.title = "\(phaseLabel) — paused (\(time) left)"
        } else {
            statusItem.button?.title = " \(time)"
            let phaseLabel = state.phase == .working ? "Working" : "Resting"
            statusMenuItem.title = "\(phaseLabel) — \(time) remaining"
        }

        toggleMenuItem.title = state.paused ? "Resume" : "Pause"
    }

    // MARK: Sound

    private func playWorkDoneSound() {
        // Clear bell tone — play twice for emphasis
        NSSound(named: "Glass")?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSSound(named: "Glass")?.play()
        }
    }

    private func playRestDoneSound() {
        // Two-tone "come back" chime — audible even when looking away
        NSSound(named: "Purr")?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            NSSound(named: "Hero")?.play()
        }
    }

    // MARK: Notifications

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: Actions

    @objc private func togglePause() {
        state.togglePause()
        if state.paused {
            timer?.invalidate()
            timer = nil
        } else {
            startTimer()
        }
        updateDisplay()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func screenConfigChanged() {
        // If overlay is showing during a screen change, refresh it
        if overlay.isShowing && state.phase == .resting && !state.paused {
            overlay.show(seconds: state.secondsRemaining)
        }
    }
}

// MARK: - Main

#if !TESTING
@main
struct RespiroApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
#endif
