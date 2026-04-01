/**
 * VERİ ENTEGRASYONU - ZAMAN VE TARİH YÖNETİMİ (COMPLETED)
 * Bu araçlar, API'den gelen karmaşık tarih verilerini (Haberler/İşlemler)
 * '5 dakika önce' veya '13:45' gibi kullanıcı dostu formatlara çevirir.
 * UI tasarımında zaman gösterimlerini standart hale getirir.
 */
```


import Foundation

extension Date {
  /// Haber zamanı gibi "5 dk önce", "2 saat önce", "Dün" formatı üretir.
  /// Daha eski tarihler için `toShortDateString()` döndürür.
  func timeAgoDisplay(referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
    let seconds = Int(referenceDate.timeIntervalSince(self))
    if seconds <= 0 { return "az önce" }

    if seconds < 60 {
      return "az önce"
    }

    if seconds < 60 * 60 {
      let minutes = max(1, seconds / 60)
      return "\(minutes) dk önce"
    }

    if seconds < 60 * 60 * 24 {
      let hours = max(1, seconds / (60 * 60))
      return "\(hours) saat önce"
    }

    if calendar.isDateInYesterday(self) {
      return "Dün"
    }

    let dayDiff = calendar.dateComponents([.day], from: calendar.startOfDay(for: self), to: calendar.startOfDay(for: referenceDate)).day ?? 0
    if dayDiff > 1 && dayDiff < 7 {
      return "\(dayDiff) gün önce"
    }

    return toShortDateString()
  }

  /// "01 Nis" gibi kısa tarih formatı.
  func toShortDateString(locale: Locale = Locale(identifier: "tr_TR")) -> String {
    let formatter = DateFormatter.threadCached(key: "DateExt.shortDate.tr") {
      let df = DateFormatter()
      df.locale = locale
      df.calendar = .current
      df.timeZone = .current
      df.dateFormat = "dd MMM"
      return df
    }
    return formatter.string(from: self)
  }

  /// "13:45" gibi saat:dakika formatı.
  func toHourAndMinute(locale: Locale = Locale(identifier: "tr_TR")) -> String {
    let formatter = DateFormatter.threadCached(key: "DateExt.hourMinute.tr") {
      let df = DateFormatter()
      df.locale = locale
      df.calendar = .current
      df.timeZone = .current
      df.dateFormat = "HH:mm"
      return df
    }
    return formatter.string(from: self)
  }
}

private extension DateFormatter {
  static func threadCached(key: String, factory: () -> DateFormatter) -> DateFormatter {
    let dict = Thread.current.threadDictionary
    if let cached = dict[key] as? DateFormatter {
      return cached
    }
    let created = factory()
    dict[key] = created
    return created
  }
}
