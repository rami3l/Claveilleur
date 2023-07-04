import Cocoa

// Special thanks to
// <https://stackoverflow.com/questions/36264038/cocoa-programmatically-detect-frontmost-floating-windows>
// for providing the basic methodological guidance for supporting Spotlight and co.

let currentInputSourceObserver = NotificationCenter
  .default
  .publisher(for: NSTextInputContext.keyboardSelectionDidChangeNotification)
  .map { _ in getInputSource() }
  .removeDuplicates()
  .sink { inputSource in
    guard let currentApp = getCurrentAppBundleID() else {
      return
    }
    saveInputSource(inputSource, forApp: currentApp)
  }

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
    log.debug("appActivatedObserver: detected activation of app: \(currentApp)")

    guard
      let oldInputSource = userDefaults.string(forKey: currentApp),
      setInputSource(to: oldInputSource)
    else {
      let newInputSource = getInputSource()
      saveInputSource(newInputSource, forApp: currentApp)
      return
    }
  }

let runningAppsObserver = RunningAppsObserver()
