import SwiftUI
import WidgetKit

struct WidgetDiagnosticView: View {
    @State private var appGroupStatus: Bool = false
    @State private var logoDirectoryExists: Bool = false
    @State private var logoFiles: [String] = []
    @State private var containerPath: String = ""
    @State private var isRefreshing: Bool = false
    
    var body: some View {
        List {
            Section("Sistem Durumu") {
                HStack {
                    Text("App Group Erişimi")
                    Spacer()
                    StatusBadge(isActive: appGroupStatus)
                }
                
                HStack {
                    Text("Logo Klasörü")
                    Spacer()
                    StatusBadge(isActive: logoDirectoryExists)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Paylaşımlı Yol:")
                        .font(.caption.bold())
                    Text(containerPath)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Logo Önbelleği (\(logoFiles.count) dosya)") {
                if logoFiles.isEmpty {
                    Text("Henüz logo indirilmemiş.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(logoFiles.prefix(20), id: \.self) { file in
                        HStack {
                            if let url = WidgetSharedData.logoDirectoryURL?.appendingPathComponent(file),
                               let data = try? Data(contentsOf: url),
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            }
                            Text(file)
                                .font(.system(size: 10, design: .monospaced))
                        }
                    }
                    if logoFiles.count > 20 {
                        Text("... ve \(logoFiles.count - 20) daha fazla.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                Button(action: refreshDiagnostics) {
                    HStack {
                        Spacer()
                        Text("Verileri Yenile")
                        Spacer()
                    }
                }
                
                Button(action: {
                    print("🛠 Diagnostic: Manuel yenileme tetiklendi. AppGroup: \(WidgetSharedData.appGroupID)")
                    WidgetKit.WidgetCenter.shared.reloadAllTimelines()
                    refreshDiagnostics()
                    
                    // Ekstra: UserDefaults senkronizasyonunu zorla
                    UserDefaults(suiteName: WidgetSharedData.appGroupID)?.synchronize()
                }) {
                    HStack {
                        Spacer()
                        Text("Görünümü Yenile (Widget'ı Zorla)")
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
                
                Button(action: clearAndReloadLogos) {
                    HStack {
                        Spacer()
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Text("Logoları Sil ve Yeniden İndir")
                                .foregroundColor(.red)
                        }
                        Spacer()
                    }
                }
                .disabled(isRefreshing)
            }
        }
        .navigationTitle("Widget Tanı Paneli")
        .onAppear(perform: refreshDiagnostics)
    }
    
    private func refreshDiagnostics() {
        appGroupStatus = WidgetSharedData.sharedContainerURL != nil
        containerPath = WidgetSharedData.sharedContainerURL?.path ?? "Erişilemiyor"
        
        if let dir = WidgetSharedData.logoDirectoryURL {
            logoDirectoryExists = FileManager.default.fileExists(atPath: dir.path)
            logoFiles = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        } else {
            logoDirectoryExists = false
            logoFiles = []
        }
    }
    
    private func clearAndReloadLogos() {
        isRefreshing = true
        guard let dir = WidgetSharedData.logoDirectoryURL else { return }
        
        try? FileManager.default.removeItem(at: dir)
        refreshDiagnostics()
        
        // Re-trigger from ViewModels (will happen on next load)
        // For now, just trigger manual refresh after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isRefreshing = false
            self.refreshDiagnostics()
        }
    }
}

struct StatusBadge: View {
    let isActive: Bool
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isActive ? "BAŞARILI" : "HATALI")
                .font(.caption.bold())
                .foregroundColor(isActive ? .green : .red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((isActive ? Color.green : Color.red).opacity(0.1))
        .cornerRadius(4)
    }
}
