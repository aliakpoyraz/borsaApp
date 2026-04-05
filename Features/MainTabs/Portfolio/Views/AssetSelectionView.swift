import SwiftUI

public struct AssetSelectionView: View {
    let kind: PortfolioAssetKind
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSymbol: String
    
    @State private var searchText = ""
    @State private var allSymbols: [String] = []
    @State private var isLoading = true
    
    var filteredSymbols: [String] {
        if searchText.isEmpty {
            return allSymbols
        } else {
            return allSymbols.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    public var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Varlıklar Yükleniyor...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if allSymbols.isEmpty {
                    Text("Varlık listesi alınamadı.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredSymbols, id: \.self) { symbol in
                            Button(action: {
                                selectedSymbol = symbol
                                dismiss()
                            }) {
                                HStack {
                                    Text(symbol)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if symbol == selectedSymbol {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: kind == .crypto ? "Sembol Ara (Örn: BTCUSDT)" : "Sembol Ara (Örn: THYAO)")
                }
            }
            .navigationTitle(kind == .crypto ? "Kripto Seç" : "Hisse Seç")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Kapat") { dismiss() })
            .task {
                await loadSymbols()
            }
        }
    }
    
    private func loadSymbols() async {
        isLoading = true
        if kind == .crypto {
            let cryptos = await CryptoService.shared.fetchAll24hTickers(cachePolicy: .ignoreCache)
            await MainActor.run {
                // Extract USDT cryptos mostly or just all
                self.allSymbols = cryptos.map { $0.symbol }.sorted()
                self.isLoading = false
            }
        } else {
            let stocks = await BistService.shared.fetchStocks(forceRefresh: false)
            await MainActor.run {
                self.allSymbols = stocks.map { $0.symbol }.sorted()
                self.isLoading = false
            }
        }
    }
}
