import Cocoa

extension AXUIElement {
  func getValue<T>(forKey key: String) throws -> T {
    var res: AnyObject?
    try AXUIElementCopyAttributeValue(self, key as CFString, &res).unwrap()
    guard let res = res as? T else {
      throw AXUIError.typeCastError("downcast failed from `\(type(of: res))` to `\(T.self)`")
    }
    return res
  }
}
