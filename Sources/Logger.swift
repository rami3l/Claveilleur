import Logging

private func initLogger() -> Logger {
  LoggingSystem.bootstrap(StreamLogHandler.standardError)
  return Logger(label: suiteName)
}

let log = initLogger()
