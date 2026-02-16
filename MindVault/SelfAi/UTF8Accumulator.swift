//
//  UTF8Accumulator.swift
//  MindVault
//
//  Created by XTY on 2026/2/12.
//

import Foundation

/// UTF-8 字节累积器，用于正确处理多字节字符（如中文），防止流式输出时出现乱码块
class UTF8Accumulator {
    private var buffer: [UInt8] = []
    
    /// 追加字节并尝试解码完整的 UTF-8 字符
    /// - Parameter bytes: 要追加的字节数组
    /// - Returns: 解码后的字符串（如果有完整的字符），否则返回 nil
    func append(_ bytes: [UInt8]) -> String? {
        buffer.append(contentsOf: bytes)
        
        // 尝试解码完整的 UTF-8 字符
        var result = ""
        var validEndIndex = 0
        
        var i = 0
        while i < buffer.count {
            let byte = buffer[i]
            
            // 判断 UTF-8 字符的字节数
            let charLength: Int
            if byte & 0x80 == 0 {
                charLength = 1  // ASCII
            } else if byte & 0xE0 == 0xC0 {
                charLength = 2
            } else if byte & 0xF0 == 0xE0 {
                charLength = 3
            } else if byte & 0xF8 == 0xF0 {
                charLength = 4
            } else {
                // 无效的起始字节，跳过
                i += 1
                continue
            }
            
            // 检查是否有足够的字节
            if i + charLength > buffer.count {
                break  // 等待更多字节
            }
            
            // 验证后续字节是否有效（必须以 10 开头）
            var isValid = true
            for j in 1..<charLength {
                if i + j >= buffer.count {
                    isValid = false
                    break
                }
                if (buffer[i + j] & 0xC0) != 0x80 {
                    isValid = false
                    break
                }
            }
            
            if isValid {
                // 提取完整的字符
                let charBytes = Array(buffer[i..<i+charLength])
                if let char = String(bytes: charBytes, encoding: .utf8) {
                    result += char
                    validEndIndex = i + charLength
                } else {
                    // 解码失败，跳过这个字节
                    i += 1
                    continue
                }
                i += charLength
            } else {
                // 无效的 UTF-8 序列，跳过起始字节
                i += 1
            }
        }
        
        // 移除已处理的字节
        if validEndIndex > 0 {
            buffer.removeFirst(validEndIndex)
        }
        
        return result.isEmpty ? nil : result
    }
    
    /// 刷新累积器，尝试解码剩余的字节（可能是不完整的）
    /// - Returns: 解码后的字符串，如果没有剩余字节或解码失败则返回 nil
    func flush() -> String? {
        // 尝试解码剩余字节（可能是不完整的）
        if buffer.isEmpty {
            return nil
        }
        if let remaining = String(bytes: buffer, encoding: .utf8) {
            buffer.removeAll()
            return remaining
        }
        buffer.removeAll()
        return nil
    }
}
