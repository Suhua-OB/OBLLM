//
//  ContentView.swift
//  OBLLM
//
//  Created by 苏华 on 2025/9/19.
//

import SwiftUI
import UniformTypeIdentifiers


struct ContentView: View {
    @EnvironmentObject var modelManager: ModelManager
    @State private var input: String = ""
    @State private var selectedModelName: String? = nil
    @State private var showSettings = false

    // Alert & File Export
    @State private var showTokenizerAlert = false
    @State private var showFileExporter = false
    @State private var exportScriptFile: ExportFile?
    @State private var exportError: String? = nil
    @State private var showExportSuccess = false
    @State private var exportSuccessMessage = ""

    // iOS/macOS 文件选择
    @State private var showFileImporter = false
    
    @State private var textHeight: CGFloat = 30

    var body: some View {
        
        VStack(spacing: 0) {

            Divider()

            // 聊天窗口
            ConversationView(messages: modelManager.messages)

            Divider()

            // 输入栏
            HStack {
                ChatTextEditor(text: $input,
                                           onSend: sendMessage,
                                           minHeight: 40,
                                           maxHeight: 150,
                                           dynamicHeight: $textHeight)
                                .frame(height: textHeight)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                if modelManager.isGenerating {
                    StopButton(action: modelManager.stopGeneration)
                        .padding(.trailing,-2)
                        .padding(.leading,2)
                }else{
                    Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.primary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing,-4)
                        .onHover { inside in
                            if inside {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                }
                
            }
            .padding()
        }
        // SwiftUI Alert（跨平台，按钮不会透明）
        .alert("缺少 tokenizer.json", isPresented: $showTokenizerAlert) {
            Button("取消", role: .cancel) { }
            Button("下载脚本") {
                exportPythonScript()
            }
        } message: {
            Text("""
            你可以运行 generate_tokenizer.py 来生成 tokenizer.json

            用法:
              python generate_tokenizer.py <模型目录>
            """)
        }
        // 文件导出器
        .fileExporter(
            isPresented: $showFileExporter,
            document: exportScriptFile,
            contentType: .plainText,
            defaultFilename: "generate_tokenizer.py"
        ) { result in
            switch result {
            case .success(let url):
                exportSuccessMessage = "已保存: \(url.lastPathComponent)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    exportSuccessMessage = ""  // ✅ 3秒后自动消失
                }
            case .failure(let error):
                exportError = "保存失败: \(error.localizedDescription)"
            }
        }
        // iOS 文件选择器（目录）
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.folder]
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    modelManager.isLoading = true
                    selectedModelName = nil
                    await modelManager.loadModel(at: url.path)
                    modelManager.isLoading = false
                    if modelManager.modelLoaded {
                        selectedModelName = url.lastPathComponent
                    }
                }
            case .failure(let error):
                print("❌ 文件选择失败: \(error.localizedDescription)")
            }
        }
        .hideToolbarBackground{
            HStack(alignment: .center, spacing: 8) {
                // 状态文字
                if modelManager.isLoading || modelManager.lastError != nil {
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                if let error = modelManager.lastError,
                   error.contains("tokenizer.json") || error.contains("tokenizer") {
                    Button(action: { showTokenizerAlert = true }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.primary)
                    }
                    .onHover{ inside in
                        if inside {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }

                // 状态指示点
                if modelManager.modelLoaded, let name = selectedModelName {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                        .help(name)
                } else {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                }

                // 选择模型按钮
                Button(action: {
                    #if os(macOS)
                    openMacOSFileChooser()
                    #else
                    showFileImporter = true
                    #endif
                }) {
                    Text("选择模型")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.secondary) // 蓝色椭圆背景
                        )
                        .foregroundColor(Color.systemBackground) // 白色文字
                }
                .padding(.leading,-5)
//                .padding(.trailing, 3)
                .fixedSize()
                .onHover { inside in
                    if inside {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                
                Button(action: {
                    showSettings = true
                }) {
                    Text("设置")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.secondary) // 蓝色椭圆背景
                        )
                        .foregroundColor(Color.systemBackground) // 白色文字
                }
                .buttonStyle(.plain)
                .fixedSize()
                .padding(.leading, -5)
                .padding(.trailing, 3)
                .onHover { inside in
                    if inside {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            VStack(spacing: 20) {
                Text("设置")
                    .font(.title2)
                    .padding(.top, 20)
                Text("Prompt")
                TextEditor(text: $modelManager.instructions)
                    .frame(height: 100)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.4)))
                VStack(alignment: .leading) {
                    Text("Temperature: \(String(format: "%.2f", modelManager.generationConfig.temperature))")
                    HStack {
                        Slider(value: $modelManager.generationConfig.temperature, in: 0...2, step: 0.01)
                        TextField("", value: $modelManager.generationConfig.temperature, formatter: NumberFormatter.decimalFormatter)
                            .frame(width: 50)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                VStack(alignment: .leading) {
                    Text("Top P: \(String(format: "%.2f", modelManager.generationConfig.topP))")
                    HStack {
                        Slider(value: $modelManager.generationConfig.topP, in: 0...1, step: 0.01)
                        TextField("", value: $modelManager.generationConfig.topP, formatter: NumberFormatter.decimalFormatter)
                            .frame(width: 50)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                VStack(alignment: .leading) {
                    Text("Max Tokens: \(modelManager.generationConfig.maxTokens)")
                    TextField("", value: $modelManager.generationConfig.maxTokens, formatter: NumberFormatter.integerFormatter)
                        .frame(width: 80)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                Spacer()
                Button("关闭") {
                    showSettings = false
                }
                .padding(.bottom, 20)
            }
            .padding(.leading,20)
            .padding(.trailing,20)
            .frame(minWidth: 300, minHeight: 500)
        }
    }
    
    
    
    // MARK: - 状态显示
    private var statusColor: Color {
        if modelManager.isLoading {
            return .yellow
        } else {
            return modelManager.modelLoaded ? .green : .red
        }
    }

    private var statusText: String {
        if modelManager.isLoading {
            return "加载中..."
        } else if modelManager.modelLoaded, let name = selectedModelName {
            return name
        } else if let error = modelManager.lastError {
            return "加载失败: \(error)"
        } else {
            return "未加载模型"
        }
    }

    // MARK: - 打开文件选择（macOS）
    private func openMacOSFileChooser() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"

        if panel.runModal() == .OK {
            if let url = panel.url {
                Task {
                    modelManager.isLoading = true
                    selectedModelName = nil
                    await modelManager.loadModel(at: url.path)
                    modelManager.isLoading = false
                    if modelManager.modelLoaded {
                        selectedModelName = url.lastPathComponent
                    }
                }
            }
        }
        #endif
    }

    // MARK: - 导出脚本
    private func exportPythonScript() {
        if let scriptURL = Bundle.main.url(forResource: "generate_tokenizer", withExtension: "py"),
           let text = try? String(contentsOf: scriptURL, encoding: .utf8) {
            exportScriptFile = ExportFile(text: text)
            showFileExporter = true
        } else {
            exportError = "找不到 Resources/generate_tokenizer.py"
        }
    }
    
    // MARK: - 发送消息
        private func sendMessage() {
            guard !input.isEmpty else { return }
            modelManager.isGenerating = true;
            modelManager.sendMessage(input)
            input = ""
        }
    
    // MARK: - 清空聊天
    private func clearChat() {
        modelManager.clearMessages()
        modelManager.createNewChatSession()
    }
}

#Preview {
    ContentView().environmentObject(ModelManager())
}

// MARK: - FileDocument 用于导出
struct ExportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String

    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return .init(regularFileWithContents: text.data(using: .utf8)!)
    }
}

extension NumberFormatter {
    static var decimalFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 0
        formatter.maximumFractionDigits = 2
        formatter.maximum = 2
        return formatter
    }
    static var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = 2048
        return formatter
    }
}

extension View {
    @ViewBuilder
    func hideToolbarBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if os(macOS)
        if #available(macOS 26.0, *) {
            self.toolbar {
                ToolbarItem(placement: .automatic) {
                    content()
                }
                .sharedBackgroundVisibility(.hidden)
                
            }
        } else {
            self.toolbar {
                ToolbarItem(placement: .automatic) {
                    content()
                }
            }
            .toolbarBackground(.hidden, for: .windowToolbar)
        }
        #else
        return self
        #endif
    }
}
struct StopButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.primary) // 随系统背景变化
                    .frame(width: 24, height: 24)
                    
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.systemBackground) // 根据模式自动变为黑/白
                    .frame(width: 10, height: 10)
            }
        }
        .buttonStyle(.plain)
        .shadow(radius: 1)
        .onHover { inside in
            if inside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
