import Cocoa

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
        log.debug("RunningAppsObserver: removing from windowChangeObservers: \(toRemove)")
      }
      toRemove.forEach {
        self.windowChangeObservers.removeValue(forKey: $0)
      }

      let toAdd = newKeys.subtracting(oldKeys)
      if !toAdd.isEmpty {
        log.debug("RunningAppsObserver: adding to windowChangeObservers: \(toAdd)")
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
      (CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID)! as Array)
      .compactMap { $0.object(forKey: kCGWindowOwnerPID) as? pid_t }

    // HACK: When hiding some system apps, `AXApplicationHidden` is not sent.
    // We exclude these apps from the observation for now.
    // See: https://github.com/rami3l/Claveilleur/issues/3
    let specialSystemAppIDs = Set<String?>([
      "com.apple.controlcenter",
      "com.apple.notificationcenterui",
    ])

    return Set(
      workspace.runningApplications.lazy
        .filter { !specialSystemAppIDs.contains($0.bundleIdentifier) }
        .map { $0.processIdentifier }
        .filter { includingWindowAppPIDs.contains($0) }
    )
  }
}
