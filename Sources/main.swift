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

// TODO: Listen for `NSAccessibilityFocusedWindowChangedNotification` for each pid
// https://developer.apple.com/documentation/appkit/nsaccessibilityfocusedwindowchangednotification
class RunningAppsObserver: NSObject {
  @objc var currentWorkSpace: NSWorkspace
  var observation: NSKeyValueObservation?

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

    observation = currentWorkSpace.observe(
      \.runningApplications,
      options: [.new]
    ) { workspace, _ in
      // TODO: Should not recreate necessary observers.
      let oldKeys = Set(self.windowChangeObservers.keys)
      let newKeys = Self.getWindowChangePIDs(for: workspace)

      let toRemove = oldKeys.subtracting(newKeys)
      if !toRemove.isEmpty {
        print("- windowChangeObservers: \(toRemove)")
      }
      for key in toRemove {
        self.windowChangeObservers.removeValue(forKey: key)
      }

      let toAdd = newKeys.subtracting(oldKeys)
      if !toAdd.isEmpty {
        print("+ windowChangeObservers: \(toAdd)")
      }
      for key in toAdd {
        self.windowChangeObservers[key] = try? WindowChangeObserver(pid: key)
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

let focusedWindowChangedPublisher = NSWorkspace
  .shared
  .notificationCenter
  .publisher(for: Claveilleur.focusedWindowChangedNotification)
  .map { getAppBundleID(forPID: $0.object as! pid_t) }

let didActivateAppPublisher = NSWorkspace
  .shared
  .notificationCenter
  .publisher(
    for: NSWorkspace.didActivateApplicationNotification
  )
  .merge(
    with:
      NSWorkspace
      .shared
      .notificationCenter
      .publisher(for: NSWorkspace.didHideApplicationNotification)
  )
  .map { notif in
    let userInfo =
      notif.userInfo?[NSWorkspace.applicationUserInfoKey]
      as? NSRunningApplication
    return userInfo?.bundleIdentifier
  }

let currentAppObserver =
  focusedWindowChangedPublisher
  .merge(with: didActivateAppPublisher)
  // .removeDuplicates()
  .sink { currentApp in
    print("ping from \(currentApp)")
    // TODO: Should fix spotlight desactivation not detected.

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
      kAXFocusedWindowChangedNotification
    ] as [CFString]

  let observerCallbackWithInfo: AXObserverCallbackWithInfo = {
    (observer, element, notification, userInfo, refcon) in
    guard let refcon = refcon else {
      return
    }
    let slf = Unmanaged<WindowChangeObserver>.fromOpaque(refcon).takeUnretainedValue()
    print("should ping from \(slf.currentAppPID)")
    NSWorkspace.shared.notificationCenter.post(
      name: Claveilleur.focusedWindowChangedNotification,
      object: slf.currentAppPID
    )
  }

  init(pid: pid_t) throws {
    currentAppPID = pid
    element = AXUIElementCreateApplication(currentAppPID)
    super.init()

    try AXObserverCreateWithInfoCallback(currentAppPID, observerCallbackWithInfo, &rawObserver)
      .unwrap()

    let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    try notifNames.forEach {
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
    notifNames.forEach {
      do {
        try AXObserverRemoveNotification(rawObserver!, element, $0).unwrap()
      } catch {}
    }
  }
}

let runningAppsObserver = RunningAppsObserver()
// let foo = WindowChangeObserver(pid: 548)

CFRunLoopRun()
