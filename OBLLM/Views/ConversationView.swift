//
//  ConversationView.swift
//  OBLLM
//
//  Created by 苏华 on 2025/9/19.
//

import SwiftUI

struct ConversationView: View {
    @EnvironmentObject var modelManager: ModelManager
    let messages: [Message]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages) { message in
                    MessageView(message: message)
                }
            }
            .padding()
        }
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
                    if inside {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(2)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
    }
}
