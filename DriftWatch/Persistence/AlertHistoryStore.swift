import Foundation
import OSLog
import SwiftData

import SharedKit

/// Writes fired alerts to disk and reads them back as pages for the feed.
///
/// The store runs on the main actor so it can share the app's `ModelContext`
/// with SwiftUI without crossing an isolation boundary. Volume here is tiny (a
/// handful of alerts), so a `@ModelActor` background writer would be overkill;
/// the persistence rule allows the simpler shape when the work is small.
@MainActor
final class AlertHistoryStore {
    private let context: ModelContext
    private let log = Logger(subsystem: "com.Anton.DriftWatch", category: "AlertHistory")

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Writing

    /// Saves a fired alert, deduplicating by `eventID`.
    ///
    /// If a record with the same id already exists this is a no-op, so a logical
    /// firing re-detected after a reconnect replay does not create a second row
    /// (count stays 1 on a duplicate).
    func save(_ event: AlertEvent) {
        let id = event.eventID
        var existing = FetchDescriptor<AlertRecord>(
            predicate: #Predicate { $0.id == id }
        )
        existing.fetchLimit = 1
        let already = (try? context.fetch(existing)) ?? []
        guard already.isEmpty else { return }

        let record = AlertRecord(
            id: id,
            symbol: event.symbol.rawValue,
            price: NSDecimalNumber(decimal: event.price).doubleValue,
            firedAt: event.firedAt
        )
        context.insert(record)
        do {
            try context.save()
        } catch {
            // The unique constraint can still reject a true duplicate that races
            // the fetch above; that is the intended dedup, not a failure to act on.
            log.error("alert save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Reading

    /// Fetches a page of records ordered by `firedAt` descending.
    ///
    /// Paging is keyset/cursor based, not offset based: pass the `firedAt` of the
    /// last row you already have as `before` and you get the next older page.
    /// A new alert inserted at the top never shifts the cursor, so paging stays
    /// stable while the feed keeps growing.
    func page(before cursor: Date? = nil, limit: Int = 50) -> [AlertRecord] {
        var descriptor = FetchDescriptor<AlertRecord>(
            sortBy: [SortDescriptor(\.firedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        if let cursor {
            descriptor.predicate = #Predicate { $0.firedAt < cursor }
        }
        return (try? context.fetch(descriptor)) ?? []
    }
}
