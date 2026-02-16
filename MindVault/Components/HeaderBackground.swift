import SwiftUI

struct HeaderBackground: View {
    var body: some View {
        // 用一个"占位矩形"决定布局尺寸，把大圆放到 background 里，
        // 让圆和阴影只影响绘制，不参与宽度计算
        Color.clear
            .frame(height: 270)
            .frame(maxWidth: .infinity)
            .background(
                TimelineView(.periodic(from: .now, by: 0.016)) { context in
                    let time = context.date.timeIntervalSince1970
                    let phase1 = time * (2 * .pi / 8.0)  // 8秒一个周期
                    let phase2 = time * (2 * .pi / 12.0)  // 12秒一个周期
                    let phase3 = time * (2 * .pi / 15.0)  // 15秒一个周期
                    
                    ZStack {
                        // 主圆形 - 仅颜色涌动，涌动中心靠下方
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: MVTheme.primary.opacity(0.70 + 0.1 * sin(phase1)), location: 0.0),
                                        .init(color: MVTheme.primaryLight.opacity(0.60 + 0.08 * cos(phase1 * 0.7)), location: 0.5),
                                        .init(color: MVTheme.primary.opacity(0.50 + 0.05 * sin(phase1 * 1.2)), location: 1.0)
                                    ]),
                                    center: UnitPoint(
                                        x: 0.5 + 0.2 * sin(phase1),
                                        y: 0.75 + 0.1 * cos(phase1 * 0.8)  // 中心靠下方，在下方区域涌动
                                    ),
                                    startRadius: 200,
                                    endRadius: 600
                                )
                            )
                            .frame(width: 1200, height: 1200)
                            .offset(y: -490)
                            .shadow(color: MVTheme.primary.opacity(0.5), radius: 22, x: 0, y: 10)
                        
                        // 第二层 - 更慢的颜色涌动，中心靠下方
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: MVTheme.primaryLight.opacity(0.55 + 0.1 * cos(phase2)), location: 0.0),
                                        .init(color: MVTheme.primary.opacity(0.50 + 0.08 * sin(phase2 * 0.9)), location: 0.6),
                                        .init(color: MVTheme.primaryLight.opacity(0.40 + 0.05 * cos(phase2 * 1.1)), location: 1.0)
                                    ]),
                                    center: UnitPoint(
                                        x: 0.5 + 0.25 * cos(phase2),
                                        y: 0.8 + 0.12 * sin(phase2 * 0.7)  // 中心更靠下方
                                    ),
                                    startRadius: 150,
                                    endRadius: 550
                                )
                            )
                            .frame(width: 1100, height: 1100)
                            .offset(y: -480)
                            .blendMode(.overlay)
                        
                        // 第三层 - 最慢的深层颜色涌动，中心靠下方
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: MVTheme.primary.opacity(0.50 + 0.08 * sin(phase3 * 0.6)), location: 0.0),
                                        .init(color: MVTheme.primaryLight.opacity(0.45 + 0.06 * cos(phase3 * 0.8)), location: 0.7),
                                        .init(color: MVTheme.primary.opacity(0.40 + 0.04 * sin(phase3 * 1.0)), location: 1.0)
                                    ]),
                                    center: UnitPoint(
                                        x: 0.5 + 0.15 * sin(phase3 * 0.5),
                                        y: 0.85 + 0.1 * cos(phase3 * 0.6)  // 中心最靠下方
                                    ),
                                    startRadius: 100,
                                    endRadius: 500
                                )
                            )
                            .frame(width: 1000, height: 1000)
                            .offset(y: -470)
                            .blendMode(.softLight)
                    }
                }
            )
            .padding(.bottom, 50)
            // 裁剪掉超出顶部区域的部分
            .clipped()
            .ignoresSafeArea(edges: .top)
    }
}
