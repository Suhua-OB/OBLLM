//
//  MessageView.swift
//  OBLLM
//
//  Created by 苏华 on 2025/9/19.
//

import SwiftUI

struct MessageView: View {
    let message: Message

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading) {
            MarkdownText(message.content)
                .padding(10)
                .background(message.role == .user ? Color.secondary.opacity(0.5) : Color.secondary.opacity(0.1))
                .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}
