//
//  VoiceFirstKeyboardView.swift
//  VivaDictaKeyboard
//
//  A compact, voice-first keyboard surface for the Typeless-style flow.
//  The extension still uses UITextDocumentProxy for all host-app edits; this
//  view only owns the interaction surface and never touches provider secrets.
//

import SwiftUI
import DesignSystem

struct VoiceFirstKeyboardView: View {
    @Bindable var dictationState: KeyboardDictationState

    let hasFullAccess: Bool
    let canUndo: Bool
    let onMic: () -> Void
    let onUndo: () -> Void
    let onDelete: () -> Void
    let onReturn: () -> Void
    let onSwitchKeyboard: () -> Void
    let onShowFullAccessPrompt: () -> Void

    private var selectedMode: VivaMode {
        dictationState.vivaModeManager.selectedVivaMode
    }

    private var statusTitle: String {
        switch dictationState.uiState {
        case .notReady:
            "打开应用以启动语音"
        case .ready:
            "点击麦克风开始说话"
        case .recording:
            "正在录音"
        case .processing:
            "正在整理文字"
        case .error:
            "语音输入暂不可用"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 8)

            VStack(spacing: 12) {
                VoiceFirstMicButton(
                    state: dictationState.uiState,
                    action: onMic
                )

                Text(statusTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 12)

            actionBar
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("语音输入键盘")
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "waveform")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)

                Text("语音输入")
                    .font(.subheadline.weight(.semibold))
            }

            Spacer(minLength: 8)

            Button {
                cycleMode()
            } label: {
                HStack(spacing: 5) {
                    Text(selectedMode.name)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.thinMaterial, in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(dictationState.vivaModeManager.availableVivaModes.count < 2)
            .accessibilityLabel("当前整理模式")
            .accessibilityValue(selectedMode.name)

            if !hasFullAccess {
                Button(action: onShowFullAccessPrompt) {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .frame(width: 30, height: 30)
                        .background(.orange.opacity(0.12), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("开启完整访问")
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            VoiceFirstActionButton(
                title: "切换",
                systemImage: "globe",
                action: onSwitchKeyboard
            )

            VoiceFirstActionButton(
                title: "撤销",
                systemImage: "arrow.uturn.backward",
                isEnabled: canUndo,
                action: onUndo
            )

            VoiceFirstActionButton(
                title: "换行",
                systemImage: "return",
                action: onReturn
            )

            VoiceFirstActionButton(
                title: "删除",
                systemImage: "delete.backward",
                action: onDelete
            )
        }
    }

    private func cycleMode() {
        let modes = dictationState.vivaModeManager.availableVivaModes
        guard modes.count > 1,
              let currentIndex = modes.firstIndex(where: { $0.id == selectedMode.id }) else {
            return
        }

        HapticManager.selectionChanged()
        let nextIndex = (currentIndex + 1) % modes.count
        dictationState.vivaModeManager.selectedVivaMode = modes[nextIndex]
    }
}

private struct VoiceFirstMicButton: View {
    let state: KeyboardDictationState.UIState
    let action: () -> Void

    private var symbolName: String {
        switch state {
        case .recording:
            "stop.fill"
        case .processing:
            "ellipsis"
        default:
            "mic.fill"
        }
    }

    private var tint: Color {
        switch state {
        case .notReady:
            .secondary
        case .ready:
            .accentColor
        case .recording:
            .red
        case .processing:
            .secondary
        case .error:
            .orange
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 94, height: 94)

                Circle()
                    .fill(tint.gradient)
                    .frame(width: 70, height: 70)
                    .shadow(color: tint.opacity(0.28), radius: 12, y: 6)

                Image(systemName: symbolName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state == .recording ? "停止录音" : "开始语音输入")
    }
}

private struct VoiceFirstActionButton: View {
    let title: String
    let systemImage: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.medium))

                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(isEnabled ? .primary : .tertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(.thinMaterial, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }
}
