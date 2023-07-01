import AppKit
import Carbon

// TODO: Use Apple unified logging to replace `print`s: https://github.com/chrisaljoudi/swift-log-oslog

// TODO: Add CLI interface: launch (normal), --(un)?install-service, --(start|stop|restart)-service

// TODO: Handle spotlight: https://stackoverflow.com/questions/36264038/cocoa-programmatically-detect-frontmost-floating-windows

let suiteName = "io.github.rami3l.Claveilleur"
let userDefaults = UserDefaults(suiteName: suiteName)!

func saveInputSource(_ id: String, forApp appID: String) {
  userDefaults.set(id, forKey: appID)
}

// https://github.com/mzp/EmojiIM/issues/27#issue-1361876711
func getInputSource() -> String {
  let inputSource = TISCopyCurrentKeyboardInputSource().takeUnretainedValue()
  return unsafeBitCast(
    TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID),
    to: NSString.self
  ) as String
}

// https://github.com/daipeihust/im-select/blob/83046bb75333e58c9a7cbfbd055db6f360361781/macOS/im-select/im-select/main.m
func setInputSource(to id: String) -> Bool {
  if getInputSource() == id {
    return true
  }
  print("Restoring input source to: \(id)")
  let filter = [kTISPropertyInputSourceID!: id] as NSDictionary
  let inputSources =
    TISCreateInputSourceList(filter, false).takeUnretainedValue()
    as NSArray as! [TISInputSource]
  guard !inputSources.isEmpty else {
    return false
  }
  let inputSource = inputSources[0]
  TISSelectInputSource(inputSource)
  return true
}

func getCurrentAppID() -> String? {
  let currentApp = NSWorkspace.shared.frontmostApplication
  return currentApp?.bundleIdentifier
}

let currentInputSourceObserver = NotificationCenter
  .default
  .publisher(for: NSTextInputContext.keyboardSelectionDidChangeNotification)
  .map { _ in getInputSource() }
  .removeDuplicates()
  .sink { inputSource in
    guard let currentApp = getCurrentAppID() else {
      return
    }

    print("Switching to input source: \(inputSource)")
    saveInputSource(inputSource, forApp: currentApp)
  }

// let currentAppObserver = NSWorkspace
//   .shared
//   .notificationCenter
//   .publisher(for: NSWindow.didBecomeKeyNotification)
//   .sink { notification in
//     guard let currentApp = getCurrentAppID() else {
//       return
//     }

//     print("Switching to app: \(currentApp)")
//     guard
//       let oldInputSource = userDefaults.string(forKey: currentApp),
//       setInputSource(to: oldInputSource)
//     else {
//       let newInputSource = getInputSource()
//       saveInputSource(newInputSource, forApp: currentApp)
//       return
//     }
//   }

// class CurrentAppObserver: NSObject {
//   @objc var currentWorkSpace: NSWorkspace
//   var observation: NSKeyValueObservation?

//   convenience override init() {
//     self.init(workspace: NSWorkspace.shared)
//   }

//   init(workspace: NSWorkspace) {
//     currentWorkSpace = workspace
//     super.init()

//     observation = observe(
//       \.currentWorkSpace.frontmostApplication,
//       options: [.new]
//     ) { _, change in
//       print("switching to \(change.newValue!!.bundleIdentifier! as String)")
//     }
//   }
// }

// let currentAppObserver = CurrentAppObserver()

// https://apple.stackexchange.com/a/317705
// https://gist.github.com/ljos/3040846
// https://stackoverflow.com/a/61688877
let onScreenAppPIDs =
  (CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)!
  as Array)
  .compactMap { $0.object(forKey: kCGWindowOwnerPID) as? pid_t }

// TODO: Observe the changes of runningApplications.
let runningApps = NSWorkspace
  .shared
  .runningApplications
  .filter { onScreenAppPIDs.contains($0.processIdentifier) }

// TODO: Listen for `NSAccessibilityFocusedWindowChangedNotification` for each pid
// https://developer.apple.com/documentation/appkit/nsaccessibilityfocusedwindowchangednotification

// runningApps.forEach { print($0) }

// https://juejin.cn/post/6919528826196197390
// let systemWideAXUIElement = AXUIElementCreateSystemWide()
// var names: CFArray?
// let error: AXError = AXUIElementCopyAttributeNames(systemWideAXUIElement, &names)
// for name in names as! [String] {
//   print("attribute name \(name)")
//   var value: AnyObject?
//   let error: AXError = AXUIElementCopyAttributeValue(
//     systemWideAXUIElement, name as CFString, &value)
//   print("value \(value as! AXValue)")
// }

// func test(for element: AXUIElement) throws {
//   let focusedWindow: AXUIElement = try element.getValue(forKey: kAXFocusedWindowAttribute).get()
//   var names: CFArray?
//   AXUIElementCopyAttributeNames(focusedWindow, &names)
//   for name in names as! [String] {
//     print("attribute name \(name)")
//   }
//   let isFocused: AXValue = try focusedWindow.getValue(forKey: kAXFocusedAttribute).get()
//   print("isFocused: ", isFocused)
//   let isMain: AXValue = try focusedWindow.getValue(forKey: kAXMainAttribute).get()
//   print("isMain: ", isMain)
// }

enum AXUIError: Error {
  case axError(String)
  case typeCastError(String)
}

extension AXUIElement {
  func getValue<T>(forKey key: String) throws -> T {
    var res: AnyObject?
    let axResult = AXUIElementCopyAttributeValue(self, key as CFString, &res)
    guard case .success = axResult else {
      throw AXUIError.axError("AXUI function failed with `\(axResult)`")
    }
    guard let res = res as? T else {
      throw AXUIError.typeCastError("downcast failed from `\(type(of: res))` to `\(T.self)`")
    }
    return res
  }
}

// try runningApps.forEach {
//   print(" - ", $0.bundleIdentifier ?? "n/a")
//   let element = AXUIElementCreateApplication($0.processIdentifier)
//   do { try test(for: element) } catch let e { print(e) }
// }

// print(runningApps)
// let currentApp: AXUIElement = try AXUIElementCreateSystemWide().getValue(
//   forKey: kAXFocusedApplicationAttribute
// )
// print(currentApp)
// var names: CFArray?
// AXUIElementCopyAttributeNames(currentApp, &names)
// for name in names as! [String] {
//   print("attribute name \(name)")
// }

func getCurrentAppID() throws -> pid_t {
  let currentApp: AXUIElement = try AXUIElementCreateSystemWide().getValue(
    forKey: kAXFocusedApplicationAttribute
  )
  var res: pid_t = 0
  let axResult = AXUIElementGetPid(currentApp, &res)
  guard case .success = axResult else {
    throw AXUIError.axError("AXUI function failed with `\(axResult)`")
  }
  return res
}

class CurrentAppObserver: NSObject {
  @objc dynamic var currentAppPID: pid_t {
    return try! getCurrentAppID()
  }

  var observation: NSKeyValueObservation?

  override init() {
    super.init()

    observation = observe(
      \.currentAppPID,
      options: [.new]
    ) { _, change in
      print("switching to \(change.newValue!)")
    }
  }
}

let currentAppObserver = CurrentAppObserver()
CFRunLoopRun()
