import SwiftUI

/// 数字滚动动画视图：从 0 平滑滚动到目标数值
/// 支持自定义格式、字体、颜色等样式
struct CountUpView: View {
    /// 目标数值
    let targetValue: Double
    /// 数值格式字符串（如 "%+.2f", "%.0f"）
    let format: String
    /// 字体
    let font: Font
    /// 文字颜色
    let foregroundColor: Color
    /// 动画持续时间（秒）
    let duration: Double
    /// 是否在出现时自动开始动画
    let autoStart: Bool
    
    @State private var currentValue: Double = 0
    @State private var animationStartTime: Date?
    @State private var animationStartValue: Double = 0
    @State private var animationTargetValue: Double = 0
    @State private var timer: Timer?
    
    init(
        targetValue: Double,
        format: String = "%.2f",
        font: Font = .system(size: 38, weight: .bold),
        foregroundColor: Color = MVTheme.primary,
        duration: Double = 1.5,
        autoStart: Bool = true
    ) {
        self.targetValue = targetValue
        self.format = format
        self.font = font
        self.foregroundColor = foregroundColor
        self.duration = duration
        self.autoStart = autoStart
    }
    
    var body: some View {
        Text(String(format: format, currentValue))
            .font(font)
            .foregroundColor(foregroundColor)
            .onAppear {
                if autoStart {
                    startAnimation(to: targetValue)
                }
            }
            .onChange(of: targetValue) { oldValue, newValue in
                // 当目标值改变时，从当前值开始动画到新值
                startAnimation(to: newValue)
            }
            .onDisappear {
                stopAnimation()
            }
    }
    
    private func startAnimation(to endValue: Double) {
        // 停止之前的动画
        stopAnimation()
        
        let startValue = currentValue
        let difference = endValue - startValue
        
        // 如果差值很小，直接设置目标值
        guard abs(difference) > 0.001 else {
            currentValue = endValue
            return
        }
        
        animationStartValue = startValue
        animationTargetValue = endValue
        animationStartTime = Date()
        
        // 使用定时器实现平滑的数字滚动（60 FPS）
        let startVal = animationStartValue
        let targetVal = animationTargetValue
        let diff = difference
        let animDuration = duration
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            guard let startTime = self.animationStartTime else {
                timer.invalidate()
                return
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / animDuration, 1.0)
            
            // 使用缓动函数（easeOutCubic）使动画更自然
            let easedProgress = self.easeOutCubic(progress)
            self.currentValue = startVal + diff * easedProgress
            
            if progress >= 1.0 {
                self.currentValue = endValue
                timer.invalidate()
                self.timer = nil
            }
        }
        
        // 确保定时器在主运行循环中运行
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 缓动函数：easeOutCubic，使动画开始快，结束时慢
    private func easeOutCubic(_ t: Double) -> Double {
        let t1 = t - 1
        return t1 * t1 * t1 + 1
    }
}

// MARK: - 便捷初始化方法

extension CountUpView {
    /// 创建带符号的数值滚动视图（如 +1.23 或 -0.45）
    static func signed(
        targetValue: Double,
        decimals: Int = 2,
        font: Font = .system(size: 38, weight: .bold),
        foregroundColor: Color = MVTheme.primary,
        duration: Double = 1.5
    ) -> CountUpView {
        CountUpView(
            targetValue: targetValue,
            format: "%+.\(decimals)f",
            font: font,
            foregroundColor: foregroundColor,
            duration: duration
        )
    }
    
    /// 创建整数滚动视图
    static func integer(
        targetValue: Double,
        font: Font = .system(size: 38, weight: .bold),
        foregroundColor: Color = MVTheme.primary,
        duration: Double = 1.5
    ) -> CountUpView {
        CountUpView(
            targetValue: targetValue,
            format: "%.0f",
            font: font,
            foregroundColor: foregroundColor,
            duration: duration
        )
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 30) {
        CountUpView.signed(
            targetValue: 1.23,
            decimals: 2
        )
        
        CountUpView.signed(
            targetValue: -0.45,
            decimals: 2
        )
        
        CountUpView.integer(
            targetValue: 100
        )
        
        CountUpView(
            targetValue: 99.99,
            format: "%.2f",
            font: .system(size: 24, weight: .medium),
            foregroundColor: .blue
        )
    }
    .padding()
}
