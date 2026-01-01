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

struct ContentView: View {
    @State private var isRunning: Bool = false
    @State private var hasAccessibility: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isRunning ? "cursorarrow.rays" : "cursorarrow")
                .imageScale(.large)
                .foregroundStyle(isRunning ? .green : .secondary)
            Text("SVAnimCancel")
                .font(.title)

            if hasAccessibility {
                Text("Listening for middle mouse: left-click + RShift+R+Delete")
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
        }
        .frame(minWidth: 300, minHeight: 280)
        .padding()
        .onAppear {
            hasAccessibility = isAccessibilityEnabled()
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
            if isRunning {
                stopApp()
                isRunning = false
            }
        }
    }
}

#Preview {
    ContentView()
}

