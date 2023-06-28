import AppKit

let currentAppObserver = NSWorkspace
  .shared
  .notificationCenter
  .publisher(for: NSWorkspace.didActivateApplicationNotification)
  .sink { notification in
    guard
      let info =
        notification.userInfo?[NSWorkspace.applicationUserInfoKey]
        as? NSRunningApplication,
      let identifier = info.bundleIdentifier
    else {
      return
    }

    // TODO: Remove this
    print("Switching to app: \(identifier)")
  }

CFRunLoopRun()
