# OBMLX (Minimal Swift LLM App)

## 目标
- 本地加载 MLX / mlx-swift-examples 转换后的模型目录
- 支持流式生成（AsyncStream）
- 支持 Markdown 渲染聊天内容
- 可扩展到 Siri / Intents

## 结构
```
OBMLX/
├── Assets.xcassets/
│   ├── AccentColor.colorset/
│   ├── AppIcon.appiconset/
│   └── Contents.json
├── Extensions/
│   ├── ChatTextEditor.swift
│   └── Color.swift
├── Managers/
│   └── ModelManager.swift
├── Models/
│   └── Message.swift
├── Resources/
│   └── generate_tokenizer.py
├── Services/
│   └── LocalLLM.swift
├── Views/
│   ├── ContentView.swift
│   ├── ConversationView.swift
│   ├── MarkdownText.swift
│   └── MessageView.swift
└── OBLLMApp.swift
```

### 文件和目录功能说明

- **Assets.xcassets/**: 包含应用的图片和颜色资源
  - **AccentColor.colorset/**: 应用的强调色设置
  - **AppIcon.appiconset/**: 应用图标资源
- **Extensions/**: Swift 扩展文件，用于增强系统类型功能
  - **ChatTextEditor.swift**: 聊天文本编辑器相关的扩展
  - **Color.swift**: 颜色相关的扩展
- **Managers/**: 管理器类，负责管理应用中的复杂逻辑
  - **ModelManager.swift**: 模型管理器，负责模型的加载和管理
- **Models/**: 数据模型定义
  - **Message.swift**: 消息数据模型，定义消息的结构和属性
- **Resources/**: 应用所需的资源文件
  - **generate_tokenizer.py**: Python 脚本，用于生成 tokenizer.json 文件
- **Services/**: 核心服务实现
  - **LocalLLM.swift**: 本地大语言模型服务，负责与 MLX 模型交互
- **Views/**: SwiftUI 视图组件
  - **ContentView.swift**: 主视图，应用的主要界面容器
  - **ConversationView.swift**: 对话视图，显示聊天对话内容
  - **MarkdownText.swift**: Markdown 文本渲染组件
  - **MessageView.swift**: 消息视图，单条消息的显示组件
- **OBLLMApp.swift**: 应用入口文件，SwiftUI 应用的根视图

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
