import WeatherKit
import CoreLocation
import Observation

// MARK: - Event structs

struct ESunEvents {
    var sunrise:   Date?
    var solarNoon: Date?
    var sunset:    Date?
    var civilDawn: Date?
    var civilDusk: Date?
}

struct EMoonEvents {
    var moonrise: Date?
    var moonset:  Date?
    var phase:    MoonPhase?

    var phaseLabel: String {
        guard let p = phase else { return "" }
        switch p {
        case .new:            return "New Moon"
        case .waxingCrescent: return "Waxing Crescent"
        case .firstQuarter:   return "First Quarter"
        case .waxingGibbous:  return "Waxing Gibbous"
        case .full:           return "Full Moon"
        case .waningGibbous:  return "Waning Gibbous"
        case .lastQuarter:    return "Last Quarter"
        case .waningCrescent: return "Waning Crescent"
        @unknown default:     return "Unknown"
        }
    }

    var phaseEmoji: String {
        guard let p = phase else { return "" }
        switch p {
        case .new:            return "🌑"
        case .waxingCrescent: return "🌒"
        case .firstQuarter:   return "🌓"
        case .waxingGibbous:  return "🌔"
        case .full:           return "🌕"
        case .waningGibbous:  return "🌖"
        case .lastQuarter:    return "🌗"
        case .waningCrescent: return "🌘"
        @unknown default:     return "🌙"
        }
    }
}

// MARK: - Service

@Observable
final class EWeatherService {

    static let shared = EWeatherService()
    private init() {}

    private(set) var sunEvents:  ESunEvents?  = nil
    private(set) var moonEvents: EMoonEvents? = nil
    private(set) var isLoading = false
    private(set) var error: String? = nil

    // Cache key — avoid re-fetching for same location+day
    private var lastLat:  Double? = nil
    private var lastLon:  Double? = nil
    private var lastDay:  String? = nil   // "yyyy-MM-dd"

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    func fetch(latitude: Double, longitude: Double, date: Date) async {
        let dayKey = Self.dayFmt.string(from: date)

        // Same spot (< ~1 km) and same calendar day — skip
        if let lLat = lastLat, let lLon = lastLon, let lDay = lastDay {
            let dLat = abs(latitude  - lLat)
            let dLon = abs(longitude - lLon)
            if dLat < 0.01 && dLon < 0.01 && dayKey == lDay { return }
        }

        isLoading = true
        error     = nil

        do {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let weather  = try await WeatherService.shared.weather(
                for: location,
                including: .daily
            )

            let cal = Calendar.current
            if let day = weather.forecast.first(where: {
                cal.isDate($0.date, inSameDayAs: date)
            }) {
                sunEvents = ESunEvents(
                    sunrise:   day.sun.sunrise,
                    solarNoon: day.sun.solarNoon,
                    sunset:    day.sun.sunset,
                    civilDawn: day.sun.civilDawn,
                    civilDusk: day.sun.civilDusk
                )
                moonEvents = EMoonEvents(
                    moonrise: day.moon.moonrise,
                    moonset:  day.moon.moonset,
                    phase:    day.moon.phase
                )
            }

            lastLat = latitude
            lastLon = longitude
            lastDay = dayKey
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
