import AppKit
import SwiftUI

private let bundleID = "dev.freecoffee.GrokSpeak"

extension Notification.Name {
    static let speakNow = Notification.Name("dev.freecoffee.GrokSpeak.speakNow")
    static let stopNow = Notification.Name("dev.freecoffee.GrokSpeak.stopNow")
    static let togglePlay = Notification.Name("dev.freecoffee.GrokSpeak.togglePlay")
    static let skipBack = Notification.Name("dev.freecoffee.GrokSpeak.skipBack")
    static let skipForward = Notification.Name("dev.freecoffee.GrokSpeak.skipForward")
    static let loadLastReply = Notification.Name("dev.freecoffee.GrokSpeak.loadLastReply")
    static let speakForce = Notification.Name("dev.freecoffee.GrokSpeak.speakForce")
}

@main
struct GrokSpeakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 980, height: 660)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Speak") {
                Button("Speak") {
                    NotificationCenter.default.post(name: .speakNow, object: nil)
                }
                .keyboardShortcut(.return, modifiers: .command)
                Button("New take") {
                    NotificationCenter.default.post(name: .speakForce, object: nil)
                }
                .keyboardShortcut(.return, modifiers: [.command, .option])
                Button("Stop") {
                    NotificationCenter.default.post(name: .stopNow, object: nil)
                }
                .keyboardShortcut(".", modifiers: .command)
                Divider()
                Button("Play / Pause") {
                    NotificationCenter.default.post(name: .togglePlay, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                Button("Skip Back 15s") {
                    NotificationCenter.default.post(name: .skipBack, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                Button("Skip Forward 15s") {
                    NotificationCenter.default.post(name: .skipForward, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                Divider()
                Button("Load Last Grok Reply") {
                    NotificationCenter.default.post(name: .loadLastReply, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let other = others.first {
            other.activate()
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
