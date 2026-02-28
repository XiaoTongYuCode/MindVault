//
//  OpenRouterService.swift
//  Myrisle
//
//  Created by XTY on 2026/2/12.
//

import Foundation

// MARK: - Request Models

/// OpenRouter API 请求消息
struct OpenRouterMessage: Codable {
    let role: String
    let content: String
}

/// OpenRouter API 请求体
struct OpenRouterRequest: Codable {
    let model: String
    let messages: [OpenRouterMessage]
    let stream: Bool
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case temperature
        case maxTokens = "max_tokens"
    }
}

/// OpenRouter API 服务
class OpenRouterService {
    // MARK: - Properties
    
    private let apiKey: String
    private let modelName: String
    private let baseURL = AppConfig.OpenRouter.baseURL
    
    // MARK: - Initialization
    
    init(apiKey: String, modelName: String) {
        self.apiKey = apiKey
        self.modelName = modelName
    }
    
    // MARK: - Public Methods
    
    /// 生成响应（流式输出）
    /// - Parameters:
    ///   - messages: 消息历史
    ///   - onToken: 每收到一个 token 时调用的回调
    /// - Returns: 完整的响应文本
    func generate(messages: [Message], onToken: @escaping (String) -> Void) async throws -> String {
        // 构建请求体
        let requestBody = buildRequestBody(messages: messages, stream: true)
        
        // 创建请求
        guard let url = URL(string: baseURL) else {
            throw OpenRouterError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.OpenRouter.httpReferer, forHTTPHeaderField: "HTTP-Referer")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // 发送请求并处理流式响应
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorData = try await Data(collecting: asyncBytes)
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw OpenRouterError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // 处理流式响应
        var accumulatedResponse = ""
        
        for try await line in asyncBytes.lines {
            // 跳过空行和 data: 前缀
            guard line.hasPrefix("data: ") else { continue }
            
            let jsonString = String(line.dropFirst(6)) // 移除 "data: " 前缀
            
            // 检查是否是结束标记
            if jsonString.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                break
            }
            
            // 解析 JSON
            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let delta = firstChoice["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                continue
            }
            
            // 累积内容并调用回调
            accumulatedResponse += content
            onToken(content)
        }
        
        return accumulatedResponse
    }
    
    /// 生成响应（非流式）
    /// - Parameter messages: 消息历史
    /// - Returns: 完整响应文本
    func generate(messages: [Message]) async throws -> String {
        // 构建请求体
        let requestBody = buildRequestBody(messages: messages, stream: false)
        
        // 创建请求
        guard let url = URL(string: baseURL) else {
            throw OpenRouterError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.OpenRouter.httpReferer, forHTTPHeaderField: "HTTP-Referer")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenRouterError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // 解析响应
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenRouterError.invalidResponse
        }
        
        return content
    }
    
    // MARK: - Private Methods
    
    /// 构建请求体
    private func buildRequestBody(messages: [Message], stream: Bool) -> OpenRouterRequest {
        // 转换消息格式
        let apiMessages = messages.map { message -> OpenRouterMessage in
            OpenRouterMessage(
                role: message.role.rawValue,
                content: message.content
            )
        }
        
        return OpenRouterRequest(
            model: modelName,
            messages: apiMessages,
            stream: stream,
            temperature: AppConfig.OpenRouter.defaultTemperature,
            maxTokens: AppConfig.OpenRouter.defaultMaxTokens
        )
    }
}

// MARK: - OpenRouter Errors

enum OpenRouterError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .apiError(let statusCode, let message):
            return "API 错误 (状态码: \(statusCode)): \(message)"
        case .decodingError:
            return "响应解析失败"
        }
    }
}

// MARK: - AsyncSequence Extension for Data Collection

extension AsyncSequence where Element == UInt8 {
    func collect() async throws -> Data {
        var data = Data()
        for try await byte in self {
            data.append(byte)
        }
        return data
    }
}

// MARK: - Data Extension for AsyncBytes

extension Data {
    init(collecting asyncBytes: URLSession.AsyncBytes) async throws {
        self.init()
        for try await byte in asyncBytes {
            self.append(byte)
        }
    }
}
