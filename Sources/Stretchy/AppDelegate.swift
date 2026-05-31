import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var stretchWindow: NSWindow?
    let timerManager = TimerManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()

        timerManager.onStretchTime = { [weak self] in
            DispatchQueue.main.async { self?.showStretchPopup() }
        }
        timerManager.start()
    }

    // ── Menu bar setup ────────────────────────────────────────────

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = makeCatIcon()
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 390)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(timerManager: timerManager)
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // ── Stretch popup ─────────────────────────────────────────────

    func showStretchPopup() {
        if let existing = stretchWindow, existing.isVisible {
            existing.orderFront(nil)
            return
        }

        let windowSize = CGSize(width: 400, height: 500)
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let sr = screen.visibleFrame
        let origin = CGPoint(x: sr.midX - windowSize.width / 2,
                             y: sr.midY - windowSize.height / 2)

        let win = NSWindow(
            contentRect: NSRect(origin: origin, size: windowSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.level = .floating
        win.contentView = NSHostingView(
            rootView: StretchPopupView(timerManager: timerManager) { [weak self, weak win] in
                win?.close()
                self?.stretchWindow = nil
            }
        )
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        stretchWindow = win
    }

    // ── Menu bar cat icon ─────────────────────────────────────────

    private func makeCatIcon() -> NSImage {
        let img = NSImage(size: NSSize(width: 22, height: 22), flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            ctx.setStrokeColor(NSColor.labelColor.cgColor)
            ctx.setFillColor(NSColor.labelColor.cgColor)
            ctx.setLineWidth(1.3)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            // Head
            ctx.addEllipse(in: CGRect(x: 3, y: 4, width: 16, height: 16))
            ctx.strokePath()

            // Left ear
            ctx.move(to: CGPoint(x: 4, y: 8))
            ctx.addLine(to: CGPoint(x: 6.5, y: 2))
            ctx.addLine(to: CGPoint(x: 10, y: 7))
            ctx.strokePath()

            // Right ear
            ctx.move(to: CGPoint(x: 12, y: 7))
            ctx.addLine(to: CGPoint(x: 15.5, y: 2))
            ctx.addLine(to: CGPoint(x: 18, y: 8))
            ctx.strokePath()

            // Eyes
            ctx.fillEllipse(in: CGRect(x: 7.5, y: 10, width: 2.2, height: 2.2))
            ctx.fillEllipse(in: CGRect(x: 12.3, y: 10, width: 2.2, height: 2.2))

            // Smile
            ctx.move(to: CGPoint(x: 9, y: 14.5))
            ctx.addQuadCurve(to: CGPoint(x: 13, y: 14.5), control: CGPoint(x: 11, y: 17))
            ctx.strokePath()

            return true
        }
        img.isTemplate = true
        return img
    }
}
