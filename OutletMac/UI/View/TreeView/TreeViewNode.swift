import Foundation

@objc public class TreeViewNode: NSObject {

  @objc let value: String
  @objc var children: [TreeViewNode]

  @objc var childrenCount: String? {
    let count = children.count
    guard count > 0 else { return nil }
    return "\(count) node\(count > 1 ? "s" : "")"
  }

  @objc var count: Int {
    children.count
  }

  @objc var isLeaf: Bool {
    children.isEmpty
  }

  init(value: String, children: [TreeViewNode] = []) {
    self.value = value
    self.children = children
  }
}
