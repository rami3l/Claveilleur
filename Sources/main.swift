import AppKit
import Carbon
import Combine

// TODO: Use Apple unified logging to replace `print`s: https://github.com/chrisaljoudi/swift-log-oslog

// TODO: Add CLI interface: launch (normal), --(un)?install-service, --(start|stop|restart)-service

// Special thanks to <https://stackoverflow.com/questions/36264038/cocoa-programmatically-detect-frontmost-floating-windows>
// for providing the necessary directions of implementing Spotlight support.

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

let currentInputSourceObserver = NotificationCenter
  .default
  .publisher(for: NSTextInputContext.keyboardSelectionDidChangeNotification)
  .map { _ in getInputSource() }
  .removeDuplicates()
  .sink { inputSource in
    guard let currentApp = getCurrentAppBundleID() else {
      return
    }

    print("Switching to input source: \(inputSource)")
    saveInputSource(inputSource, forApp: currentApp)
  }

class RunningAppsObserver: NSObject {
  @objc var currentWorkSpace: NSWorkspace
  var rawObserver: NSKeyValueObservation?

  var windowChangeObservers = [pid_t: WindowChangeObserver?]()

  convenience override init() {
    self.init(workspace: NSWorkspace.shared)
  }

  init(workspace: NSWorkspace) {
    currentWorkSpace = workspace
    windowChangeObservers =
      Dictionary(
        uniqueKeysWithValues:
          Self.getWindowChangePIDs(for: currentWorkSpace)
          .map { ($0, try? WindowChangeObserver(pid: $0)) }
      )
    super.init()

    rawObserver = currentWorkSpace.observe(\.runningApplications) {
      workspace,
      _ in
      let oldKeys = Set(self.windowChangeObservers.keys)
      let newKeys = Self.getWindowChangePIDs(for: workspace)

      let toRemove = oldKeys.subtracting(newKeys)
      if !toRemove.isEmpty {
        print("- windowChangeObservers: \(toRemove)")
      }
      toRemove.forEach {
        self.windowChangeObservers.removeValue(forKey: $0)
      }

      let toAdd = newKeys.subtracting(oldKeys)
      if !toAdd.isEmpty {
        print("+ windowChangeObservers: \(toAdd)")
      }
      toAdd.forEach {
        self.windowChangeObservers[$0] = try? WindowChangeObserver(pid: $0)
      }
    }
  }

  static func getWindowChangePIDs(
    for workspace: NSWorkspace
  ) -> Set<pid_t> {
    // https://apple.stackexchange.com/a/317705
    // https://gist.github.com/ljos/3040846
    // https://stackoverflow.com/a/61688877
    let includingWindowAppPIDs =
      (CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID)!
      as Array)
      .compactMap { $0.object(forKey: kCGWindowOwnerPID) as? pid_t }

    return Set(
      workspace.runningApplications.lazy
        .map { $0.processIdentifier }
        .filter { includingWindowAppPIDs.contains($0) }
    )
  }
}

// https://stackoverflow.com/a/38928864
let focusedWindowChangedNotification =
  Notification.Name("claveilleur-focused-window-changed")
let appHiddenNotification =
  Notification.Name("claveilleur-app-hidden")

let focusedWindowChangedPublisher = NSWorkspace
  .shared
  .notificationCenter
  .publisher(for: Claveilleur.focusedWindowChangedNotification)
  .compactMap { getAppBundleID(forPID: $0.object as! pid_t) }

let didActivateAppPublisher = NSWorkspace
  .shared
  .notificationCenter
  .publisher(
    for: NSWorkspace.didActivateApplicationNotification
  )
  .compactMap { notif in
    let userInfo =
      notif.userInfo?[NSWorkspace.applicationUserInfoKey]
      as? NSRunningApplication
    return userInfo?.bundleIdentifier
  }

let appHiddenPublisher = NSWorkspace
  .shared
  .notificationCenter
  .publisher(for: Claveilleur.appHiddenNotification)
  .compactMap { _ in getCurrentAppBundleID() }

let appActivatedObserver =
  focusedWindowChangedPublisher
  .merge(with: didActivateAppPublisher, appHiddenPublisher)
  .removeDuplicates()
  .sink { currentApp in
    print("ping from \(currentApp)")

    // TODO: Uncomment those.
    // print("Switching to app: \(currentApp)")
    // guard
    //   let oldInputSource = userDefaults.string(forKey: currentApp),
    //   setInputSource(to: oldInputSource)
    // else {
    //   let newInputSource = getInputSource()
    //   saveInputSource(newInputSource, forApp: currentApp)
    //   return
    // }
  }

enum AXUIError: Error {
  case axError(String)
  case typeCastError(String)
}

extension AXUIElement {
  func getValue<T>(forKey key: String) throws -> T {
    var res: AnyObject?
    try AXUIElementCopyAttributeValue(self, key as CFString, &res).unwrap()
    guard let res = res as? T else {
      throw AXUIError.typeCastError("downcast failed from `\(type(of: res))` to `\(T.self)`")
    }
    return res
  }
}

extension AXError {
  func unwrap() throws {
    guard case .success = self else {
      throw AXUIError.axError("AXUI function failed with `\(self)`")
    }
  }
}

func getCurrentAppPID() throws -> pid_t {
  let currentApp: AXUIElement = try AXUIElementCreateSystemWide().getValue(
    forKey: kAXFocusedApplicationAttribute
  )
  var res: pid_t = 0
  try AXUIElementGetPid(currentApp, &res).unwrap()
  return res
}

private func getAppBundleID(forPID pid: pid_t) -> String? {
  let currentApp = NSWorkspace.shared.runningApplications.first {
    $0.processIdentifier == pid
  }
  return currentApp?.bundleIdentifier
}

func getCurrentAppBundleID() -> String? {
  guard let currentAppPID = try? getCurrentAppPID() else {
    return nil
  }
  return getAppBundleID(forPID: currentAppPID)
}

// https://juejin.cn/post/6919716600543182855
class WindowChangeObserver: NSObject {
  var currentAppPID: pid_t
  var element: AXUIElement
  var rawObserver: AXObserver?

  let notifNames =
    [
      kAXFocusedWindowChangedNotification:
        Claveilleur.focusedWindowChangedNotification,
      kAXApplicationHiddenNotification:
        Claveilleur.appHiddenNotification,
    ] as [CFString: Notification.Name]

  let observerCallbackWithInfo: AXObserverCallbackWithInfo = {
    (observer, element, notif, userInfo, refcon) in
    guard let refcon = refcon else {
      return
    }
    let slf = Unmanaged<WindowChangeObserver>.fromOpaque(refcon).takeUnretainedValue()
    print("should \(notif) from \(slf.currentAppPID)")

    guard let notifName = slf.notifNames[notif] else {
      return
    }
    NSWorkspace.shared.notificationCenter.post(
      name: notifName,
      object: slf.currentAppPID
    )
  }

  init(pid: pid_t) throws {
    currentAppPID = pid
    element = AXUIElementCreateApplication(currentAppPID)
    super.init()

    try AXObserverCreateWithInfoCallback(
      currentAppPID,
      observerCallbackWithInfo,
      &rawObserver
    )
    .unwrap()

    let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    try notifNames.keys.forEach {
      try AXObserverAddNotification(rawObserver!, element, $0, selfPtr).unwrap()
    }
    CFRunLoopAddSource(
      CFRunLoopGetCurrent(),
      AXObserverGetRunLoopSource(rawObserver!),
      CFRunLoopMode.defaultMode
    )
  }

  deinit {
    CFRunLoopRemoveSource(
      CFRunLoopGetCurrent(),
      AXObserverGetRunLoopSource(rawObserver!),
      CFRunLoopMode.defaultMode
    )
    notifNames.keys.forEach {
      do {
        try AXObserverRemoveNotification(rawObserver!, element, $0).unwrap()
      } catch {}
    }
  }
}

let runningAppsObserver = RunningAppsObserver()

CFRunLoopRun()
