import Cocoa

/// Converts a running application's PID to its Bundle ID.
func getAppBundleID(forPID pid: pid_t) -> String? {
  let currentApp = NSWorkspace.shared.runningApplications.first {
    $0.processIdentifier == pid
  }
  return currentApp?.bundleIdentifier
}

/// Returns the PID of the frontmost application from a notification sent by `NotificationCenter`.
///
/// # Note
/// This function could always return `nil` for certain notification types.
func getAppBundleID(forNotification notif: NotificationCenter.Publisher.Output) -> String? {
  let runningApp =
    notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
  return runningApp?.bundleIdentifier
}

/// Returns the PID of the frontmost application from the Accessibility APIs.
func getCurrentAppPID() throws -> pid_t {
  let currentApp: AXUIElement = try AXUIElementCreateSystemWide().getValue(
    forKey: kAXFocusedApplicationAttribute
  )
  var res: pid_t = 0
  try AXUIElementGetPid(currentApp, &res).unwrap()
  return res
}

/// Returns the Bundle ID of the frontmost application as indicated by `NSWorkspace`.
///
/// # Note
/// Floating panels (such as the Spotlight search box triggered by cmd-space) are ignored by this API.
func getFrontmostAppBundleID() -> String? {
  let runningApp = NSWorkspace.shared.frontmostApplication
  return runningApp?.bundleIdentifier
}

/// Returns the Bundle ID of the currently focused application.
///
/// # Note
/// This function always tries to get the current application from the Accessibility APIs first,
/// and uses the `NSWorkspace` result as a fallback.
/// Despite these efforts, the result might still be inaccurate.
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
