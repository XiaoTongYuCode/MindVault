import SwiftUI

/// 呼吸动画背景组件
/// 支持形状、大小、颜色深浅的集体呼吸效果
struct BreathingBackground<S: Shape>: View {
    let shape: S
    let color: Color
    
    // 动画参数配置
    var duration: Double = 2.0
    var minOpacity: Double = 0.1
    var maxOpacity: Double = 0.35
    var minScale: Double = 0.88
    var maxScale: Double = 1.08
    
    // 动画状态
    @State private var opacity: Double = 0.1
    @State private var scale: Double = 1.0
    
    init(
        shape: S,
        color: Color,
        duration: Double = 2.0,
        minOpacity: Double = 0.1,
        maxOpacity: Double = 0.35,
        minScale: Double = 0.88,
        maxScale: Double = 1.08
    ) {
        self.shape = shape
        self.color = color
        self.duration = duration
        self.minOpacity = minOpacity
        self.maxOpacity = maxOpacity
        self.minScale = minScale
        self.maxScale = maxScale
    }
    
    var body: some View {
        shape
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: color.opacity(opacity), location: 0.0),
                        .init(color: color.opacity(opacity * 0.6), location: 0.5),
                        .init(color: color.opacity(opacity * 0.2), location: 1.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
            )
            .scaleEffect(scale)
            .onAppear {
                startBreathingAnimation()
            }
    }
    
    private func startBreathingAnimation() {
        // 初始化状态
        opacity = minOpacity
        scale = minScale
        
        // 启动呼吸动画
        withAnimation(
            Animation.easeInOut(duration: duration)
                .repeatForever(autoreverses: true)
        ) {
            opacity = maxOpacity
            scale = maxScale
        }
    }
}

// MARK: - 便捷初始化方法

extension BreathingBackground where S == Capsule {
    /// 胶囊形状的呼吸背景
    init(
        color: Color,
        duration: Double = 2.0,
        minOpacity: Double = 0.1,
        maxOpacity: Double = 0.35,
        minScale: Double = 0.88,
        maxScale: Double = 1.08
    ) {
        self.init(
            shape: Capsule(),
            color: color,
            duration: duration,
            minOpacity: minOpacity,
            maxOpacity: maxOpacity,
            minScale: minScale,
            maxScale: maxScale
        )
    }
}

extension BreathingBackground where S == RoundedRectangle {
    /// 圆角矩形的呼吸背景
    init(
        cornerRadius: CGFloat,
        style: RoundedCornerStyle = .continuous,
        color: Color,
        duration: Double = 2.0,
        minOpacity: Double = 0.1,
        maxOpacity: Double = 0.35,
        minScale: Double = 0.88,
        maxScale: Double = 1.08
    ) {
        self.init(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: style),
            color: color,
            duration: duration,
            minOpacity: minOpacity,
            maxOpacity: maxOpacity,
            minScale: minScale,
            maxScale: maxScale
        )
    }
}

extension BreathingBackground where S == Circle {
    /// 圆形的呼吸背景
    init(
        color: Color,
        duration: Double = 2.0,
        minOpacity: Double = 0.1,
        maxOpacity: Double = 0.35,
        minScale: Double = 0.88,
        maxScale: Double = 1.08
    ) {
        self.init(
            shape: Circle(),
            color: color,
            duration: duration,
            minOpacity: minOpacity,
            maxOpacity: maxOpacity,
            minScale: minScale,
            maxScale: maxScale
        )
    }
}
