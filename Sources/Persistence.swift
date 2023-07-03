import Cocoa

let userDefaults = UserDefaults(suiteName: packageName)!

func saveInputSource(_ id: String, forApp appID: String) {
  log.info("\(#function): saving input source for `\(appID)` to: \(id)")
  userDefaults.set(id, forKey: appID)
}
