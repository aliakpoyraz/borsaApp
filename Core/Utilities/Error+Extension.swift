import Foundation

extension Error {
    public var turkishDescription: String {
        let nsError = self as NSError
        
        // Ağ bağlantısı hataları (NSURLErrorDomain)
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin."
            case NSURLErrorTimedOut:
                return "İşlem zaman aşımına uğradı. Lütfen tekrar deneyin."
            case NSURLErrorCannotConnectToHost:
                return "Sunucuya bağlanılamıyor. Lütfen daha sonra tekrar deneyin."
            case NSURLErrorNetworkConnectionLost:
                return "Ağ bağlantısı kesildi."
            default:
                break
            }
        }
        
        // Supabase veya diğer özel hata mesajları için ham dize kontrolü
        let msg = self.localizedDescription
        if msg.contains("The internet connection appears to be offline") {
            return "İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin."
        }
        
        return msg
    }
}
