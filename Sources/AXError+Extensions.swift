import Cocoa

extension AXError {
  // TODO: Get proper case name instead of using direct string interpolation:
  // https://github.com/Azoy/Echo/issues/9#issuecomment-624903603

  /// Throws a conventional runtime error if this `AXError` is not `.success`.
  func unwrap() throws {
    guard case .success = self else {
      throw AXUIError.axError("AXUI function failed with `\(self)`")
    }
  }
}
