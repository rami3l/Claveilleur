import Cocoa

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

func getCurrentAppPID() throws -> pid_t {
  let currentApp: AXUIElement = try AXUIElementCreateSystemWide().getValue(
    forKey: kAXFocusedApplicationAttribute
  )
  var res: pid_t = 0
  try AXUIElementGetPid(currentApp, &res).unwrap()
  return res
}

func getFrontmostAppBundleID() -> String? {
  let runningApp = NSWorkspace.shared.frontmostApplication
  return runningApp?.bundleIdentifier
}

func getCurrentAppBundleID() -> String? {
  do {
    let pid = try getCurrentAppPID()
    return getAppBundleID(forPID: pid)
  } catch {
    // HACK: I don't know why I am doing this, but this seems to work 90% of the time.
    log.debug(
      "\(#function): failed to get current app PID, falling back to frontmost app PID: \(error)"
    )
    // TODO: What happens when `getCurrentAppPID()` fails and we fall back to this one, but the frontmost app is NOT the current app?
    return getFrontmostAppBundleID()
  }
}
