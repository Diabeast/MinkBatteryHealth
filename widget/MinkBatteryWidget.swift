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
    @Environment(\.colorScheme) private var colorScheme
    let entry: BatteryEntry

    private var background: Color { colorScheme == .dark ? Color(red: 0.035, green: 0.039, blue: 0.047) : Color(red: 0.965, green: 0.965, blue: 0.955) }
    private var primary: Color { colorScheme == .dark ? .white : Color(red: 0.035, green: 0.039, blue: 0.047) }
    private var secondary: Color { colorScheme == .dark ? Color(red: 0.60, green: 0.62, blue: 0.66) : Color(red: 0.34, green: 0.35, blue: 0.37) }
    private let green = Color(red: 0.21, green: 0.68, blue: 0.47)
    private var batteryIcon: String { entry.percent >= 88 ? "battery.100" : entry.percent >= 63 ? "battery.75" : entry.percent >= 38 ? "battery.50" : entry.percent >= 13 ? "battery.25" : "battery.0" }

    var body: some View {
        ZStack {
            background
            switch family {
            case .systemSmall: small
            case .systemLarge: large
            default: medium
            }
        }
        .foregroundStyle(primary)
        .widgetBackground(background)
    }
    private var brand: some View { Text("MINK BATTERY HEALTH").font(.system(size: 10, weight: .semibold, design: .rounded)).tracking(1.15).foregroundStyle(primary) }
    private var status: some View { HStack(spacing: 5) { Circle().fill(green).frame(width: 6, height: 6); Text(entry.state).font(.caption2).foregroundStyle(secondary) } }
    private var bars: some View { HStack(alignment: .bottom, spacing: 3) { ForEach(0..<12, id: \.self) { index in RoundedRectangle(cornerRadius: 1.5).fill(index < max(1, Int((Double(entry.percent) / 100) * 12)) ? green : secondary.opacity(0.2)).frame(height: index % 5 == 0 ? 16 : index % 3 == 0 ? 12 : 9) } }.frame(height: 18) }
    private var small: some View { VStack(alignment: .leading, spacing: 7) { brand; status; Spacer(); Text("\(entry.percent)%").font(.system(size: 38, weight: .light, design: .rounded)).foregroundStyle(green); bars; HStack { Text("\(entry.range) km").font(.caption.weight(.medium)); Spacer(); Image(systemName: batteryIcon).foregroundStyle(green) } }.padding(15) }
    private var medium: some View { HStack(spacing: 22) { VStack(alignment: .leading, spacing: 7) { brand; status; Spacer(); HStack(alignment: .firstTextBaseline, spacing: 5) { Text("\(entry.percent)%").font(.system(size: 43, weight: .light, design: .rounded)).foregroundStyle(green); Text("\(entry.range) km").font(.subheadline.weight(.medium)).foregroundStyle(primary) }; bars }; Rectangle().fill(secondary.opacity(0.22)).frame(width: 1); VStack(alignment: .leading, spacing: 6) { Text("LAATSTE LOCATIE").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(secondary); Text(entry.address).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(primary).lineLimit(3); Spacer(); Text(entry.date, style: .relative).font(.caption2).foregroundStyle(secondary) }.frame(maxWidth: 145, alignment: .leading) }.padding(16) }
    private var large: some View { VStack(alignment: .leading, spacing: 13) { HStack { brand; Spacer(); status }; HStack(alignment: .firstTextBaseline, spacing: 7) { Text("\(entry.percent)%").font(.system(size: 62, weight: .ultraLight, design: .rounded)).foregroundStyle(green); Text("batterij").font(.headline).foregroundStyle(secondary) }; bars; Divider().overlay(secondary.opacity(0.25)); HStack { VStack(alignment: .leading, spacing: 3) { Text("ACTIERADIUS").font(.caption2).tracking(1).foregroundStyle(secondary); Text("\(entry.range) km").font(.title2.weight(.medium)) }; Spacer(); Image(systemName: batteryIcon).font(.title).foregroundStyle(green) }; Spacer(); VStack(alignment: .leading, spacing: 5) { Text("LAATSTE LOCATIE").font(.caption2).tracking(1).foregroundStyle(secondary); Text(entry.address).font(.body.weight(.medium)).lineLimit(2) }; Text("Bijgewerkt \(entry.date, style: .relative)").font(.caption2).foregroundStyle(secondary) }.padding(18) }
}

private extension View {
    @ViewBuilder func widgetBackground(_ color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) { containerBackground(for: .widget) { color } } else { background(color) }
    }
}

@main struct MinkBatteryWidgets: WidgetBundle {
    var body: some Widget { MinkBatteryWidget() }
}
struct MinkBatteryWidget: Widget {
    var body: some WidgetConfiguration { StaticConfiguration(kind: "MinkBatteryWidget", provider: BatteryProvider()) { BatteryWidgetView(entry: $0) }.configurationDisplayName("Tesla Mink").description("Batterij, bereik, status en locatie.").supportedFamilies([.systemSmall, .systemMedium, .systemLarge]) }
}
