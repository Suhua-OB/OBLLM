//
//  MarkdownView.swift
//  OBLLM
//
//  Created by 苏华 on 2025/9/19.
//

import SwiftUI
import MarkdownUI

struct MarkdownText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Markdown(text)
            .textSelection(.enabled) // 支持复制
    }
}
