import Cocoa

let packageName = Bundle.main.bundleIdentifier!
let packageVersion =
  Bundle.main.infoDictionary?["CFBundleShortVersionString"]
  as? String ?? "n/a"
