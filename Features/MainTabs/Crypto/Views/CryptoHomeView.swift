import SwiftUI

struct CryptoItem: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let price: String
    let change: Double
}

struct CryptoHomeView: View {
    @State private var searchText = ""

    let cryptoList: [CryptoItem] = [
        CryptoItem(symbol: "BTC", name: "Bitcoin", price: "$67,420", change: 2.35),
        CryptoItem(symbol: "ETH", name: "Ethereum", price: "$3,420", change: 1.42),
        CryptoItem(symbol: "SOL", name: "Solana", price: "$182", change: -0.84),
        CryptoItem(symbol: "XRP", name: "Ripple", price: "$0.61", change: 3.12),
        CryptoItem(symbol: "TRX", name: "Tron", price: "$0.12", change: 0.56)
    ]

    var filteredList: [CryptoItem] {
        if searchText.isEmpty {
            return cryptoList
        } else {
            return cryptoList.filter {
                $0.symbol.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Kripto ara (BTC, ETH, TRX...)", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    Text("Piyasa Özeti")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            summaryCard(title: "En Çok Artan", symbol: "XRP", value: "+3.12%", color: .green)
                            summaryCard(title: "En Çok Düşen", symbol: "SOL", value: "-0.84%", color: .red)
                            summaryCard(title: "Trend", symbol: "BTC", value: "$67,420", color: .blue)
                        }
                    }

                    Text("Kripto Listesi")
                        .font(.headline)

                    VStack(spacing: 12) {
                        ForEach(filteredList) { item in
                            cryptoRow(item: item)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Kripto")
        }
    }

    @ViewBuilder
    func summaryCard(title: String, symbol: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(symbol)
                .font(.headline)
                .fontWeight(.bold)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(color)
        }
        .padding()
        .frame(width: 150, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    @ViewBuilder
    func cryptoRow(item: CryptoItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.symbol)
                    .font(.headline)

                Text(item.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.price)
                    .font(.headline)

                Text(String(format: "%.2f%%", item.change))
                    .foregroundStyle(item.change >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}
