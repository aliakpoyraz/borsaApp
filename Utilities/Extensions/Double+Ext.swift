/**
 * VERİ ENTEGRASYONU - MATEMATİK VE FORMATLAYICILAR (COMPLETED)
 * Bu araçlar, API'den gelen ham sayısal verileri (Kripto/BIST)
 * kullanıcıya şık bir para birimi ve yüzde değişimi olarak 
 * göstermek için kullanılır. UI tarafındaki iş yükünü sıfıra indirir.
 */
```

import Foundation

extension Double {
    /// Formats as `$1.234,56` using Turkish separators.
    /// If absolute value < 1, uses up to 6 fraction digits; otherwise uses 2.
    func toCurrency() -> String {
        let absValue = Swift.abs(self)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.roundingMode = .halfUp

        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = (absValue < 1) ? 6 : 2

        let numberString = formatter.string(from: NSNumber(value: self)) ?? String(self)
        return "$" + numberString
    }

    /// Formats as `+%2,50` or `-%1,20` (always 2 fraction digits, Turkish separators).
    func toPercentChange() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.roundingMode = .halfUp
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let absString = formatter.string(from: NSNumber(value: Swift.abs(self))) ?? String(Swift.abs(self))
        let sign = (self >= 0) ? "+" : "-"
        return "\(sign)%\(absString)"
    }

    /// Abbreviates numbers (e.g. `1.2M`, `500K`).
    var formattedString: String {
        let value = self
        let absValue = Swift.abs(value)

        let (divisor, suffix): (Double, String) = {
            switch absValue {
            case 1_000_000_000_000...:
                return (1_000_000_000_000, "T")
            case 1_000_000_000...:
                return (1_000_000_000, "B")
            case 1_000_000...:
                return (1_000_000, "M")
            case 1_000...:
                return (1_000, "K")
            default:
                return (1, "")
            }
        }()

        if divisor == 1 {
            // For non-abbreviated values, keep as-is with minimal noise.
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = "."
            formatter.decimalSeparator = ","
            formatter.usesGroupingSeparator = true
            formatter.roundingMode = .halfUp
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }

        let short = value / divisor
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.usesGroupingSeparator = false
        formatter.roundingMode = .halfUp

        let absShort = Swift.abs(short)
        if absShort < 10 {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 1
        } else {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        }

        let shortString = formatter.string(from: NSNumber(value: short)) ?? String(short)
        return shortString + suffix
    }
}

