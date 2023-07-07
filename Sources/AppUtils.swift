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

func getAppBundleID(forNotification notif: NotificationCenter.Publisher.Output) -> String? {
  let runningApp =
    notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
  return runningApp?.bundleIdentifier
}

func getCurrentAppBundleID() -> String? {
  return (try? getCurrentAppPID()).flatMap(getAppBundleID(forPID:))
}
