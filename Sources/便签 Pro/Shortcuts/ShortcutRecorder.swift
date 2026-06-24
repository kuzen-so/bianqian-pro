import AppKit

@MainActor
class ShortcutRecorder {
    static let shared = ShortcutRecorder()
    private var monitor: Any?
    private var completion: ((ShortcutConfig?) -> Void)?

    func startRecording(completion: @escaping (ShortcutConfig?) -> Void) {
        self.completion = completion
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }

            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let keyCode = event.keyCode

            // Esc to cancel
            if keyCode == 53 {
                self.completion?(nil)
                self.stopRecording()
                return nil
            }

            // Ignore pure modifier keys
            if keyCode == 55 || keyCode == 56 || keyCode == 58 || keyCode == 59 || keyCode == 60 || keyCode == 61 {
                return event
            }

            guard modifiers != [] else { return event }

            let config = ShortcutConfig(modifiers: modifiers.rawValue, keyCode: keyCode)
            self.completion?(config)
            self.stopRecording()
            return nil
        }
    }

    func stopRecording() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        completion = nil
    }
}
