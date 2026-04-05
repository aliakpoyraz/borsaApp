import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case serverError(statusCode: Int)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Geçersiz bir bağlantı adresi."
        case .invalidResponse:
            return "Sunucudan beklenen yanıt alınamadı."
        case .decodingError(let error):
            return "Veri işlenirken bir hata oluştu: \(error.turkishDescription)"
        case .serverError(let statusCode):
            return "Sunucu hatası. (Hata Kodu: \(statusCode))"
        case .unknown(let error):
            return "Bilinmeyen bir hata oluştu: \(error.turkishDescription)"
        }
    }
}
