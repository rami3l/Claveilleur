import Logging

let log: Logger = {
  LoggingSystem.bootstrap(StreamLogHandler.standardError)
  return Logger(label: packageName)
}()
