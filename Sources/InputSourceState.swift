import Cocoa

var inputSourceState = [String: String]()

func loadInputSource(forApp appID: String) -> String? {
  // It's a pity that we don't have `.get()` in Swift...
  return inputSourceState.index(forKey: appID).map { inputSourceState[$0].1 }
}

func saveInputSource(_ id: String, forApp appID: String) {
  inputSourceState[appID] = id
}
