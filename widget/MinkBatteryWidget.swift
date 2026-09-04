import WidgetKit
import SwiftUI

private let suite = "group.com.9CGZ7BWVXT.minkbatteryhealth"

struct BatteryEntry: TimelineEntry {
    let date: Date
    let percent: Int
    let range: Int
    let state: String
    let address: String
}

struct BatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryEntry { BatteryEntry(date: .now, percent: 59, range: 232, state: "Slaapstand", address: "Laatste locatie") }
    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) { completion(storedEntry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        let fallback = storedEntry()
        guard let defaults = UserDefaults(suiteName: suite),
              let server = defaults.string(forKey: "serverUrl"),
              let key = defaults.string(forKey: "apiKey"), !key.isEmpty,
              let url = URL(string: server.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api/v1/mobile/summary") else {
            completion(Timeline(entries: [fallback], policy: .after(.now.addingTimeInterval(900))))
            return
        }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "X-API-Key")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            var entry = fallback
            if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let percent = Self.number(json["battery_percent"]) ?? Double(fallback.percent)
                let miles = Self.number(json["estimated_range"])
                let range = miles.map { Int(($0 * 1.609344).rounded()) } ?? fallback.range
                let address = json["address"] as? String ?? fallback.address
                entry = BatteryEntry(date: .now, percent: Int(percent.rounded()), range: range, state: "Laatst bekend", address: address)
                defaults.set(entry.percent, forKey: "percent"); defaults.set(entry.range, forKey: "range"); defaults.set(entry.address, forKey: "address")
            }
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
        }.resume()
    }
    private static func number(_ object: Any?) -> Double? {
        guard let object else { return nil }
        if let dictionary = object as? [String: Any] { return number(dictionary["value"]) }
        if let value = object as? NSNumber { return value.doubleValue }
        if let value = object as? String { return Double(value) }
        return nil
    }
    private func storedEntry() -> BatteryEntry {
        let defaults = UserDefaults(suiteName: suite)
        return BatteryEntry(date: .now, percent: defaults?.integer(forKey: "percent") ?? 59, range: defaults?.integer(forKey: "range") ?? 232, state: "Laatst bekend", address: defaults?.string(forKey: "address") ?? "Locatie nog niet geladen")
    }
}

struct BatteryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BatteryEntry
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.02, green: 0.12, blue: 0.23), Color(red: 0.01, green: 0.05, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if family == .systemSmall { small } else { medium }
        }
    }
    private var small: some View { VStack(alignment: .leading, spacing: 7) { Text("TESLA MINK").font(.caption2).foregroundStyle(.cyan); Spacer(); Text("\(entry.percent)%").font(.system(size: 39, weight: .light)); Text("\(entry.range) km").font(.headline).foregroundStyle(Color(red: 0.33, green: 0.95, blue: 0.68)); Text(entry.state).font(.caption2).foregroundStyle(.secondary) }.padding() }
    private var medium: some View { HStack { VStack(alignment: .leading, spacing: 6) { Text("TESLA MINK").font(.caption2).foregroundStyle(.cyan); Text("\(entry.percent)%").font(.system(size: 43, weight: .light)); Text("\(entry.range) km bereik").foregroundStyle(Color(red: 0.33, green: 0.95, blue: 0.68)) }; Spacer(); VStack(alignment: .trailing, spacing: 7) { Image(systemName: "moon.zzz.fill").foregroundStyle(.cyan); Text(entry.state).font(.caption); Text(entry.address).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.trailing).lineLimit(2) }.frame(maxWidth: 145) }.padding() }
}

@main struct MinkBatteryWidgets: WidgetBundle {
    var body: some Widget { MinkBatteryWidget() }
}
struct MinkBatteryWidget: Widget {
    var body: some WidgetConfiguration { StaticConfiguration(kind: "MinkBatteryWidget", provider: BatteryProvider()) { BatteryWidgetView(entry: $0) }.configurationDisplayName("Tesla Mink").description("Batterij, bereik, status en locatie.").supportedFamilies([.systemSmall, .systemMedium, .systemLarge]) }
}
