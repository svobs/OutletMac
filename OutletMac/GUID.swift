//
//  File.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/9.
//

import Foundation

typealias GUID = Int32

class GUIDGenerator {
  private var nextVal: GUID = 0
  private let lock = NSLock()

  func next() -> GUID {
    lock.lock()
    defer {
      lock.unlock()
    }

    nextVal -= 1
    if SUPER_DEBUG {
      NSLog("DEBUG GUIDGenerator: returning next GUID: \(nextVal)")
    }
    return nextVal
  }
}

class GUIDMapper {
  private let guidGen = GUIDGenerator()
  private var map = [String: GUID]()
  private let lock = NSLock()

  private static func buildGDriveKey(_ singlePath: String, _ uid: UID) -> String {
    return "\(uid)-\(singlePath)"
  }

  func guidFor(_ treeType: TreeType, singlePath: String, uid: UID) -> GUID {
    switch (treeType) {
      case .LOCAL_DISK:
        return GUID(uid)
      case .GDRIVE:
        lock.lock()
        defer {
          lock.unlock()
        }
        let key = GUIDMapper.buildGDriveKey(singlePath, uid)
        var value = self.map[key]
        if value == nil {
          value = self.guidGen.next()
          self.map[key] = value
        }
        return value!
      case .NA:
        lock.lock()
        defer {
          lock.unlock()
        }
        // Loading message, etc.
        // TODO: clean this up. This is super kludgy
        let key = GUIDMapper.buildGDriveKey(singlePath, NULL_UID)
        var value = self.map[key]
        if value == nil {
          value = self.guidGen.next()
          self.map[key] = value
        }
        return value!
      default:
        fatalError("Invalid treeType: \(treeType)")
    }
  }
}
