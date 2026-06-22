import Charts
import Foundation
import SwiftUI

import SharedKit

struct ContentView: View {
    let store: MarketStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                priceHeader
                chartCard
                BoundsEditor(store: store)
                alertsCard
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task { store.start() }
    }

    // MARK: - Header

    private var priceHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BTCUSDT")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                ConnectionBadge(status: store.connection)
            }
            Text(priceText)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private var priceText: String {
        guard let price = store.latestPrice else { return "..." }
        return price.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Price")
                .font(.headline)
                .foregroundStyle(.secondary)
            PriceChart(prices: store.priceHistory, upper: store.bandUpper, lower: store.bandLower)
                .frame(height: 180)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Alerts

    private var alertsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alerts")
                .font(.headline)
            if store.alerts.isEmpty {
                Text("Waiting for a rule to fire...")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(store.alerts.enumerated()), id: \.element.eventID) { pair in
                    AlertRow(alert: pair.element)
                    if pair.offset < store.alerts.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Price chart

private struct PriceChart: View {
    let prices: [Decimal]
    let upper: Decimal?
    let lower: Decimal?

    private struct Point: Identifiable {
        let id: Int
        let value: Double
    }

    private var points: [Point] {
        prices.enumerated().map { index, price in
            Point(id: index, value: NSDecimalNumber(decimal: price).doubleValue)
        }
    }

    private var upperValue: Double? {
        upper.map { NSDecimalNumber(decimal: $0).doubleValue }
    }

    private var lowerValue: Double? {
        lower.map { NSDecimalNumber(decimal: $0).doubleValue }
    }

    private var yDomain: ClosedRange<Double> {
        var values = points.map(\.value)
        if let upperValue { values.append(upperValue) }
        if let lowerValue { values.append(lowerValue) }
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        guard low < high else { return (low - 1)...(high + 1) }
        let pad = (high - low) * 0.15
        return (low - pad)...(high + pad)
    }

    var body: some View {
        if points.count < 2 {
            placeholder
        } else {
            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Sample", point.id),
                        y: .value("Price", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.35), .blue.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Sample", point.id),
                        y: .value("Price", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                if let upperValue {
                    RuleMark(y: .value("Upper", upperValue))
                        .foregroundStyle(.green.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
                if let lowerValue {
                    RuleMark(y: .value("Lower", lowerValue))
                        .foregroundStyle(.red.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: yDomain)
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.blue.opacity(0.06))
            .overlay {
                Text("Collecting prices...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
    }
}

// MARK: - Alert row

private struct AlertRow: View {
    let alert: AlertEvent

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "bell.fill")
                    .foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.symbol.rawValue)
                    .font(.subheadline.bold())
                Text(alert.firedAt.formatted(date: .omitted, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(alert.price.formatted(.currency(code: "USD").precision(.fractionLength(2))))
                .font(.subheadline.monospacedDigit().bold())
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Connection badge

private struct ConnectionBadge: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case .connecting: "Connecting"
        case .live: "Live"
        case .reconnecting: "Reconnecting"
        case .offline: "Offline"
        }
    }

    private var color: Color {
        switch status {
        case .connecting: .orange
        case .live: .green
        case .reconnecting: .orange
        case .offline: .red
        }
    }
}

// MARK: - Bounds editor

private struct BoundsEditor: View {
    let store: MarketStore
    @State private var upperText = ""
    @State private var lowerText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alert bounds")
                .font(.headline)
            HStack(spacing: 12) {
                boundField("Upper", text: $upperText)
                boundField("Lower", text: $lowerText)
            }
            HStack {
                Button("Apply") { apply() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                Spacer()
                Button("Auto") { store.useAutoBounds() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onChange(of: store.bandUpper) { _, value in
            if upperText.isEmpty, let value { upperText = formatted(value) }
        }
        .onChange(of: store.bandLower) { _, value in
            if lowerText.isEmpty, let value { lowerText = formatted(value) }
        }
    }

    private func boundField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0.00", text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()
        }
    }

    private var upperValue: Decimal? { parse(upperText) }
    private var lowerValue: Decimal? { parse(lowerText) }

    private var isValid: Bool {
        guard let upper = upperValue, let lower = lowerValue else { return false }
        return upper > lower && lower > 0
    }

    private func apply() {
        guard let upper = upperValue, let lower = lowerValue else { return }
        Task { await store.setBounds(upper: upper, lower: lower) }
    }

    private func parse(_ text: String) -> Decimal? {
        Decimal(string: text.replacingOccurrences(of: ",", with: "."))
    }

    private func formatted(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(2)).grouping(.never))
    }
}

#Preview {
    ContentView(store: .demo())
}
