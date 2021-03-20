//
//  IconStore.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/18.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import SwiftUI

/**
 PROTOCOL ImageProvider

 Intended as a flexible factory for a single particular Image and associated useful metadata
 */
protocol ImageProvider {
  func getImage() -> Image

  var isGrayscale: Bool { get }

  var width: CGFloat { get }
  var height: CGFloat { get }
}

fileprivate class LocalImage: ImageProvider {
  let width: CGFloat
  let height: CGFloat
  let imageName: String
  let font: Font

  var isGrayscale: Bool {
    get {
      false
    }
  }

  init(width: CGFloat, height: CGFloat, imageName: String, font: Font = DEFAULT_FONT) {
    self.width = width
    self.height = height
    self.imageName = imageName
    self.font = font
  }

  func getImage() -> Image {
    let img = Image(self.imageName)
      .renderingMode(.template)

    let _ = img
      .font(self.font)
      .frame(width: self.width, height: self.height)

    return img
  }
}

fileprivate class SystemImage: ImageProvider {
  let width: CGFloat
  let height: CGFloat
  let systemImageName: String
  let font: Font

  var isGrayscale: Bool {
    get {
      true
    }
  }

  init(width: CGFloat, height: CGFloat, systemImageName: String, font: Font = DEFAULT_FONT) {
    self.width = width
    self.height = height
    self.systemImageName = systemImageName
    self.font = font
  }

  func getImage() -> Image {
    let img = Image(systemName: self.systemImageName)
      .renderingMode(.template)

    let _ = img
      .font(self.font)
      .frame(width: self.width, height: self.height)

    return img
  }
}

fileprivate class NetworkImage: ImageProvider {
  let width: CGFloat
  let height: CGFloat
  let nsImage: NSImage

  var isGrayscale: Bool {
    get {
      false
    }
  }

  init(width: CGFloat, height: CGFloat, nsImage: NSImage) {
    self.width = width
    self.height = height
    self.nsImage = nsImage
  }

  func getImage() -> Image {
    let img = Image(nsImage: self.nsImage)
    let _ = img
      .frame(width: self.width, height: self.height)
    return img
  }
}

fileprivate class ImageProviderWrapper {
  let imageProvider: ImageProvider

  init(_ imgProvider: ImageProvider) {
    self.imageProvider = imgProvider
  }
}

/**
 CLASS IconStore

 The in-memory repository for all icons in the app. Configured at start. May use either MacOS system icons, or icons retreived
 from the backend server.
 */
class IconStore: HasLifecycle {

  let backend: OutletBackend
  var treeIconSize: CGFloat = (CGFloat)(DEFAULT_ICON_SIZE)
  var toolbarIconSize: CGFloat = (CGFloat)(DEFAULT_ICON_SIZE)
  var useSystemToolbarIcons: Bool = true

  private let cache = NSCache<NSNumber, ImageProviderWrapper>()

  init(_ backend: OutletBackend) {
    self.backend = backend
  }

  func start() throws {
    self.treeIconSize = (CGFloat)(try self.backend.getIntConfig(CFG_KEY_TREE_ICON_SIZE, defaultVal: DEFAULT_ICON_SIZE))
    self.toolbarIconSize = (CGFloat)(try self.backend.getIntConfig(CFG_KEY_TOOLBAR_ICON_SIZE, defaultVal: DEFAULT_ICON_SIZE))
    self.useSystemToolbarIcons = try self.backend.getBoolConfig(CFG_KEY_USE_NATIVE_TOOLBAR_ICONS, defaultVal: useSystemToolbarIcons)
    NSLog("DEBUG IconStore: treeIconSize=\(self.treeIconSize) toolbarIconSize=\(self.toolbarIconSize) useSystemToolbarIcons = \(self.useSystemToolbarIcons)")
  }

  func shutdown() throws {
    cache.removeAllObjects()
  }

  func getIcon(for iconID: IconID) -> ImageProvider {
    let key = NSNumber(integerLiteral: Int(iconID.rawValue))

    if let cachedIcon = cache.object(forKey: key) {
      return cachedIcon.imageProvider
    } else {
        // create it from scratch then store in the cache
      let imageProvider = self.getNewImageProvider(for: iconID)
      cache.setObject(ImageProviderWrapper(imageProvider), forKey: key)
      return imageProvider
    }
  }

  private func getNewImageProvider(for iconID: IconID) -> ImageProvider {
    let iconSize: CGFloat
    if iconID.isToolbarIcon() {
      iconSize = toolbarIconSize
    } else {
      iconSize = treeIconSize
    }

    if self.useSystemToolbarIcons {
      return SystemImage(width: iconSize, height: iconSize, systemImageName: iconID.systemImageName())
    }

    do {
      if let nsImage = try self.backend.getIcon(iconID) {
        return NetworkImage(width: iconSize, height: iconSize, nsImage: nsImage)
      } else {
        NSLog("ERROR Server returned nil for image ID \(iconID)")
        return self.makeErrorImage(iconSize: iconSize)
      }
    } catch {
      NSLog("ERROR Failed to load image ID \(iconID) from server: \(error)")
      return self.makeErrorImage(iconSize: iconSize)
    }
  }

  private func makeErrorImage(iconSize: CGFloat) -> ImageProvider {
    return SystemImage(width: iconSize, height: iconSize, systemImageName: ICON_DEFAULT_ERROR_SYSTEM_IMAGE_NAME)
  }
}
