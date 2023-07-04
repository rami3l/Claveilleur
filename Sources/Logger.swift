import Logging

var logLevel: Logger.Level = .info

let log: Logger = {
  LoggingSystem.bootstrap {
    var handler = StreamLogHandler.standardError(label: $0)
    handler.logLevel = logLevel
    return handler
  }
  return Logger(label: packageName)
}()
