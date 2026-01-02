//
//  ContentView.swift
//  StardewAC
//
//  Created by Matt Kingston on 1/1/2026.
//

import SwiftUI
import Foundation

@_silgen_name("runApp") func runApp() -> Void
@_silgen_name("stopApp") func stopApp() -> Void
@_silgen_name("isAccessibilityEnabled") func isAccessibilityEnabled() -> Bool
@_silgen_name("setRepeatIntervalMilliseconds") func setRepeatIntervalMilliseconds(_ milliseconds: Int32) -> Void
@_silgen_name("setMouseTrigger") func setMouseTrigger(_ buttonNumber: Int32, _ modifiersMask: UInt64) -> Void
@_silgen_name("setKeyTrigger") func setKeyTrigger(_ keyCode: UInt16, _ modifiersMask: UInt64) -> Void

struct ContentView: View {
    @State private var isRunning: Bool = false
    @State private var hasAccessibility: Bool = true
    @State private var delayMs: Double = 200

    @State private var awaitingTrigger: Bool = false
    @AppStorage("trigger.description") private var triggerDescription: String = "Middle Click"
    @AppStorage("trigger.type") private var triggerType: String = "mouse" // "mouse" or "key"
    @AppStorage("trigger.keyCode") private var triggerKeyCode: Int = 0
    @AppStorage("trigger.buttonNumber") private var triggerButtonNumber: Int = 2 // 2 = middle
    @AppStorage("trigger.modifiers") private var triggerModifiers: String = "" // e.g. "ctrl+opt"
    @State private var keyMonitor: Any?
    @State private var mouseMonitor: Any?

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                ZStack {
                    // Reserve a fixed area so symbol swaps don't shift layout
                    Color.clear
                    Image(systemName: isRunning ? "cursorarrow.rays" : "cursorarrow")
                        .font(.system(size: isRunning ? 64 : 32, weight: .regular))
                        .foregroundStyle(isRunning ? .green : .secondary)
                }
                .frame(width: 80, height: 80)
                Text("Stardew Animation Cancel")
                    .font(.title)

                if hasAccessibility {
                    VStack(spacing: 2) {
                        Text("Listening for \(triggerDescription)")
                        Text("Triggers a Left Click, \(Int(delayMs))ms delay, Right Shift + R + Delete")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                } else {
                    VStack(spacing: 8) {
                        Text("Accessibility permissions not granted.")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text("Grant access in System Settings → Privacy & Security → Accessibility, then close and re-open the app.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 4)
                }

                VStack(spacing: 8) {
                    Text("Delay: \(Int(delayMs)) ms")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Spacer()
                        Slider(value: $delayMs, in: 1...500)
                            .frame(maxWidth: 300)
                            .onChange(of: delayMs) { _, newValue in
                                setRepeatIntervalMilliseconds(Int32(newValue))
                            }
                        Spacer()
                    }
                }

                HStack {
                    Button(isRunning ? "Stop" : "Start") {
                        if isRunning {
                            stopApp()
                            isRunning = false
                        } else {
                            DispatchQueue.global(qos: .userInitiated).async {
                                runApp()
                            }
                            isRunning = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(!hasAccessibility ? .gray : (isRunning ? .red : .blue))
                    .disabled(!hasAccessibility)
                }

                VStack(spacing: 6) {
                    Button("Change trigger…") {
                        beginAwaitingTrigger()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    Text("Current trigger: \(triggerDescription)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(awaitingTrigger ? 0.4 : 1)

            if awaitingTrigger {
                Color.black.opacity(0.1).ignoresSafeArea()
                VStack(spacing: 12) {
                    Text("Awaiting trigger – Press a key or click a mouse button to assign")
                        .font(.headline)
                    Text("Press Esc to cancel")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            cancelAwaitingTrigger()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.thinMaterial)
            }
        }
        .frame(minWidth: 360, minHeight: 340)
        .padding()
        .onAppear {
            hasAccessibility = isAccessibilityEnabled()
            setRepeatIntervalMilliseconds(Int32(delayMs))
            let mask = modifierMaskFromString(triggerModifiers)
            if triggerType == "mouse" {
                setMouseTrigger(Int32(triggerButtonNumber), mask)
            } else {
                setKeyTrigger(UInt16(triggerKeyCode), mask)
            }
            if hasAccessibility {
                // Optionally auto-start on launch
                if !isRunning {
                    DispatchQueue.global(qos: .userInitiated).async {
                        runApp()
                    }
                    isRunning = true
                }
            } else {
                // Ensure not running if permissions are missing
                if isRunning {
                    stopApp()
                    isRunning = false
                }
            }
        }
        .onDisappear {
            removeMonitors()
            if isRunning {
                stopApp()
                isRunning = false
            }
        }
    }

    private func beginAwaitingTrigger() {
        // Stop the running service while awaiting
        if isRunning {
            stopApp()
            isRunning = false
        }
        awaitingTrigger = true
        // Install event monitors for keyboard and mouse
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handleKeyEvent(event)
            return nil // swallow while awaiting
        }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .otherMouseDown]) { event in
            handleMouseEvent(event)
            return nil // swallow while awaiting
        }
    }

    private func cancelAwaitingTrigger() {
        removeMonitors()
        awaitingTrigger = false
    }

    private func removeMonitors() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Esc cancels
        if event.keyCode == 53 { // kVK_Escape
            cancelAwaitingTrigger()
            return
        }
        let mods = describeModifiers(event.modifierFlags)
        let key = event.charactersIgnoringModifiers ?? "Key"
        triggerDescription = (mods.isEmpty ? key : mods + "+" + key)
        triggerType = "key"
        triggerKeyCode = Int(event.keyCode)
        triggerButtonNumber = -1
        triggerModifiers = mods
        let mask = modifierMaskFromString(mods)
        setKeyTrigger(UInt16(event.keyCode), mask)
        awaitingTrigger = false
        removeMonitors()
    }

    private func handleMouseEvent(_ event: NSEvent) {
        // Ignore left click assignment
        if event.type == .leftMouseDown { return }
        let mods = describeModifiers(event.modifierFlags)
        let buttonName: String
        var buttonNumber: Int = Int(event.buttonNumber)
        switch event.type {
        case .rightMouseDown: buttonName = "Right Click"; if buttonNumber == 0 { buttonNumber = 1 }
        case .otherMouseDown:
            buttonName = (event.buttonNumber == 2) ? "Middle Click" : "Mouse Button \(event.buttonNumber)"
        default: buttonName = "Mouse";
        }
        triggerDescription = (mods.isEmpty ? buttonName : mods + "+" + buttonName)
        triggerType = "mouse"
        triggerKeyCode = -1
        triggerButtonNumber = buttonNumber
        triggerModifiers = mods
        let mask = modifierMaskFromString(mods)
        setMouseTrigger(Int32(buttonNumber), mask)
        awaitingTrigger = false
        removeMonitors()
    }

    private func describeModifiers(_ flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.function) { parts.append("fn") }
        if flags.contains(.control) { parts.append("ctrl") }
        if flags.contains(.command) { parts.append("cmd") }
        if flags.contains(.option) { parts.append("opt") }
        if flags.contains(.shift) { parts.append("shift") }
        return parts.joined(separator: "+")
    }

    private func modifierMaskFromString(_ mods: String) -> UInt64 {
        var mask: UInt64 = 0
        let parts = mods.split(separator: "+").map { String($0) }
        for p in parts {
            switch p {
            case "ctrl": mask |= (1 << 0)
            case "cmd": mask |= (1 << 1)
            case "opt": mask |= (1 << 2)
            case "shift": mask |= (1 << 3)
            case "fn": mask |= (1 << 4)
            default: break
            }
        }
        return mask
    }
}

#Preview {
    ContentView()
}
