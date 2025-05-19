//
//  AppDelegate.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 4/29/25.
//

import AppKit
import SwiftUI


class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the app from the Dock
        NSApp.setActivationPolicy(.prohibited)

        // Setup shared state
        _ = SelectedReceiver.shared
        let connection = Connection.shared

        print(SelectedReceiver.shared.receiver)
        if let receiver = SelectedReceiver.shared.receiver {
            connection.start(receiver: receiver)
        } else {
            print("asntuhoercuh")
            connection.enterDemoMode()
        }

        // Setup popover view
        let contentView = StatusPopoverView()
        let hostingController = NSHostingController(rootView: contentView)

        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true

        // Setup status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Volume")
            button.action = #selector(togglePopover(_:))
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
            popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                
                DispatchQueue.main.async {
                    self.popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
}


extension View {
    func onWindowDidAppear(_ callback: @escaping (NSWindow) -> Void) -> some View {
        self.background(
            WindowAccessor(onWindow: callback)
        )
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        DispatchQueue.main.async {
            if let window = nsView.window {
                onWindow(window)
            }
        }
        return nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
