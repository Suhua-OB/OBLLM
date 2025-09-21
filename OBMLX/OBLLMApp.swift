//
//  OBLLMApp.swift
//  OBLLM
//
//  Created by 苏华 on 2025/9/19.
//

import SwiftUI

@main
struct OBLLMApp: App {
    @StateObject private var modelManager = ModelManager()

        var body: some Scene {
            WindowGroup {
                ContentView()
                    .environmentObject(modelManager)
            }
        }
}
