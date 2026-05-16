import SwiftUI

private let bitcoinOrange = Color(red: 1.0, green: 0.58, blue: 0.13)

// MARK: - Collapsed

struct BitcoinCollapsedView: View {
    @Bindable var state: BitcoinPriceState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(bitcoinOrange)
            if let snap = state.snapshot {
                Text(BitcoinFormat.compact(snap.priceUSD))
                    .font(Typography.labelMedium)
                    .monospacedDigit()
                    .foregroundStyle(Palette.primary)
            } else {
                Text("—")
                    .font(Typography.labelMedium)
                    .monospacedDigit()
                    .foregroundStyle(Palette.tertiary)
            }
        }
    }
}

// MARK: - Expanded

struct BitcoinExpandedView: View {
    @Bindable var state: BitcoinPriceState

    var body: some View {
        Group {
            if let snap = state.snapshot {
                content(snap)
            } else if state.isFetching {
                loadingView
            } else {
                errorView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func content(_ snap: BitcoinSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(bitcoinOrange)
                    Text("BTC / USD")
                        .font(Typography.label)
                        .foregroundStyle(Palette.secondary)
                        .tracking(0.5)
                }
                Spacer()
                Text(updatedString(for: snap.updatedAt))
                    .font(Typography.caption)
                    .foregroundStyle(Palette.tertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(BitcoinFormat.full(snap.priceUSD))
                    .font(Typography.display)
                    .foregroundStyle(Palette.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                changeBadge(snap)
            }

            if !snap.sparkline.isEmpty {
                SparklineView(values: snap.sparkline, trend: snap.trend)
                    .frame(height: 28)
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    private func changeBadge(_ snap: BitcoinSnapshot) -> some View {
        let color: Color = {
            switch snap.trend {
            case .up: return .green
            case .down: return .red
            case .flat: return Palette.secondary
            }
        }()
        let arrow: String = {
            switch snap.trend {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .flat: return "arrow.right"
            }
        }()
        return HStack(spacing: 2) {
            Image(systemName: arrow).font(.system(size: 9, weight: .bold))
            Text(BitcoinFormat.change(snap.change24hPct))
                .font(Typography.label)
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color.opacity(0.15))
        )
    }

    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Fetching BTC price…")
                .font(Typography.body)
                .foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 4) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 18))
                .foregroundStyle(Palette.tertiary)
            Text(state.lastError ?? "Couldn't reach CoinGecko")
                .font(Typography.labelMedium)
                .foregroundStyle(Palette.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func updatedString(for date: Date) -> String {
        let secs = max(0, Int(Date().timeIntervalSince(date)))
        if secs < 60 { return "Updated \(secs)s ago" }
        let mins = secs / 60
        return "Updated \(mins)m ago"
    }
}

// MARK: - Sparkline

private struct SparklineView: View {
    let values: [Double]
    let trend: BitcoinSnapshot.Trend

    private var color: Color {
        switch trend {
        case .up: return .green
        case .down: return .red
        case .flat: return Palette.secondary
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let span = max(0.0001, maxV - minV)

            ZStack {
                // Soft gradient fill — bright at the line, fades to clear
                // at the bottom. Reads premium next to the hero price.
                Path { p in
                    guard !values.isEmpty else { return }
                    p.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(max(1, values.count - 1))
                        let y = h - h * CGFloat((v - minV) / span)
                        p.addLine(to: CGPoint(x: x, y: y))
                    }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.28), color.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // The line itself
                Path { p in
                    guard !values.isEmpty else { return }
                    for (i, v) in values.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(max(1, values.count - 1))
                        let y = h - h * CGFloat((v - minV) / span)
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else      { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

                // End cap — a small dot at the latest price so the eye
                // lands on "now" rather than the whole curve.
                if let last = values.last {
                    let lastX = w
                    let lastY = h - h * CGFloat((last - minV) / span)
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .position(x: lastX - 2.5, y: lastY)
                    Circle()
                        .fill(color.opacity(0.25))
                        .frame(width: 11, height: 11)
                        .position(x: lastX - 2.5, y: lastY)
                        .blendMode(.plusLighter)
                }
            }
        }
    }
}
