import Cocoa

extension AXError {
  func unwrap() throws {
    guard case .success = self else {
      throw AXUIError.axError("AXUI function failed with `\(self)`")
    }
  }
}
