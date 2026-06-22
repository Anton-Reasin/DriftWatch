import SwiftUI

import SharedKit

struct ContentView: View {
    let store: MarketStore

    var body: some View {
        VStack(spacing: 24) {
            priceHeader
            alertsSection
            Spacer()
        }
        .padding()
        .task { store.start() }
    }

    private var priceHeader: some View {
        VStack(spacing: 4) {
            Text("BTCUSDT")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(priceText)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alerts")
                .font(.title3.bold())
            if store.alerts.isEmpty {
                Text("Waiting for a rule to fire...")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            } else {
                ForEach(store.alerts, id: \.eventID) { alert in
                    AlertRow(alert: alert)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var priceText: String {
        guard let price = store.latestPrice else { return "..." }
        return price.formatted(.number.precision(.fractionLength(2)))
    }
}

private struct AlertRow: View {
    let alert: AlertEvent

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.symbol.rawValue)
                    .font(.subheadline.bold())
                Text(alert.firedAt.formatted(date: .omitted, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(alert.price.formatted(.number.precision(.fractionLength(2))))
                .font(.subheadline.monospacedDigit())
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ContentView(store: .demo())
}
