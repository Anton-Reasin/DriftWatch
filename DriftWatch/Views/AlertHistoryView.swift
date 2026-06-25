import SwiftData
import SwiftUI

/// Persisted alert feed. Reads `AlertRecord` rows straight from SwiftData, so
/// whatever fired in earlier sessions is still here after a kill and restart.
struct AlertHistoryView: View {
    /// `@Query` reads from the app's `ModelContainer` and refreshes the view when
    /// rows change, newest first. Reading from disk is what makes the list
    /// survive a restart, no in-memory cache to lose.
    @Query(sort: \AlertRecord.firedAt, order: .reverse)
    private var records: [AlertRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if records.isEmpty {
                    emptyState
                } else {
                    ForEach(records) { record in
                        AlertHistoryRow(record: record)
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("History")
                .font(.title2.bold())
            Spacer()
            Text("\(records.count)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(Capsule())
        }
    }

    private var emptyState: some View {
        Text("No saved alerts yet. They appear here once a rule fires and stay after restart.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
    }
}

// MARK: - Row

private struct AlertHistoryRow: View {
    let record: AlertRecord

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
                Text(record.symbol)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(record.firedAt.formatted(date: .abbreviated, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(record.price.formatted(.currency(code: "USD").precision(.fractionLength(2))))
                .font(.subheadline.monospacedDigit().bold())
                .foregroundStyle(.white)
        }
        .glowCard()
    }
}

// MARK: - Card style

private extension View {
    func glowCard() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.black)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .cyan.opacity(0.22), radius: 14)
            .shadow(color: .white.opacity(0.05), radius: 6)
    }
}

#Preview {
    AlertHistoryView()
        .modelContainer(for: AlertRecord.self, inMemory: true)
}
