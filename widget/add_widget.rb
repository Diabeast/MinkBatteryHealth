require "xcodeproj"
project_path = "ios/App/App.xcodeproj"
project = Xcodeproj::Project.open(project_path)
app = project.targets.find { |target| target.name == "App" }
raise "App target ontbreekt" unless app

group = project.main_group.find_subpath("MinkBatteryWidget", true)
group.set_source_tree("<group>")
widget_source = group.new_file("../../widget/MinkBatteryWidget.swift")
widget_plist = group.new_file("../../widget/Info.plist")
widget_entitlements = group.new_file("../../widget/Widget.entitlements")
bridge_source = project.main_group.find_subpath("App", true).new_file("../../../widget/WidgetBridgePlugin.swift")
bridge_controller_source = project.main_group.find_subpath("App", true).new_file("../../../widget/MinkBridgeViewController.swift")
app_entitlements = project.main_group.find_subpath("App", true).new_file("../../../widget/App.entitlements")

widget = project.new_target(:app_extension, "MinkBatteryWidget", :ios, "15.0")
widget.add_file_references([widget_source])
app.add_file_references([bridge_source, bridge_controller_source])
app.add_dependency(widget)
embed = app.copy_files_build_phases.find { |phase| phase.name == "Embed Foundation Extensions" } || app.new_copy_files_build_phase("Embed Foundation Extensions")
embed.dst_subfolder_spec = "13"
embed.add_file_reference(widget.product_reference, true)

widget.build_configurations.each do |config|
  config.build_settings["PRODUCT_NAME"] = "MinkBatteryWidget"
  config.build_settings["EXECUTABLE_NAME"] = "MinkBatteryWidget"
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.9CGZ7BWVXT.minkbatteryhealth.widget"
  config.build_settings["INFOPLIST_FILE"] = "../../widget/Info.plist"
  config.build_settings["CODE_SIGN_ENTITLEMENTS"] = "../../widget/Widget.entitlements"
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["APPLICATION_EXTENSION_API_ONLY"] = "YES"
  config.build_settings["SKIP_INSTALL"] = "YES"
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "15.0"
  config.build_settings["MARKETING_VERSION"] = "1.1"
  config.build_settings["CURRENT_PROJECT_VERSION"] = ENV.fetch("GITHUB_RUN_NUMBER", "1")
end
app.build_configurations.each do |config|
  config.build_settings["CODE_SIGN_ENTITLEMENTS"] = "../../widget/App.entitlements"
  config.build_settings["MARKETING_VERSION"] = "1.1"
end
project.save
