# VivaDicta → Typeless 风格语音输入客户端架构分析

> WK-189 第一阶段审计。本文档记录当前 VivaDicta 的可复用边界、需要改造的边界，以及第一版语音键盘的落地顺序。目标是先建立“录音 → ASR → AI 整理 → 插入当前输入框”的稳定闭环，再逐步裁剪与重做界面。

## 1. 目标架构

```text
┌──────────────────────────────────────────────────────────────┐
│ iOS Host App / 任意输入框                                    │
│  └─ VivaDictaKeyboard: Mic / Delete / Return / Undo / 切换键盘 │
└───────────────────────┬──────────────────────────────────────┘
                        │ Darwin Notification + App Group
┌───────────────────────▼──────────────────────────────────────┐
│ VivaDicta 主 App                                             │
│  AudioRecording → TranscriptionKit → AIKit → AppGroupBridge │
│        │              │                  │                  │
│      WAV/PCM       ASR Provider       AI Polish              │
│                    ├─ Whisper/Parakeet                       │
│                    ├─ OpenAI/Groq/Custom                     │
│                    ├─ Volcengine（极速版直连已接入）          │
│                    └─ GLM-ASR（兼容路径已接入）               │
└───────────────────────┬──────────────────────────────────────┘
                        │ Raw Transcript 必须始终可用
┌───────────────────────▼──────────────────────────────────────┐
│ KeyboardDictationState → TextDocumentProxy.insertText()      │
└──────────────────────────────────────────────────────────────┘
```

核心原则：Keyboard Extension 不持有 API Key，不重复实现录音和网络请求；主 App 负责音频会话、ASR、AI 和 Keychain，键盘只负责交互、状态显示和向当前输入框插入最终文本。

## 2. 当前仓库审计

| 能力 | 当前实现 | 处理结论 |
|---|---|---|
| Keyboard Extension | `VivaDictaKeyboard/`，KeyboardKit + SwiftUI | 保留，重做为语音优先布局 |
| 录音 | `AudioRecording`、`AudioPrewarmManager`、`RecordViewModel` | 保留，不重复造录音栈 |
| App Group / IPC | `Modules/AppGroup`、`AppGroupBridge`、Darwin Notifications | 保留，作为键盘与主 App 的唯一通信边界 |
| API Key | `Modules/Keychain`、`DefaultKeychainService` | 保留；所有新 Provider 只通过 Keychain 读取 |
| 本地 ASR | WhisperKit、Parakeet | 保留，作为低成本/离线路径 |
| 云端 ASR | OpenAI、Groq、Deepgram、Gemini、Soniox 等 | 保留现有 Provider 路由，统一第一版设置入口 |
| OpenAI-Compatible | `CustomTranscriptionService`、`CustomOpenAIService`、AI Provider Registry | 保留并收敛配置模型，补齐统一 endpoint 语义 |
| AI 整理 | `AIService`、`AIKit`、`PromptsTemplates`、多个 Provider | 保留；键盘默认使用轻量 Polish preset |
| Raw Transcript fallback | `RecordViewModel` 已在 enhancement 失败/取消时保存原文 | 保留机制，补充键盘路径的明确 fallback 测试 |
| 历史记录 | SwiftData `Transcription` / variations / Recent Notes | 保留最小历史能力；隐藏复杂 Notes UI |
| RAG / Chat / Smart Search | `Services/RAG`、`Views/Chat`、`Views/SmartSearch` | 第一版从语音输入主流程移除入口，暂不删除底层代码 |
| Watch / Widget / Share / Action | 独立扩展和 App Intents | 第一版不进入键盘交互，后续再决定是否裁剪 target |
| Volcengine ASR | 当前 Provider 枚举中未发现独立实现 | 已通过自定义模型的官方极速版 JSON 适配接入；标准版 submit/query 仍待补 |
| GLM-ASR | 当前 Provider 枚举中未发现独立实现 | 已通过 `CustomTranscriptionService` 的 multipart 兼容路径接入，并提供快速配置 |

## 3. 可保留 / 需修改 / 可删除入口

### 可保留

- `Modules/AppGroup/Sources/AppGroup/AppGroupCoordinator.swift`
- `VivaDicta/Services/AppGroupBridge.swift`
- `VivaDicta/Services/AudioPrewarmManager.swift`
- `VivaDicta/Views/RecordViewModel.swift`
- `Modules/TranscriptionKit`、`Modules/CloudTranscription`、`Modules/LocalTranscription`
- `Modules/AIKit`、`Modules/AIProviders`、`VivaDicta/Services/AIEnhance/AIService.swift`
- `Modules/Keychain`
- SwiftData 历史记录模型和已有测试

### 需修改

- `VivaDictaKeyboard/KeyboardCustomView.swift`：从完整 QWERTY 键盘默认态切换为语音优先控制面板。
- `VivaDictaKeyboard/KeyboardViewController.swift`：保留 `TextDocumentProxy` 插入逻辑，压缩 toolbar 和 mode 交互。
- `VivaDictaKeyboard/KeyboardDictationState.swift`：补齐“录音中 / ASR / AI Polish / fallback / 完成”的稳定状态和可观察错误。
- `VivaDictaKeyboard/Views/RecordingStateView.swift`、`ProcessingStateView.swift`：统一 Typeless 风格的轻量视觉状态。
- `VivaDicta/Views/SettingsScreen/SettingsView.swift` 与 Provider 配置：第一版只展示 ASR、AI Polish、语言、Keychain 和键盘开关。
- `VivaDicta/Models/TranscriptionModelProvider.swift`：第一版通过 Custom 映射 Volcengine/GLM-ASR；是否拆成独立枚举留到标准版协议稳定后。

### 暂不删除，只移出第一版入口

- Notes、RAG、Chat、Smart Search、Reminders、Live Translation。
- Watch、Widget、Share、Action 等外围扩展。

这样可以先保证可编译和可回退，避免为了目录清理破坏成熟的 CloudKit、App Group 或 App Intents 架构。

## 4. 端到端状态流

1. 键盘加载后读取 App Group 的键盘 session 和当前 `VivaMode`。
2. 用户点击 Mic；键盘发送 `requestStartRecording`，不接触 API Key。
3. 主 App 通过 `AudioPrewarmManager` 建立音频会话并录音。
4. 停止录音后，`TranscriptionKit` 选择当前 ASR Provider，先写入 raw transcript。
5. 若开启 AI Polish，状态变为 enhancing；AI 成功则使用整理文本，失败或超时则使用 raw transcript。
6. 主 App 通过 App Group 写入结果并发送 `transcriptionCompleted`。
7. Keyboard 接收结果，用 `TextInsertionFormatter` 做上下文格式化，调用 `textDocumentProxy.insertText`。
8. 无论 AI 成功与否，用户都必须获得可插入文本；只在完全无法完成 ASR 时显示错误。

## 5. 第一版实施顺序

### Phase 1：稳定语音闭环

- 新增语音优先键盘控制面板。
- 保留 Mic、Delete、Return、切换键盘、Undo 五个核心操作。
- 复用现有录音、IPC、ASR、AI、Keychain 和插入逻辑。
- 增加状态文案和 raw transcript fallback 测试。

### Phase 2：统一 Provider 配置

- 抽象 `SpeechRecognitionProvider` 和 `AIProvider` 的最小配置协议。
- 将 Volcengine、GLM-ASR、OpenAI/Groq、Custom OpenAI-Compatible、本地 Whisper 映射到同一设置模型。
- 将 DeepSeek、OpenAI、Gemini、Custom OpenAI-Compatible 映射到同一 AI Polish 模型。
- 所有密钥继续只存 Keychain，UserDefaults 只保存 provider、model、endpoint 和非敏感开关。

### Phase 3：简化主 App

- Main App 首屏聚焦“一键录音、最近结果、Provider 设置”。
- 将 Notes、RAG、Chat、Watch 入口移入 Advanced 或后续版本。
- 中文优先提供简体中文、English、Auto Detect 三种语言选项。

### Phase 4：验证与性能

- Build 主 App 和 Keyboard target。
- 测试微信、Safari、Notes、Messages、ChatGPT 输入框。
- 验证首次录音、session 超时、AI 失败 fallback、无 Full Access、切换键盘和取消录音。
- 对录音启动和 Provider 初始化做预热，避免第一次点击无反馈。

## 6. 本次已落地

- `VivaDictaKeyboard/VoiceFirstKeyboardView.swift`：默认态改为语音优先控制面板，保留 Mic、Delete、Return、切换键盘、Undo。
- `KeyboardViewController`：记录最近一次插入文本，只有当前输入框仍以该文本结尾时才允许撤销，避免误删后续输入。
- `RecordingStateView` / `ProcessingStateView`：录音、识别、AI 整理状态统一为中文优先的轻量界面。
- `TranscriptDeliveryPolicy`：AI 整理失败、空结果或超时都回退到 Raw Transcript，再交给键盘插入。
- 自定义转写配置增加 GLM-ASR 快速配置；`CustomTranscriptionService` 对 `glm-asr-*` 使用其 multipart 请求字段，不发送不兼容的 Whisper 参数。
- 自定义转写配置增加火山引擎极速版快速配置；适配官方 JSON 请求、`X-Api-Key`、资源 ID 和任务请求头。
- 自定义 AI 配置增加 DeepSeek 快速配置，仍复用 OpenAI-Compatible 路由，密钥继续由 Keychain 管理。

## 7. 未在本批次强行实现的项

- 火山引擎标准版仍使用独立的鉴权与 submit/query 生命周期，本批次接入的是官方极速版单请求接口；旧版控制台的 App ID + Access Token 兼容和标准版任务轮询仍待补。
- 主 App 首屏和 Settings 的进一步裁剪仍待下一批次；本批次先保证现有成熟录音、App Group、历史和 Provider 路由不被破坏。

## 8. 当前风险

- 本工作区是 Linux，未安装 Xcode / Swift toolchain，无法在本地运行 `xcodebuild` 或 iOS Simulator；最终 Build 必须在 macOS/Xcode 环境执行。
- VivaDicta 使用 Swift 6.2、iOS 18+，新增代码必须遵守严格并发和现有 SwiftUI 约束。
- iOS Keyboard Extension 的 API Key、网络请求和录音权限不能直接迁移到扩展，必须维持 App Group handoff。
- App Group 和 SwiftData/CloudKit schema 不应在本阶段随意改动。
