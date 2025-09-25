//
//  ConversationView.swift
//  OBLLM
//
//  Created by 苏华 on 2025/9/19.
//

import SwiftUI

// 用于获取滚动偏移
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ConversationView: View {
    @EnvironmentObject var modelManager: ModelManager
    let messages: [Message]

    @State private var autoScroll: Bool = true
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        MessageView(message: message)
                            .id(message.id)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("Bottom")
                }
                .padding()
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .global).maxY)
                    }
                )
            }
            // 新消息自动滚动到底部
            .onChange(of: messages.count) { _ in
                if autoScroll {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("Bottom", anchor: .bottom)
                    }
                }
            }
            // 手动滚动检测
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                let threshold: CGFloat = 50
                if scrollOffset > value + threshold {
                    autoScroll = false
                } else if value - scrollOffset < threshold {
                    autoScroll = true
                }
                scrollOffset = value
            }
        }

        // 清空按钮
        if !modelManager.messages.isEmpty {
            HStack {
                Button("清空") {
                    modelManager.clearMessages()
                    modelManager.createNewChatSession()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
            .padding(2)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
    }
}
