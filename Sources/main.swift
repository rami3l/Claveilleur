import AppKit
import Carbon

// https://github.com/mzp/EmojiIM/issues/27#issue-1361876711
func getInputSource() -> String {
  let inputSource = TISCopyCurrentKeyboardInputSource().takeUnretainedValue()
  return unsafeBitCast(
    TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID),
    to: NSString.self
  ) as String
}

// https://github.com/daipeihust/im-select/blob/83046bb75333e58c9a7cbfbd055db6f360361781/macOS/im-select/im-select/main.m
func setInputSource(to id: String) {
  let filter = [kTISPropertyInputSourceID!: id] as NSDictionary
  let inputSources =
    TISCreateInputSourceList(filter, false).takeUnretainedValue()
    as NSArray as! [TISInputSource]
  let inputSource = inputSources[0]
  TISSelectInputSource(inputSource)
}

// print(getInputSource())
// setInputSource(to: "com.apple.keylayout.US")

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
