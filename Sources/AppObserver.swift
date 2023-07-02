import Cocoa

func getCurrentAppPID() throws -> pid_t {
  let currentApp: AXUIElement = try AXUIElementCreateSystemWide().getValue(
    forKey: kAXFocusedApplicationAttribute
  )
  var res: pid_t = 0
  try AXUIElementGetPid(currentApp, &res).unwrap()
  return res
}

func getAppBundleID(forPID pid: pid_t) -> String? {
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
