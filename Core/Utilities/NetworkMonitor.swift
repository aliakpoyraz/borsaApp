import Foundation
import Network
import Combine
import UIKit

public final class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()
    
    @Published public private(set) var isConnected: Bool = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var heartbeatTimer: Timer?
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let connected = path.status == .satisfied
            
            DispatchQueue.main.async {
                // Eğer uygulama arkaplanda ise sahte 'bağlantı koptu' olaylarını yok say
                if !connected && UIApplication.shared.applicationState == .background {
                    return
                }
                self.isConnected = connected
            }
        }
        
        // Uygulama öne geldiğinde güncel bağlantı durumunu kontrol et
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let connected = self.monitor.currentPath.status == .satisfied
            self.isConnected = connected
        }
        
        monitor.start(queue: queue)
    }
}
