import SwiftUI

public struct PortfolioAddAssetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PortfolioViewModel

    @State private var assetType: PortfolioAssetKind = .crypto
    @State private var symbol: String = ""
    @State private var quantity: String = ""
    @State private var isSaving = false

    @State private var suggestions: [AssetSuggestion] = []
    @State private var isLoadingSymbols = false
    @State private var searchText: String = ""
    @State private var selectedSuggestion: AssetSuggestion?

    struct AssetSuggestion: Identifiable, Equatable {
        let id = UUID()
        let symbol: String
        let name: String
    }

    var filteredSuggestions: [AssetSuggestion] {
        guard !searchText.isEmpty else { return [] }
        let q = searchText.uppercased()
        return suggestions
            .filter { $0.symbol.contains(q) || $0.name.localizedCaseInsensitiveContains(searchText) }
            .prefix(8)
            .map { $0 }
    }

    var canAdd: Bool {
        !symbol.isEmpty && !quantity.isEmpty && !isSaving
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Asset type picker
                        typePicker

                        // Asset search
                        searchSection

                        // Quantity input
                        quantitySection

                        // Add button
                        addButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Varlık Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { dismiss() }
                }
            }
            .alert(isPresented: .constant(viewModel.errorMessage != nil)) {
                SwiftUI.Alert(
                    title: Text("Hata"),
                    message: Text(viewModel.errorMessage ?? ""),
                    dismissButton: .default(Text("Tamam"))
                )
            }
            .onChange(of: assetType) { _, _ in
                symbol = ""
                searchText = ""
                selectedSuggestion = nil
                Task { await loadSymbols() }
            }
            .task {
                await loadSymbols()
            }
        }
    }

    // MARK: - Type Picker
    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Varlık Tipi")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            Picker("Tür", selection: $assetType) {
                Label("Kripto Para", systemImage: "bitcoinsign.circle").tag(PortfolioAssetKind.crypto)
                Label("Hisse Senedi", systemImage: "chart.bar").tag(PortfolioAssetKind.stock)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    // MARK: - Asset Search
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(assetType == .crypto ? "Kripto Para" : "Hisse Senedi")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // Selected badge or search field
                if let selected = selectedSuggestion {
                    HStack {
                        // Icon
                        assetIcon(symbol: selected.symbol.replacingOccurrences(of: "USDT", with: ""))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.symbol)
                                .font(.headline)
                            Text(selected.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            selectedSuggestion = nil
                            symbol = ""
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    // Search field
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(assetType == .crypto ? "BTC, ETH, SOL..." : "THYAO, GARAN...", text: $searchText)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .onChange(of: searchText) { _, _ in }
                        if isLoadingSymbols {
                            ProgressView().scaleEffect(0.7)
                        } else if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Suggestions dropdown
                    if !filteredSuggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(filteredSuggestions) { sug in
                                Button {
                                    selectedSuggestion = sug
                                    symbol = sug.symbol
                                    searchText = sug.symbol
                                } label: {
                                    HStack(spacing: 12) {
                                        assetIcon(symbol: sug.symbol.replacingOccurrences(of: "USDT", with: ""))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(sug.symbol)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(.primary)
                                            Text(sug.name)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 11)
                                }
                                .buttonStyle(PlainButtonStyle())

                                if sug.id != filteredSuggestions.last?.id {
                                    Divider().padding(.leading, 54)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.primary.opacity(0.08), radius: 8, x: 0, y: 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func assetIcon(symbol: String) -> some View {
        if assetType == .crypto {
            CryptoLogoView(symbol: symbol, size: 34)
        } else {
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 34, height: 34)
                .overlay(Text(String(symbol.prefix(2))).font(.system(size: 11, weight: .bold)).foregroundColor(.white))
        }
    }

    // MARK: - Quantity
    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Miktar")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 10) {
                Image(systemName: "number")
                    .foregroundColor(.secondary)
                TextField("0.00", text: $quantity)
                    .keyboardType(.decimalPad)
                    .font(.system(.body, design: .rounded))
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Ondalık için nokta (.) kullanın. Örnek: 0.05")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Add Button
    private var addButton: some View {
        Button {
            Task {
                isSaving = true
                let success = await viewModel.addAsset(kind: assetType, symbol: symbol, quantityStr: quantity)
                isSaving = false
                if success { dismiss() }
            }
        } label: {
            Group {
                if isSaving {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("Ekleniyor...")
                            .fontWeight(.semibold)
                    }
                } else {
                    Text("Portföye Ekle")
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canAdd
                    ? Color.blue.gradient
                    : Color.gray.opacity(0.4).gradient
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!canAdd)
        .padding(.top, 8)
    }

    // MARK: - Load Symbols
    private func loadSymbols() async {
        isLoadingSymbols = true
        if assetType == .crypto {
            do {
                let cryptos = try await CryptoService.shared.fetchAll24hTickers(cachePolicy: .useCacheIfAvailable)
                self.suggestions = cryptos
                    .filter { $0.symbol.hasSuffix("USDT") }
                    .map { AssetSuggestion(symbol: $0.symbol, name: ($0.symbol.replacingOccurrences(of: "USDT", with: "")) + "/USDT") }
            } catch {
                self.suggestions = []
            }
        } else {
            let stocks = await BistService.shared.fetchStocks(forceRefresh: false)
            self.suggestions = stocks.map { AssetSuggestion(symbol: $0.symbol, name: "\($0.symbol)/TL - \($0.description)") }
        }
        isLoadingSymbols = false
    }
}
