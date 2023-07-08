import Cocoa

let localNotificationCenter = NotificationCenter()

// https://stackoverflow.com/a/38928864
let focusedWindowChangedNotification =
  Notification.Name("claveilleur-focused-window-changed")
let appHiddenNotification =
  Notification.Name("claveilleur-app-hidden")
