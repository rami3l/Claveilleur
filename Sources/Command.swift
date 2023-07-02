import ArgumentParser
import Cocoa

// TODO: Add CLI interface: launch (normal), --(un)?install-service, --(start|stop|restart)-service

@main
struct Command: ParsableCommand {
  func run() throws {
    // https://developer.apple.com/swift/blog/?id=7
    _ = currentInputSourceObserver
    _ = runningAppsObserver
    _ = appActivatedObserver

    log.info("== Welcome to Claveilleur ==")

    CFRunLoopRun()
  }
}
