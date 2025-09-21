//
//  Color.swift
//  OBLLM
//
//  Created by 苏华 on 2025/9/19.
//

import SwiftUI

extension Color {
    static var systemBackground: Color {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
}
