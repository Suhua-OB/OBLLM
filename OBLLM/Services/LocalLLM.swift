//
//  LocalLLM.swift
//  OBLLM
//
//  Created by 苏华 on 2025/9/19.
//

import Foundation
import MLX
import MLXLMCommon

@MainActor
class LocalLLM {
    private var context: ModelContext?
    private var chatSession: ChatSession?

    // 当前生成任务与流的 continuation（只保留一个生成会话）
    private var generateTask: Task<Void, Never>?
    private var streamContinuation: AsyncThrowingStream<String, Error>.Continuation?

    func loadModel(at url: URL) async throws {
        context = try await MLXLMCommon.loadModel(directory: url)
    }

    /// 流式生成（外层调用者用 `for try await token in llm.generateStream(...)`）
    func generateStream(prompt: String, maxTokens: Int = 128) -> AsyncThrowingStream<String, Error> {
        guard let context = context else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: NSError(domain: "LocalLLM",
                                                     code: -1,
                                                     userInfo: [NSLocalizedDescriptionKey: "模型未加载"]))
            }
        }

        // 如果已有未结束的流，先结束它（防止并发多个流）
        // 注意：因为我们在 @MainActor，直接操作属性是安全的
        if let t = generateTask {
            t.cancel()
            generateTask = nil
        }
        if let oldCont = streamContinuation {
            oldCont.finish()
            streamContinuation = nil
        }

        return AsyncThrowingStream { continuation in
            // 保存 continuation，以便 stopGenerate() 能直接注入消息
            self.streamContinuation = continuation

            // 在 continuation 被外部取消/终止时做清理
            continuation.onTermination = { @Sendable termination in
                Task { @MainActor in
                    self.streamContinuation = nil
                    self.generateTask?.cancel()
                    self.generateTask = nil
                }
            }

            // 启动生成任务
            self.generateTask = Task {
                do {
                    if self.chatSession == nil {
                        self.chatSession = ChatSession(context)
                    }
                    let session = self.chatSession!
                    for try await token in session.streamResponse(to: prompt) {
                        // 如果任务被取消，退出循环（但不要依赖抛出）
                        if Task.isCancelled { break }
                        continuation.yield(token)
                    }
                    // 正常结束
                    continuation.finish()
                } catch is CancellationError {
                    // 有时会进入这里；如果我们想在这里也注入提示，可以，但更可靠的做法是由 stopGenerate 主动注入
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }

                // 最终清理（确保状态被重置）
                await MainActor.run {
                    self.generateTask = nil
                    self.streamContinuation = nil
                }
            }
        }
    }

    /// 停止生成：取消 task，并向前端注入一条 Markdown 提示，然后结束流
    func stopGenerate() {
        // 取消正在执行的 Task（如果有）
        generateTask?.cancel()
        generateTask = nil

        // 主动向流注入 markdown 提示（如果流还存在）
        if let cont = streamContinuation {
            // 推送一条便于 markdown 渲染的通知
            cont.yield("\n\n> ⚠️ 用户已停止生成\n")
            cont.finish()
            streamContinuation = nil
        }
    }

    func newSession() {
        chatSession = nil
    }
}
