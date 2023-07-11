import Carbon
import Cocoa

// Special thanks to
// <https://stackoverflow.com/questions/36264038/cocoa-programmatically-detect-frontmost-floating-windows>
// for providing the basic methodological guidance for supporting Spotlight and co.

// https://stackoverflow.com/a/26697027
let currentInputSourceObserver = DistributedNotificationCenter
  .default
  .publisher(for: kTISNotifySelectedKeyboardInputSourceChanged as Notification.Name)
  .map { _ in (getCurrentAppBundleID(), getInputSource()) }
  .removeDuplicates { $0 == $1 }
  .sink { currentApp, inputSource in
    guard let currentApp = currentApp else {
      log.warning("\(#function): failed to get current app bundle ID for notification")
      return
    }
    log.info(
      "currentInputSourceObserver: updating input source for `\(currentApp)` to: \(inputSource)"
    )
    saveInputSource(inputSource, forApp: currentApp)
  }

let focusedWindowChangedPublisher =
  localNotificationCenter
  .publisher(for: Claveilleur.focusedWindowChangedNotification)
  .compactMap { getAppBundleID(forPID: $0.object as! pid_t) }

let didActivateAppPublisher = NSWorkspace
  .shared
  .notificationCenter
  .publisher(for: NSWorkspace.didActivateApplicationNotification)
  .compactMap(getAppBundleID(forNotification:))

let appHiddenPublisher =
  localNotificationCenter
  .publisher(for: Claveilleur.appHiddenNotification)
  .compactMap { _ in getCurrentAppBundleID() }

let appActivatedObserver =
  focusedWindowChangedPublisher
  .merge(with: didActivateAppPublisher, appHiddenPublisher)
  .removeDuplicates()
  .sink { currentApp in
    log.debug("appActivatedObserver: detected activation of app: \(currentApp)")

    guard
      let oldInputSource = loadInputSource(forApp: currentApp),
      setInputSource(to: oldInputSource)
    else {
      let newInputSource = getInputSource()
      log.info(
        "appActivatedObserver: registering input source for `\(currentApp)` as: \(newInputSource)"
      )
      saveInputSource(newInputSource, forApp: currentApp)
      return
    }
  }

let runningAppsObserver = RunningAppsObserver()
