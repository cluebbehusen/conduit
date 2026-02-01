//
//  TerminalAccessoryFAB.swift
//  conduit
//

import SwiftUI

struct TerminalAccessoryFAB: View {
    let sshService: SSHService
    let mode: AccessoryBarMode
    @Binding var ctrlActive: Bool
    let onKeyTap: () -> Void

    @State private var isExpanded = false
    @Namespace private var namespace

    private enum KeyAction: String {
        case escape, ctrl, tab
        case arrowLeft, arrowUp, arrowDown, arrowRight
    }

    var body: some View {
        if mode != .hidden {
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    if isExpanded || mode == .expanded {
                        // Arrow keys row
                        HStack(spacing: 8) {
                            arrowButton(symbol: "arrow.left", action: .arrowLeft)
                            arrowButton(symbol: "arrow.up", action: .arrowUp)
                            arrowButton(symbol: "arrow.down", action: .arrowDown)
                            arrowButton(symbol: "arrow.right", action: .arrowRight)
                        }

                        // Modifier keys row
                        HStack(spacing: 8) {
                            modifierButton(title: "esc", action: .escape)
                            ctrlButton
                            modifierButton(title: "tab", action: .tab)
                        }
                    }

                    // Only show toggle button when not in always-expanded mode
                    if mode != .expanded {
                        toggleButton
                    }
                }
            }
            .padding(16)
            .onAppear {
                if mode == .expanded {
                    isExpanded = true
                }
            }
            .onChange(of: mode) { _, newMode in
                withAnimation {
                    isExpanded = newMode == .expanded
                }
            }
        }
    }

    private func arrowButton(symbol: String, action: KeyAction) -> some View {
        Button {
            handleKeyTap(action)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive())
        .glassEffectID(action.rawValue, in: namespace)
    }

    private func modifierButton(title: String, action: KeyAction) -> some View {
        Button {
            handleKeyTap(action)
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive())
        .glassEffectID(action.rawValue, in: namespace)
    }

    private var ctrlButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                ctrlActive.toggle()
            }
        } label: {
            Text("ctrl")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(ctrlActive ? .white : .primary)
                .frame(width: 44, height: 44)
        }
        .glassEffect(ctrlActive ? .regular.tint(.blue).interactive() : .regular.interactive())
        .glassEffectID("ctrl", in: namespace)
    }

    private var toggleButton: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentTransition(.symbolEffect(.replace))
        }
        .glassEffect(.regular.interactive())
        .glassEffectID("toggle", in: namespace)
    }

    private func handleKeyTap(_ action: KeyAction) {
        switch action {
        case .escape: sendBytes([0x1B])
        case .ctrl: break // Handled separately via ctrlActive state
        case .tab: sendBytes([0x09])
        case .arrowLeft:
            // Ctrl+arrow uses CSI 1;5 modifier sequence
            sendBytes(ctrlActive ? [0x1B, 0x5B, 0x31, 0x3B, 0x35, 0x44] : [0x1B, 0x5B, 0x44])
        case .arrowUp:
            sendBytes(ctrlActive ? [0x1B, 0x5B, 0x31, 0x3B, 0x35, 0x41] : [0x1B, 0x5B, 0x41])
        case .arrowDown:
            sendBytes(ctrlActive ? [0x1B, 0x5B, 0x31, 0x3B, 0x35, 0x42] : [0x1B, 0x5B, 0x42])
        case .arrowRight:
            sendBytes(ctrlActive ? [0x1B, 0x5B, 0x31, 0x3B, 0x35, 0x43] : [0x1B, 0x5B, 0x43])
        }

        // Reset Ctrl modifier after use (standard modifier key behavior)
        if ctrlActive, action != .ctrl {
            withAnimation(.easeInOut(duration: 0.15)) {
                ctrlActive = false
            }
        }

        // Auto-collapse if in collapsed mode
        if mode == .collapsed {
            withAnimation {
                isExpanded = false
            }
        }

        onKeyTap()
    }

    private func sendBytes(_ bytes: [UInt8]) {
        let data = Data(bytes)
        sshService.send(data)
    }
}
