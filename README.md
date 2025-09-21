# OBMLX (Minimal Swift LLM App)

## 目标
- 本地加载 MLX / mlx-swift-examples 转换后的模型目录
- 支持流式生成（AsyncStream）
- 支持 Markdown 渲染聊天内容
- 可扩展到 Siri / Intents

## 先决条件
- Xcode 15+（建议）或 Swift toolchain 支持 `AttributedString(markdown:)` 和 Swift Concurrency
- 模型目录需包含 `config.json`、`tokenizer.json`、safetensors 权重等
- 若无 `tokenizer.json`，请用 Python 的 `transformers` 导出（见 conversation 中提供的脚本）

## 如何运行（macOS）
1. 在 Xcode 新建一个 macOS App，或用 SwiftPM 将 Sources 目录作为可执行目标
2. 把项目的 Package.swift 中加入你本地的 MLX 相关依赖（若需要）
3. 在 `LocalLLM.swift` 中用你的 MLX API 替换 `TODO` 部分
4. 运行 app，左侧选择模型目录，点击加载，再在聊天框输入并发送

## 注意
- `LocalLLM.generateStream` 目前为模拟实现。如果 MLX 提供 token-by-token 回调，请将回调中每个 token `yield` 到 AsyncStream。
- 保证模型目录内包含 `tokenizer.json`（若没有，使用 Python 导出）
