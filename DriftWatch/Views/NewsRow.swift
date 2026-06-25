import SwiftUI

/// A single news card styled like the price screen: black rounded card with a
/// thin border and a cyan glow on a dark background.
struct NewsRow: View {
    let item: NewsItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text("\(item.source) · \(item.timeAgo)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !item.coins.isEmpty {
                    coinChips
                }
            }
            Spacer(minLength: 0)
        }
        .glowCard()
    }

    // MARK: - Helpers

    private var thumbnail: some View {
        AsyncImage(url: item.imageURL) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Color.white.opacity(0.06)
                Image(systemName: "newspaper.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var coinChips: some View {
        HStack(spacing: 6) {
            ForEach(item.coins.prefix(3), id: \.self) { coin in
                Text(coin)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Card style

private extension View {
    /// Black rounded card with a hairline border and a cyan glow, matching the
    /// price screen cards.
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
    ZStack {
        Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()
        VStack(spacing: 16) {
            NewsRow(
                item: NewsItem(
                    id: "1",
                    title: "DEXE up +63.85%, BTC -1.33%, DeXe is The Coin of The Day",
                    source: "Coincodex",
                    timeAgo: "2h ago",
                    imageURL: nil,
                    coins: ["BTC", "XLM", "TEL"]
                )
            )
            NewsRow(
                item: NewsItem(
                    id: "2",
                    title: "Aluminium market faces 3 million tonne hole as ING warns deficit",
                    source: "Coincodex",
                    timeAgo: "4h ago",
                    imageURL: nil,
                    coins: []
                )
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
