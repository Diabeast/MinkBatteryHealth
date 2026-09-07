import Capacitor
import Foundation
import WidgetKit

@objc(WidgetBridgePlugin)
public class WidgetBridgePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "WidgetBridgePlugin"
    public let jsName = "WidgetBridge"
    public let pluginMethods: [CAPPluginMethod] = [CAPPluginMethod(name: "update", returnType: CAPPluginReturnPromise)]
    @objc func update(_ call: CAPPluginCall) {
        guard let defaults = UserDefaults(suiteName: "group.com.9CGZ7BWVXT.minkbatteryhealth") else { call.reject("Gedeelde opslag niet beschikbaar"); return }
        ["serverUrl", "apiKey", "address", "state"].forEach { if let value = call.getString($0) { defaults.set(value, forKey: $0) } }
        if let value = call.getString("updatedAt"), let date = ISO8601DateFormatter().date(from: value) { defaults.set(date.timeIntervalSince1970, forKey: "updatedAtTimestamp") }
        if let value = call.getInt("percent") { defaults.set(value, forKey: "percent") }
        if let value = call.getInt("range") { defaults.set(value, forKey: "range") }
        if let value = call.getInt("health") { defaults.set(value, forKey: "health") }
        defaults.set(UUID().uuidString, forKey: "snapshotRevision")
        defaults.synchronize()
        DispatchQueue.main.async {
            WidgetCenter.shared.reloadAllTimelines()
            call.resolve(["updated": true])
        }
    }
}
