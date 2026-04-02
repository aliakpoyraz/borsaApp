import SwiftUI

struct BistItem: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let price: String
    let change: Double
}

struct BistHomeView: View {
    @State private var searchText = ""

    let bistList: [BistItem] = [
        BistItem(code: "THYAO", name: "Türk Hava Yolları", price: "312.25 ₺", change: 1.84),
        BistItem(code: "ASELS", name: "Aselsan", price: "68.40 ₺", change: 2.16),
        BistItem(code: "TUPRS", name: "Tüpraş", price: "176.80 ₺", change: -0.92),
        BistItem(code: "SISE", name: "Şişecam", price: "49.12 ₺", change: 0.63),
        BistItem(code: "KCHOL", name: "Koç Holding", price: "215.40 ₺", change: -1.25)
    ]

    var filteredList: [BistItem] {
        if searchText.isEmpty {
            return bistList
        } else {
            return bistList.filter {
                $0.code.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Hisse ara (THYAO, ASELS...)", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    Text("BIST Özeti")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            summaryCard(title: "En Çok Artan", symbol: "ASELS", value: "+2.16%", color: .green)
                            summaryCard(title: "En Çok Düşen", symbol: "KCHOL", value: "-1.25%", color: .red)
                            summaryCard(title: "Trend", symbol: "THYAO", value: "312.25 ₺", color: .blue)
                        }
                        .padding(.horizontal, 1)
                    }
                    .frame(height: 125)

                    Text("Hisse Listesi")
                        .font(.headline)

                    LazyVStack(spacing: 12) {
                        ForEach(filteredList) { item in
                            bistRow(item: item)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("BIST")
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
        .frame(width: 180, height: 110, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    @ViewBuilder
    func bistRow(item: BistItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.code)
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
