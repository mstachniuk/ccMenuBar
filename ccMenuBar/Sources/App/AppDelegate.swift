import AppKit
import SwiftUI
import Observation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let monitor = SessionMonitor()
    private var viewModel: MenuBarViewModel!
    private var animationTimer: Timer?
    private var showFilledIcon = false
    private var observationTask: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        viewModel = MenuBarViewModel(monitor: monitor)

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon(busy: false)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: SessionListView(viewModel: viewModel)
        )

        // Start monitoring
        monitor.start()

        // Observe busy state changes using a polling approach
        // (withObservationTracking requires careful lifecycle management)
        startBusyObservation()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        animationTimer?.invalidate()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Refresh the view content
            popover.contentViewController = NSHostingController(
                rootView: SessionListView(viewModel: viewModel)
            )
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Dismiss when clicking outside
            if let window = popover.contentViewController?.view.window {
                window.makeKey()
            }
        }
    }

    // MARK: - Icon Animation

    private func startBusyObservation() {
        // Poll for busy state changes every 0.5s (aligned with animation)
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let busy = self.viewModel.hasAnyBusySession
            if busy && self.animationTimer == nil {
                self.startAnimation()
            } else if !busy && self.animationTimer != nil {
                self.stopAnimation()
            }
        }
    }

    private func startAnimation() {
        showFilledIcon = false
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.showFilledIcon.toggle()
            self.updateIcon(busy: true)
        }
        updateIcon(busy: true)
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        showFilledIcon = false
        updateIcon(busy: false)
    }

    private func updateIcon(busy: Bool) {
        guard let button = statusItem.button else { return }

        let symbolName = busy && showFilledIcon ? "terminal.fill" : "terminal"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Claude Code Status")

        if busy {
            let config = NSImage.SymbolConfiguration(paletteColors: [.orange])
            button.image = image?.withSymbolConfiguration(config)
        } else {
            button.image = image
        }
    }
}
