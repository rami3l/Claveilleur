import Carbon

func saveInputSource(_ id: String, forApp appID: String) {
  userDefaults.set(id, forKey: appID)
}

// https://github.com/mzp/EmojiIM/issues/27#issue-1361876711
func getInputSource() -> String {
  let inputSource = TISCopyCurrentKeyboardInputSource().takeUnretainedValue()
  return unsafeBitCast(
    TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID),
    to: NSString.self
  ) as String
}

// https://github.com/daipeihust/im-select/blob/83046bb75333e58c9a7cbfbd055db6f360361781/macOS/im-select/im-select/main.m
func setInputSource(to id: String) -> Bool {
  if getInputSource() == id {
    return true
  }
  print("Restoring input source to: \(id)")
  let filter = [kTISPropertyInputSourceID!: id] as NSDictionary
  let inputSources =
    TISCreateInputSourceList(filter, false).takeUnretainedValue()
    as NSArray as! [TISInputSource]
  guard !inputSources.isEmpty else {
    return false
  }
  let inputSource = inputSources[0]
  TISSelectInputSource(inputSource)
  return true
}
