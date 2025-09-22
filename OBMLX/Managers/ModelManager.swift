//
//  ModelManager.swift
//  OBLLM
//
//  Created by 苏华 on 2025/9/19.
//
import Foundation
import Combine
import MLXLMCommon

@MainActor
class ModelManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading: Bool = false
    @Published var modelLoaded: Bool = false
    @Published var lastError: String? = nil   // ⬅️ 新增：保存错误信息
    
    @Published var isModelLoading = false   // 专门表示模型是否在加载
    @Published var isGenerating = false     // 表示是否正在生成回答
    
    @Published var instructions: String = "You are a helpful assistant."
    @Published var generateParameters: GenerateParameters = .init()
    @Published var generationConfig: GenerationConfig = .init()

    private var llm = LocalLLM()

    func loadModel(at path: String) async {
        do {
            lastError = nil
            try await llm.loadModel(at: URL(fileURLWithPath: path))
            modelLoaded = true
        } catch {
            modelLoaded = false
            lastError = error.localizedDescription   // ⬅️ 保存错误
            print("❌ 模型加载失败: \(error)")
        }
    }

    func sendMessage(_ text: String) {
        let userMessage = Message(role: .user, content: text)
        messages.append(userMessage)

        Task {
            defer {
                // 相当于 finally，这里一定会执行
                isGenerating = false
            }

            
            var assistantMessage = Message(role: .assistant, content: "")
            messages.append(assistantMessage)

            do {
                for try await token in llm.generateStream(input: text) {
                    assistantMessage.content += token
                    messages[messages.count - 1] = assistantMessage
                }
            } catch {
                assistantMessage.content = "❌ 错误: \(error.localizedDescription)"
                messages[messages.count - 1] = assistantMessage
            }
        }
    }
    
    func stopGeneration() {
        llm.stopGenerate()
    }

    /// 清空消息列表
    func clearMessages() {
        messages = []
    }

    /// 创建新的对话会话，重置模型状态
    func createNewChatSession() {
        messages = []
        isGenerating = false
        // 如果 LocalLLM 支持 session 重置，可在此调用
        llm.newSession()
    }
    
    func updateInstructions(_ text: String) {
        instructions = text
        UserDefaults.standard.set(text, forKey: "OBMLX.instructions")
    }

    func updateConfig(_ config: GenerationConfig) {
        // 更新并持久化
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "OBMLX.generationConfig")
        }

        // 转换成 MLX 的 GenerateParameters 交给 LLM
        generateParameters = GenerateParameters(
            maxTokens: config.maxTokens,
            temperature: config.temperature,
            topP: config.topP
        )
    }
    
    func loadSavedConfig() {
        if let text = UserDefaults.standard.string(forKey: "OBMLX.instructions") {
            instructions = text
        }
        if let data = UserDefaults.standard.data(forKey: "OBMLX.generationConfig"),
           let config = try? JSONDecoder().decode(GenerationConfig.self, from: data) {
            generationConfig = config
            updateConfig(config)
        }
    }
}

struct GenerationConfig: Codable {
    var maxTokens: Int
    var temperature: Float
    var topP: Float
    
    init(maxTokens: Int = 512, temperature: Float = 0.7, topP: Float = 0.9) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
    }
}
