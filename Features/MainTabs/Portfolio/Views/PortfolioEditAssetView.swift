import SwiftUI

struct PortfolioEditAssetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PortfolioViewModel
    let asset: PortfolioAssetPnL
    
    @State private var quantityStr: String
    @State private var isSaving = false
    
    init(viewModel: PortfolioViewModel, asset: PortfolioAssetPnL) {
        self.viewModel = viewModel
        self.asset = asset
        _quantityStr = State(initialValue: "\(asset.quantity)".replacingOccurrences(of: ".", with: ","))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Varlık Bilgileri")) {
                    HStack {
                        Text("Sembol")
                        Spacer()
                        Text(asset.symbol)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Tür")
                        Spacer()
                        Text(asset.kind == .crypto ? "Kripto" : "Hisse Senedi")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Miktar Güncelle")) {
                    TextField("Yeni Miktar", text: $quantityStr)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Button(role: .destructive) {
                        Task {
                            isSaving = true
                            await viewModel.removeAsset(asset: asset)
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Varlığı Tamamen Sil")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Varlığı Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Güncelle") {
                            Task {
                                isSaving = true
                                let success = await viewModel.updateAssetQuantity(asset: asset, newQuantityStr: quantityStr)
                                isSaving = false
                                if success {
                                    dismiss()
                                }
                            }
                        }
                        .fontWeight(.bold)
                    }
                }
            }
        }
    }
}
