//
//  SpeechRecognizer.swift
//  MindVault
//
//  Created by XTY on 2026/2/12.
//

import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
class SpeechRecognizer: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var isStoppingManually = false // 标记是否是用户主动停止
    
    override init() {
        // 根据当前语言环境设置识别器（必须在 super.init() 之前初始化所有 let 属性）
        let locale = AppConfig.isEnglish ? Locale(identifier: "en-US") : Locale(identifier: "zh-CN")
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        super.init()
        
        self.speechRecognizer?.delegate = self
        
        // 检查授权状态
        self.authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }
    
    /// 请求语音识别权限
    func requestAuthorization() async {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume()
                }
            }
        }
    }
    
    /// 开始语音识别
    func startRecording() async throws {
        // 检查授权状态
        if authorizationStatus == .notDetermined {
            await requestAuthorization()
        }
        
        guard authorizationStatus == .authorized else {
            throw SpeechError.authorizationDenied
        }
        
        // 停止之前的任务
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.unableToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // 配置音频引擎
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // 开始识别任务
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    // 如果是用户主动停止导致的取消错误，忽略它
                    if self.isStoppingManually {
                        // 用户主动停止，忽略取消错误
                        return
                    }
                    
                    // 检查是否是取消错误（无论是手动还是自动取消）
                    let nsError = error as NSError
                    let errorDescription = error.localizedDescription.lowercased()
                    
                    // 检查是否是取消相关的错误
                    if errorDescription.contains("cancel") || 
                       (nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216) {
                        // 这是取消错误，如果是手动停止就忽略，否则正常停止
                        self.stopRecording()
                        return
                    }

                    print("SpeechRecognizer error: \(error.localizedDescription)")
                    print("Error domain: \((error as NSError).domain), code: \((error as NSError).code)")
                    self.stopRecording()
                    return
                }
                
                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                    
                    // 如果识别完成
                    if result.isFinal {
                        self.stopRecording()
                    }
                }
            }
        }
        
        isRecording = true
        errorMessage = nil
    }
    
    /// 停止语音识别
    func stopRecording() {
        // 标记为手动停止，避免显示取消错误
        isStoppingManually = true
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
        
        // 重置音频会话
        try? AVAudioSession.sharedInstance().setActive(false)
        
        // 延迟重置标志，确保错误回调能够检查到
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            self.isStoppingManually = false
        }
    }
    
    /// 清除识别的文本
    func clearText() {
        recognizedText = ""
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension SpeechRecognizer: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            // 静默处理，不显示错误信息
            // if !available {
            //     errorMessage = "Speech recognition is not available"
            // }
        }
    }
}

// MARK: - SpeechError
enum SpeechError: LocalizedError {
    case authorizationDenied
    case unableToCreateRequest
    case audioEngineError(Error)
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Speech recognition authorization denied"
        case .unableToCreateRequest:
            return "Unable to create recognition request"
        case .audioEngineError(let error):
            return "Audio engine error: \(error.localizedDescription)"
        }
    }
}
