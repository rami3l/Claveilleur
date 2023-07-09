import ArgumentParser
import Cocoa

@main
struct Command: ParsableCommand {
  static var version = "0.1.0"

  static var configuration = CommandConfiguration(
    abstract: "An input source switching daemon for macOS.",
    version: version
  )

  /// The behavior flag.
  enum Operation: String, EnumerableFlag {
    case run
    case installService
    case uninstallService
    case reinstallService
    case startService
    case stopService
  }

  /// The common options across subcommands.
  struct Options: ParsableArguments, Decodable {
    @Flag(name: .shortAndLong, help: "Enable verbose output.")
    var verbose = false

    @Flag(exclusivity: .exclusive, help: "The operation to be performed.")
    var operation: Operation = .run
  }

  @OptionGroup var options: Options

  func run() throws {
    if self.options.verbose {
      logLevel = .debug
    }

    switch self.options.operation {
    case .installService: try Service.install()
    case .uninstallService: try Service.uninstall()
    case .reinstallService: try Service.reinstall()
    case .startService: try Service.start()
    case .stopService: try Service.stop()
    case .run:
      // https://developer.apple.com/swift/blog/?id=7
      _ = currentInputSourceObserver
      _ = runningAppsObserver
      _ = appActivatedObserver

      guard hasAXPrivilege() else {
        log.error("Accessibility privilege not detected, bailing out...")
        return
      }

      log.info("== Welcome to Claveilleur ==")
      CFRunLoopRun()
    }
  }
}
