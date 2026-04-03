import SwiftUI

struct AlertCreationView: View {
    let symbol: String
    let currentPrice: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var targetPriceInput: String = ""
    @State private var isAbove: Bool = true
    @State private var isSaving = false
    
    private let alertService = AlertService.live()
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    
    init(symbol: String, currentPrice: String) {
        self.symbol = symbol
        self.currentPrice = currentPrice
        // Set initial input to current price (clean numeric string)
        _targetPriceInput = State(initialValue: currentPrice.replacingOccurrences(of: ".", with: ","))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Price Input Card
                        priceInputCard
                        
                        // Condition Section
                        conditionSection
                        
                        Spacer(minLength: 40)
                        
                        // Save Button
                        saveButton
                        
                        Text("Hedef fiyat gerçekleştiğinde anında bildirim alacaksınız.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Fiyat Alarmı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 60, height: 60)
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 4) {
                Text(symbol)
                    .font(.title2.bold())
                Text("Şu anki fiyat: ₺\(currentPrice)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var priceInputCard: some View {
        VStack(spacing: 12) {
            Text("HEDEF FİYAT")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
                .tracking(1)
            
            HStack(alignment: .center, spacing: 8) {
                Text("₺")
                    .font(.title.bold())
                    .foregroundColor(.primary)
                
                TextField("0,00", text: $targetPriceInput)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal)
    }
    
    private var conditionSection: some View {
        HStack(spacing: 12) {
            conditionCard(title: "Üstüne Çıkınca", icon: "arrow.up.circle.fill", color: .green, selected: isAbove) {
                isAbove = true
                haptic.impactOccurred(intensity: 0.5)
            }
            
            conditionCard(title: "Altına İndince", icon: "arrow.down.circle.fill", color: .red, selected: !isAbove) {
                isAbove = false
                haptic.impactOccurred(intensity: 0.5)
            }
        }
        .padding(.horizontal)
    }
    
    private func conditionCard(title: String, icon: String, color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(selected ? .white : color)
                
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(selected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(selected ? color : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Color.clear : Color.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: selected ? color.opacity(0.3) : Color.clear, radius: 8, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var saveButton: some View {
        Button(action: saveAlert) {
            HStack {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Alarmı Kur")
                        .font(.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue)
            .clipShape(Capsule())
            .padding(.horizontal, 30)
            .shadow(color: Color.blue.opacity(0.3), radius: 10, y: 5)
        }
        .disabled(isSaving || targetPriceInput.isEmpty)
    }
    
    private func saveAlert() {
        let cleanInput = targetPriceInput.replacingOccurrences(of: ",", with: ".")
        guard let decimal = Decimal(string: cleanInput) else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        
        isSaving = true
        haptic.impactOccurred()
        
        let newAlert = Alert(symbol: symbol, targetPrice: decimal, isAbove: isAbove)
        
        Task {
            await alertService.upsert(newAlert)
            try? await Task.sleep(nanoseconds: 500_000_000) // Small delay for UX
            isSaving = false
            dismiss()
        }
    }
}
