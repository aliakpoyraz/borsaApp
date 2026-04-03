import Foundation
import Network
import Combine

public final class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()
    
    @Published public private(set) var isConnected: Bool = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let connected = path.status == .satisfied
            DispatchQueue.main.async {
                self.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }
}
