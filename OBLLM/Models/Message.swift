//
//  Message.swift
//  OBLLM
//
//  Created by 苏华 on 2025/9/19.
//

import Foundation

struct Message: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    var content: String
}
