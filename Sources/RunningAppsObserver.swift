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
