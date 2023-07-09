import Cocoa

// https://github.com/koekeishiya/yabai/blob/a8eb6b1a7da4e33954b716b424eb51ce47317865/src/misc/helpers.h#L328
func hasAXPrivilege() -> Bool {
  let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): kCFBooleanTrue] as CFDictionary
  return AXIsProcessTrustedWithOptions(options)
}
