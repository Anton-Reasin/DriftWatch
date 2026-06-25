import SwiftUI

/// The news feed: a dark, scrollable list of news cards backed by NewsFeedStore.
/// Scrolling to the last row loads the next page; pull to refresh reloads.
struct NewsListView: View {
    @State private var store = NewsFeedStore()

    var body: some View {
        List {
            if store.items.isEmpty, let message = store.statusMessage, !store.isLoading {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(store.items) { item in
                NewsRow(item: item)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .onAppear {
                        if item.id == store.items.last?.id {
                            Task { await store.loadNextPage() }
                        }
                    }
            }
            if store.isLoading {
                loadingRow
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .preferredColorScheme(.dark)
        .task {
            if store.items.isEmpty {
                await store.loadFirstPage()
            }
        }
        .refreshable {
            await store.loadFirstPage()
        }
    }

    private var loadingRow: some View {
        HStack {
            Spacer()
            ProgressView()
                .tint(.cyan)
            Spacer()
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

#Preview {
    NewsListView()
}
