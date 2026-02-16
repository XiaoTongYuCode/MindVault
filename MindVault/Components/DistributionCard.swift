import SwiftUI

struct DistributionCard: View {
    @EnvironmentObject var languageManager: LanguageManager
    let distribution: MoodDistribution

    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("mood.distribution".localized(using: languageManager))
                    .font(.system(size: 14))
                    .foregroundColor(MVTheme.muted)
                HStack(spacing: 4) {
                    DistributionBar(value: distribution.veryPositiveRatio, color: MVTheme.success)
                    DistributionBar(value: distribution.positiveRatio, color: MVTheme.success.opacity(0.8))
                    DistributionBar(value: distribution.neutralRatio, color: MVTheme.warning)
                    DistributionBar(value: distribution.negativeRatio, color: MVTheme.error.opacity(0.8))
                    DistributionBar(value: distribution.veryNegativeRatio, color: MVTheme.error)
                }
                VStack(spacing: 6) {
                    HStack {
                        DistributionLabel(
                            title: "mood.very_positive".localized(using: languageManager),
                            count: distribution.veryPositive,
                            color: MVTheme.success
                        )
                        Spacer()
                        DistributionLabel(
                            title: "mood.positive".localized(using: languageManager),
                            count: distribution.positive,
                            color: MVTheme.success.opacity(0.8)
                        )
                        Spacer()
                        DistributionLabel(
                            title: "mood.neutral".localized(using: languageManager),
                            count: distribution.neutral,
                            color: MVTheme.warning
                        )
                    }
                    HStack {
                        DistributionLabel(
                            title: "mood.negative".localized(using: languageManager),
                            count: distribution.negative,
                            color: MVTheme.error.opacity(0.8)
                        )
                        Spacer()
                        DistributionLabel(
                            title: "mood.very_negative".localized(using: languageManager),
                            count: distribution.veryNegative,
                            color: MVTheme.error
                        )
                        Spacer()
                        // 占位，保持对齐
                        Text("")
                            .font(.system(size: 12))
                            .opacity(0)
                    }
                }
            }
        }
        .id(languageManager.currentLanguage.id)
    }
}

struct DistributionBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(width: max(6, proxy.size.width * value), height: 8)
        }
        .frame(height: 8)
        .background(MVTheme.border.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct DistributionLabel: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(title) \(count)")
                .font(.system(size: 12))
                .foregroundColor(MVTheme.muted)
        }
    }
}
