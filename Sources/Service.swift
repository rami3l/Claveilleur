import Cocoa
import LaunchAgent

// https://github.com/koekeishiya/skhd/blob/f88e7ad403ebbee1b8bac988d8b162d595f595c4/src/service.h

let username = NSUserName()
let home = FileManager.default.homeDirectoryForCurrentUser

func exePath() -> String? {
  var pathBuf = [Int8](repeating: 0, count: 4096)
  var pathBufSize = UInt32(pathBuf.count)
  guard _NSGetExecutablePath(&pathBuf, &pathBufSize) == 0 else {
    return nil
  }
  return String(cString: &pathBuf, encoding: String.Encoding.ascii)
}

enum Service {
  static let launchAgent: LaunchAgent = {
    let res = LaunchAgent(
      label: packageName,
      program: exePath()!
    )
    res.runAtLoad = true
    res.keepAlive = true
    res.standardOutPath = logFilePrefix + ".out.log"
    res.standardErrorPath = logFilePrefix + ".err.log"
    res.processType = .interactive
    res.nice = -20
    return res
  }()

  static let launchAgentPlistName = "\(packageName).plist"

  static let launchAgentPlistPath = {
    var res = home
    ["Library", "LaunchAgents", launchAgentPlistName].forEach {
      res.appendPathComponent($0)
    }
    return res
  }()

  static let launchAgentPlistPathStr =
    String(launchAgentPlistPath.absoluteString.dropFirst("file://".count))

  static let logFilePrefix = NSString.path(
    withComponents: ["/", "tmp", "\(packageName)_\(username)"]
  )

  static func isInstalled() -> Bool {
    return FileManager.default.fileExists(atPath: launchAgentPlistPathStr)
  }

  static func install() throws {
    if isInstalled() {
      print(
        "Existing launch agent detected at `\(launchAgentPlistPathStr)`, skipping installation"
      )
      return
    }
    try LaunchControl.shared.write(launchAgent, to: launchAgentPlistPath)
    print("Launch agent has been installed to `\(launchAgentPlistPathStr)`")
  }

  static func uninstall() throws {
    guard isInstalled() else {
      print(
        "Launch agent not found at `\(launchAgentPlistPathStr)`, skipping uninstallation"
      )
      return
    }
    try FileManager.default.removeItem(at: launchAgentPlistPath)
    print("Removed existing launch agent at `\(launchAgentPlistPathStr)`")
  }

  static func reinstall() throws {
    try uninstall()
    try install()
  }

  static func start() throws {
    if !isInstalled() {
      try install()
    }
    print("Bootstrapping service...")
    try launchAgent.bootstrap()
    if case .running(_) = launchAgent.status() {
    } else {
      print("Starting service...")
      launchAgent.start()
    }
    print("Service started successfully")
  }

  static func stop() throws {
    do {
      launchAgent.stop()
      try launchAgent.bootout()
    } catch {
      print("Failed to bootout: \(error)")
      return
    }
  }
}
