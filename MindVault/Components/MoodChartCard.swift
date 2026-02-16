import SwiftUI
import Charts

struct MoodChartCard: View {
    let moodPoints: [MoodPoint]
    let range: ChartRange
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.colorScheme) var colorScheme
    
    enum ChartRange {
        case week
        case month
        
        var dayStride: Int {
            switch self {
            case .week: return 1
            case .month: return 5
            }
        }
    }
    
    var body: some View {
        GlassCard {
            Chart(moodPoints) { point in
                // 区分真实数据和补齐数据
                let isPlaceholder = point.isPlaceholder
                let lineColor: AnyShapeStyle = isPlaceholder ? AnyShapeStyle(Color.gray.opacity(0.4)) : AnyShapeStyle(MVTheme.gradient)
                let areaColor: AnyShapeStyle = isPlaceholder ? AnyShapeStyle(Color.gray.opacity(0.1)) : AnyShapeStyle(MVTheme.gradient.opacity(0.3))
                let pointColor = isPlaceholder ? Color.gray.opacity(0.5) : SentimentDisplay.from(score: point.score).color
                
                AreaMark(
                    x: .value("日期", point.date),
                    y: .value("分数", point.score)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(areaColor)
                
                LineMark(
                    x: .value("日期", point.date),
                    y: .value("分数", point.score)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: isPlaceholder ? 1.5 : 2, dash: isPlaceholder ? [4, 4] : []))

                PointMark(
                    x: .value("日期", point.date),
                    y: .value("分数", point.score)
                )
                .symbolSize(120)
                .symbol {
                    ZStack {
                        // 外圈
                        Circle()
                            .stroke(
                                pointColor,
                                lineWidth: isPlaceholder ? 2 : 3
                            )
                            .frame(width: 10, height: 10)
                        // 内圈（主体色：浅色模式为白色，深色模式为黑色）
                        Circle()
                            .fill(colorScheme == .light ? Color.white : Color.black)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .chartYScale(domain: yAxisDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range.dayStride)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month().day(), centered: false)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisValues) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: value.as(Double.self) == 0 ? [4] : []))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            // 根据数据范围动态显示标签
                            if shouldShowLabel(for: doubleValue) {
                                let domain = yAxisDomain
                                let minValue = domain.lowerBound
                                let maxValue = domain.upperBound
                                
                                // 显示 0 为中性
                                if abs(doubleValue) < 0.001 {
                                    Text("mood.neutral".localized(using: languageManager))
                                }
                                // 显示最大值附近的标签（如果接近 0.8 或 1.0）
                                else if abs(doubleValue - maxValue) < 0.001 {
                                    if abs(doubleValue - 1.0) < 0.001 || abs(doubleValue - 0.8) < 0.001 {
                                        Text("mood.very_positive".localized(using: languageManager))
                                    } else {
                                        Text(String(format: "%.2f", doubleValue))
                                    }
                                }
                                // 显示最小值附近的标签（如果接近 -0.8 或 -1.0）
                                else if abs(doubleValue - minValue) < 0.001 {
                                    if abs(doubleValue + 1.0) < 0.001 || abs(doubleValue + 0.8) < 0.001 {
                                        Text("mood.very_negative".localized(using: languageManager))
                                    } else {
                                        Text(String(format: "%.2f", doubleValue))
                                    }
                                }
                                // 其他情况显示数值
                                else {
                                    Text(String(format: "%.2f", doubleValue))
                                }
                            }
                        }
                    }
                    .font(.system(size: 10))
                }
            }
            .frame(height: 200)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(MVTheme.gradient, lineWidth: 1)
        )
        .id(languageManager.currentLanguage.id)
    }
    
    // 计算 Y 轴动态范围
    private var yAxisDomain: ClosedRange<Double> {
        guard !moodPoints.isEmpty else {
            return -1...1
        }
        
        // 只使用真实数据计算范围，排除补齐数据
        let realScores = moodPoints.filter { !$0.isPlaceholder }.map { $0.score }
        
        // 如果没有真实数据，返回默认范围
        guard !realScores.isEmpty else {
            return -1...1
        }
        
        let minScore = realScores.min() ?? 0
        let maxScore = realScores.max() ?? 0
        
        // 如果所有数据都大于 0，只显示正半轴
        if minScore > 0 {
            // 从 0 开始，到最大值 + 一些边距，但不超过 1
            let upperBound = min(maxScore * 1.1, 1.0)
            return 0...upperBound
        }
        // 如果所有数据都小于 0，只显示负半轴
        else if maxScore < 0 {
            // 从最小值 - 一些边距开始，到 0，但不小于 -1
            let lowerBound = max(minScore * 1.1, -1.0)
            return lowerBound...0
        }
        // 数据跨越正负，显示完整范围
        else {
            return -1...1
        }
    }
    
    // 根据数据范围动态计算 Y 轴刻度值
    private var yAxisValues: [Double] {
        let domain = yAxisDomain
        let minValue = domain.lowerBound
        let maxValue = domain.upperBound
        let range = maxValue - minValue
        
        // 根据范围大小动态决定刻度数量（3-6个刻度）
        let preferredCount: Int
        if range <= 0.3 {
            preferredCount = 3
        } else if range <= 0.6 {
            preferredCount = 4
        } else if range <= 1.0 {
            preferredCount = 5
        } else {
            preferredCount = 6
        }
        
        // 计算合适的步长，确保边界值被包含
        let step = range / Double(preferredCount - 1)
        
        // 生成均匀分布的刻度值（从最小值到最大值）
        var values: [Double] = []
        for i in 0..<preferredCount {
            let value = minValue + step * Double(i)
            values.append(value)
        }
        
        // 确保最后一个值精确等于最大值（避免浮点误差）
        if !values.isEmpty {
            values[values.count - 1] = maxValue
        }
        
        return values
    }
    
    // 判断是否应该显示某个刻度值的标签
    private func shouldShowLabel(for value: Double) -> Bool {
        let domain = yAxisDomain
        let minValue = domain.lowerBound
        let maxValue = domain.upperBound
        let values = yAxisValues
        
        // 总是显示边界值
        if abs(value - minValue) < 0.001 || abs(value - maxValue) < 0.001 {
            return true
        }
        
        // 如果 0 在范围内，总是显示 0
        if minValue <= 0 && maxValue >= 0 && abs(value) < 0.001 {
            return true
        }
        
        // 对于其他刻度值，根据刻度数量决定显示策略
        // 如果刻度较少（<=4），显示所有
        if values.count <= 4 {
            return values.contains { abs($0 - value) < 0.001 }
        }
        
        // 如果刻度较多（>4），只显示边界、0（如果在范围内）和中间值
        if values.count > 4 {
            // 显示中间值（如果存在）
            let midIndex = values.count / 2
            if midIndex < values.count {
                let midValue = values[midIndex]
                if abs(value - midValue) < 0.001 {
                    return true
                }
            }
        }
        
        return false
    }
}
