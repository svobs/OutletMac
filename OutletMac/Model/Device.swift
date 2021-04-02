//
//  Device.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/31.
//  Copyright © 2021 Matt Svoboda. All rights reserved.
//

class Device {
  let uid: UID
  let long_device_id: String
  let treeType: TreeType
  let friendlyName: String

  init(device_uid: UID, long_device_id: String, treeType: TreeType, friendlyName: String) {
    self.uid = device_uid
    self.long_device_id = long_device_id
    self.treeType = treeType
    self.friendlyName = friendlyName
  }
}
