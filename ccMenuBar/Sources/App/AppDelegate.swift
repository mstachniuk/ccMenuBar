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
    private var eventMonitor: Any?

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
        popover.behavior = .applicationDefined
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
            closePopover()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Icon Animation

    private func startBusyObservation() {
        // Use withObservationTracking for immediate reaction to busy state changes
        func observe() {
            withObservationTracking {
                let busy = self.viewModel.hasAnyBusySession
                if busy && self.animationTimer == nil {
                    self.startAnimation()
                } else if !busy && self.animationTimer != nil {
                    self.stopAnimation()
                }
            } onChange: {
                DispatchQueue.main.async { observe() }
            }
        }
        observe()
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
