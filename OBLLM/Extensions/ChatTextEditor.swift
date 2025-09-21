//
//  ChatTextEditor.swift
//  OBLLM
//
//  Created by 苏华 on 2025/9/21.
//

import SwiftUI

#if os(iOS)
import UIKit
struct ChatTextEditor: UIViewRepresentable {
    @Binding var text: String
    var onSend: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 15)
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.returnKeyType = .send   // ⌨️ 显示发送按钮
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: ChatTextEditor
        init(_ parent: ChatTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            if text == "\n" {
                parent.onSend()
                return false // 拦截默认换行
            }
            return true
        }
    }
}
#endif

#if os(macOS)
import AppKit
struct ChatTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onSend: () -> Void
    var minHeight: CGFloat = 30
    var maxHeight: CGFloat = 150
    @Binding var dynamicHeight: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 15)
        textView.delegate = context.coordinator
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 4, height: 6)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        if let textView = scrollView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
            context.coordinator.recalculateHeight(textView: textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatTextEditor

        init(_ parent: ChatTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                parent.text = textView.string
                recalculateHeight(textView: textView)
            }
        }

        // ←—— 正确的方法签名（注意：没有 override）
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    // Shift+Enter => 插入换行（不拦截，系统会处理）
                    return false
                } else {
                    // Enter => 发送（拦截）
                    parent.onSend()
                    return true
                }
            }
            return false
        }

        func recalculateHeight(textView: NSTextView) {
            guard let textContainer = textView.textContainer,
                  let layoutManager = textView.layoutManager else { return }

            let used = layoutManager.usedRect(for: textContainer).size
            let newHeight = min(max(used.height + textView.textContainerInset.height * 2, parent.minHeight), parent.maxHeight)

            if abs(parent.dynamicHeight - newHeight) > 1 {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = newHeight
                }
            }
        }
    }
}
#endif
