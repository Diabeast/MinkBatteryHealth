import WidgetKit
import SwiftUI

private let suite = "group.com.9CGZ7BWVXT.minkbatteryhealth"

struct BatteryEntry: TimelineEntry {
    let date: Date
    let percent: Int
    let range: Int
    let health: Int
    let state: String
    let address: String
}

struct BatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryEntry { BatteryEntry(date: .now, percent: 59, range: 232, health: 94, state: "Slaapstand", address: "Laatste locatie") }
    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) { completion(storedEntry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        let fallback = storedEntry()
        guard let defaults = UserDefaults(suiteName: suite),
              let server = defaults.string(forKey: "serverUrl"),
              let key = defaults.string(forKey: "apiKey"), !key.isEmpty,
              let url = URL(string: server.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api/v1/mobile/summary") else {
            completion(Timeline(entries: [fallback], policy: .after(.now.addingTimeInterval(300))))
            return
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "_", value: String(Int(Date().timeIntervalSince1970)))]
        guard let freshURL = components?.url else {
            completion(Timeline(entries: [fallback], policy: .after(.now.addingTimeInterval(300))))
            return
        }
        var request = URLRequest(url: freshURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20)
        request.setValue(key, forHTTPHeaderField: "X-API-Key")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        URLSession.shared.dataTask(with: request) { data, response, _ in
            var entry = fallback
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(statusCode), let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let percent = Self.number(json["battery_percent"]) ?? Double(fallback.percent)
                let miles = Self.number(json["estimated_range"])
                let range = miles.map { Int(($0 * 1.609344).rounded()) } ?? fallback.range
                let address = Self.text(json["address"]) ?? fallback.address
                let state = Self.state(json) ?? fallback.state
                entry = BatteryEntry(date: .now, percent: Int(percent.rounded()), range: range, health: fallback.health, state: state, address: address)
                defaults.set(entry.percent, forKey: "percent"); defaults.set(entry.range, forKey: "range"); defaults.set(entry.address, forKey: "address"); defaults.set(entry.state, forKey: "state"); defaults.set(entry.date.timeIntervalSince1970, forKey: "updatedAtTimestamp")
            }
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(300))))
        }.resume()
    }
    private static func number(_ object: Any?) -> Double? {
        guard let object else { return nil }
        if let dictionary = object as? [String: Any] { return number(dictionary["value"]) }
        if let value = object as? NSNumber { return value.doubleValue }
        if let value = object as? String { return Double(value) }
        return nil
    }
    private static func text(_ object: Any?) -> String? {
        guard let object else { return nil }
        if let dictionary = object as? [String: Any] { return text(dictionary["value"]) }
        if let value = object as? String, !value.isEmpty { return value }
        return nil
    }
    private static func state(_ json: [String: Any]) -> String? {
        guard let value = json["connectivity"] else { return nil }
        let raw: Any = (value as? [String: Any])?["value"] ?? value
        let text = String(describing: raw).lowercased()
        return text.contains("connect") ? "Online" : "Slaapstand"
    }
    private func storedEntry() -> BatteryEntry {
        let defaults = UserDefaults(suiteName: suite)
        let percent = defaults?.object(forKey: "percent") == nil ? 59 : defaults?.integer(forKey: "percent") ?? 59
        let range = defaults?.object(forKey: "range") == nil ? 232 : defaults?.integer(forKey: "range") ?? 232
        let health = defaults?.object(forKey: "health") == nil ? 94 : defaults?.integer(forKey: "health") ?? 94
        let timestamp = defaults?.double(forKey: "updatedAtTimestamp") ?? 0
        return BatteryEntry(date: timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : .now, percent: percent, range: range, health: health, state: defaults?.string(forKey: "state") ?? "Laatst bekend", address: defaults?.string(forKey: "address") ?? "Locatie nog niet geladen")
    }
}

struct BatteryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: BatteryEntry

    private var background: Color { colorScheme == .dark ? Color(red: 0.035, green: 0.039, blue: 0.047) : Color(red: 0.965, green: 0.965, blue: 0.955) }
    private var primary: Color { colorScheme == .dark ? .white : Color(red: 0.035, green: 0.039, blue: 0.047) }
    private var secondary: Color { colorScheme == .dark ? Color(red: 0.76, green: 0.78, blue: 0.81) : Color(red: 0.24, green: 0.25, blue: 0.27) }
    private let green = Color(red: 0.27, green: 0.82, blue: 0.57)
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
    private var brand: some View { Text("MINK BATTERY HEALTH").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(0.7).foregroundStyle(primary).lineLimit(1).minimumScaleFactor(0.8) }
    private var status: some View { HStack(spacing: 6) { Circle().fill(green).frame(width: 7, height: 7); Text(entry.state).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(secondary) } }
    private var bars: some View { HStack(alignment: .bottom, spacing: 4) { ForEach(0..<10, id: \.self) { index in RoundedRectangle(cornerRadius: 2).fill(index < max(1, Int((Double(entry.percent) / 100) * 10)) ? green : secondary.opacity(0.28)).frame(maxWidth: .infinity).frame(height: index % 4 == 0 ? 18 : index % 3 == 0 ? 14 : 11) } }.frame(height: 20) }
    private var small: some View { VStack(alignment: .leading, spacing: 5) { HStack { Text("BATTERY HEALTH \(entry.health)%").font(.system(size: 8, weight: .bold)).tracking(0.3).foregroundStyle(secondary); Spacer(); status }; HStack(alignment: .firstTextBaseline, spacing: 6) { Text("\(entry.percent)%").font(.system(size: 39, weight: .semibold, design: .rounded)).foregroundStyle(green).minimumScaleFactor(0.8); Text("\(entry.range) km").font(.system(size: 13, weight: .bold, design: .rounded)).minimumScaleFactor(0.8) }; bars; Spacer(minLength: 1); Text(entry.address).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(primary).lineLimit(2).minimumScaleFactor(0.75) }.padding(12) }
    private var medium: some View { HStack(spacing: 14) { VStack(alignment: .leading, spacing: 5) { Text("BATTERY HEALTH \(entry.health)%").font(.system(size: 9, weight: .bold)).tracking(0.45).foregroundStyle(secondary).lineLimit(1); status; Spacer(minLength: 0); Text("\(entry.percent)%").font(.system(size: 48, weight: .semibold, design: .rounded)).foregroundStyle(green).lineLimit(1).minimumScaleFactor(0.8); HStack(spacing: 6) { Image(systemName: batteryIcon).foregroundStyle(green); Text("\(entry.range) km").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(primary) } }.frame(maxWidth: .infinity, alignment: .leading); Rectangle().fill(secondary.opacity(0.38)).frame(width: 1); VStack(alignment: .leading, spacing: 6) { Text("LAATSTE LOCATIE").font(.system(size: 10, weight: .bold)).tracking(0.65).foregroundStyle(secondary); Text(entry.address).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(primary).lineLimit(3).minimumScaleFactor(0.78); Spacer(minLength: 1); Text("Bijgewerkt \(entry.date, style: .relative)").font(.system(size: 10, weight: .semibold)).foregroundStyle(secondary) }.frame(maxWidth: 158, alignment: .leading) }.padding(14) }
    private var large: some View { VStack(alignment: .leading, spacing: 14) { HStack { brand; Spacer(); status }; HStack(alignment: .firstTextBaseline, spacing: 8) { Text("\(entry.percent)%").font(.system(size: 66, weight: .medium, design: .rounded)).foregroundStyle(green); Text("batterij").font(.title3.weight(.semibold)).foregroundStyle(secondary) }; bars; Divider().overlay(secondary.opacity(0.35)); HStack { VStack(alignment: .leading, spacing: 4) { Text("ACTIERADIUS").font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(secondary); Text("\(entry.range) km").font(.title.weight(.semibold)) }; Spacer(); Image(systemName: batteryIcon).font(.system(size: 32, weight: .semibold)).foregroundStyle(green) }; Spacer(); VStack(alignment: .leading, spacing: 6) { Text("LAATSTE LOCATIE").font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(secondary); Text(entry.address).font(.title3.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.85) }; Text("Bijgewerkt \(entry.date, style: .relative)").font(.system(size: 11, weight: .medium)).foregroundStyle(secondary) }.padding(17) }
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
