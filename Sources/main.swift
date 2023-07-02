import AppKit
import Combine

// TODO: Use Apple unified logging to replace `print`s: https://github.com/chrisaljoudi/swift-log-oslog

// TODO: Add CLI interface: launch (normal), --(un)?install-service, --(start|stop|restart)-service

// Special thanks to <https://stackoverflow.com/questions/36264038/cocoa-programmatically-detect-frontmost-floating-windows>
// for providing the necessary directions of implementing Spotlight support.

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

let runningAppsObserver = RunningAppsObserver()

CFRunLoopRun()
