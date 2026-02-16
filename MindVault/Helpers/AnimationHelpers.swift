import SwiftUI

/// 动画工具类：提供统一的动画配置和效果
struct AnimationHelpers {
    /// 丝滑的缓动动画
    static let smoothEaseOut = Animation.easeOut(duration: 0.35)
    static let smoothEaseInOut = Animation.easeInOut(duration: 0.4)
    static let smoothSpring = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.25)
    
    /// 快速响应动画
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    /// 列表项出现动画
    static let listItemAppear = Animation.easeOut(duration: 0.3)
    
    /// 页面过渡动画
    static let pageTransition = Animation.easeInOut(duration: 0.35)
}

/// 视图出现动画修饰符
struct FadeInModifier: ViewModifier {
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(AnimationHelpers.smoothSpring) {
                    isVisible = true
                }
            }
    }
}

/// 列表项动画修饰符
struct ListItemAnimationModifier: ViewModifier {
    let index: Int
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(x: isVisible ? 0 : -30)
            .onAppear {
                withAnimation(
                    AnimationHelpers.listItemAppear
                        .delay(Double(index) * 0.05)
                ) {
                    isVisible = true
                }
            }
    }
}

/// 缩放出现动画修饰符
struct ScaleInModifier: ViewModifier {
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1 : 0.8)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(AnimationHelpers.smoothSpring) {
                    isVisible = true
                }
            }
    }
}

extension View {
    /// 添加淡入动画
    func fadeIn() -> some View {
        modifier(FadeInModifier())
    }
    
    /// 添加列表项动画
    func listItemAnimation(index: Int) -> some View {
        modifier(ListItemAnimationModifier(index: index))
    }
    
    /// 添加缩放出现动画
    func scaleIn() -> some View {
        modifier(ScaleInModifier())
    }
}
