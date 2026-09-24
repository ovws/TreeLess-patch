//
//  RecordingStateView.swift
//  VivaDictaKeyboard
//

import SwiftUI
import DesignSystem

struct RecordingStateView: View {
    @Bindable var dictationState: KeyboardDictationState
    let onBackspace: () -> Void
    let onDeleteWord: () -> Void
    let onNewline: () -> Void
    let onSpace: () -> Void

    @State private var recordingStartDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(.red)
                        .frame(width: 9, height: 9)

                    Text("正在录音")
                        .font(.subheadline.weight(.semibold))
                }

                Spacer(minLength: 8)

                Text(dictationState.vivaModeManager.selectedVivaMode.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.thinMaterial, in: .capsule)

                Button {
                    HapticManager.lightImpact()
                    dictationState.requestCancelRecording()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(.thinMaterial, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("取消录音")
            }

            Spacer(minLength: 12)

            ZStack {
                Circle()
                    .fill(.red.opacity(0.12))
                    .frame(width: 118, height: 118)

                Circle()
                    .fill(.red.gradient)
                    .frame(width: 82, height: 82)
                    .shadow(color: .red.opacity(0.25), radius: 14, y: 7)
                    .scaleEffect(1 + min(dictationState.currentAudioLevel, 1) * 0.12)
                    .animation(.easeOut(duration: 0.1), value: dictationState.currentAudioLevel)

                Image(systemName: "waveform")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Text(recordingStartDate, style: .timer)
                .font(.title.monospacedDigit().weight(.medium))
                .foregroundStyle(.primary)
                .padding(.top, 12)

            Text("说完后点击完成，文字会自动插入当前输入框")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            Spacer(minLength: 12)

            Button {
                HapticManager.mediumImpact()
                dictationState.requestStopRecording()
            } label: {
                Label("完成", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(.red.gradient, in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("完成录音")

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                recordingUtilityButton(icon: "space", action: onSpace)
                recordingUtilityButton(icon: "return", action: onNewline)
                recordingUtilityButton(icon: "delete.backward", action: onBackspace, longHoldAction: onDeleteWord)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear {
            recordingStartDate = Date()
        }
    }

    @ViewBuilder
    private func recordingUtilityButton(
        icon: String,
        action: @escaping () -> Void,
        longHoldAction: (() -> Void)? = nil
    ) -> some View {
        RepeatableButton(action: action, longHoldAction: longHoldAction) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(.thinMaterial, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RecordingStateView(
        dictationState: KeyboardDictationState(),
        onBackspace: {},
        onDeleteWord: {},
        onNewline: {},
        onSpace: {}
    )
}
