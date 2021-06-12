//
//  IconStore.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/18.
//

import SwiftUI

/**
 PROTOCOL ImageContainer

 Intended as a flexible factory for a single particular Image and associated useful metadata
 */
protocol ImageContainer {
  func getImage() -> Image

  var isGrayscale: Bool { get }

  var width: CGFloat { get }
  var height: CGFloat { get }
}

fileprivate class LocalImage: ImageContainer {
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

fileprivate class SystemImage: ImageContainer {
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

    // FIXME: this doesn't actually do anything. How to return a view?
    let _ = img
      .font(self.font)
      .frame(width: self.width, height: self.height)

    return img
  }
}

/**
 CLASS NetworkImage

 An image which originated from the server via gRPC
 */
fileprivate class NetworkImage: ImageContainer {
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
    return Image(nsImage: self.nsImage)
  }
}

/**
 ImageContainerWrapper: needed because NSCache needs a protocol, not an object
 */
fileprivate class ImageContainerWrapper {
  let imageProvider: ImageContainer

  init(_ imgProvider: ImageContainer) {
    self.imageProvider = imgProvider
  }
}

/**
 CLASS IconStore

 The in-memory repository for all icons in the app. Configured at start. May use either MacOS system icons, or icons retrieved
 from the backend server.
 */
class IconStore: HasLifecycle {

  let backend: OutletBackend
  var treeIconSize: CGFloat = (CGFloat)(DEFAULT_ICON_SIZE)
  var toolbarIconSize: CGFloat = (CGFloat)(DEFAULT_ICON_SIZE)
  var useNativeToolbarIcons: Bool = true
  var useNativeTreeIcons: Bool = true

  private let toolbarIconCache = NSCache<NSNumber, ImageContainerWrapper>()
  private let treeIconCache = NSCache<NSString, NSImage>()

  init(_ backend: OutletBackend) {
    self.backend = backend
  }

  func start() throws {
    self.treeIconSize = (CGFloat)(try self.backend.getIntConfig(CFG_KEY_TREE_ICON_SIZE, defaultVal: DEFAULT_ICON_SIZE))
    self.toolbarIconSize = (CGFloat)(try self.backend.getIntConfig(CFG_KEY_TOOLBAR_ICON_SIZE, defaultVal: DEFAULT_ICON_SIZE))
    self.useNativeToolbarIcons = try self.backend.getBoolConfig(CFG_KEY_USE_NATIVE_TOOLBAR_ICONS, defaultVal: useNativeToolbarIcons)
    self.useNativeTreeIcons = try self.backend.getBoolConfig(CFG_KEY_USE_NATIVE_TREE_ICONS, defaultVal: useNativeTreeIcons)
    NSLog("DEBUG IconStore: treeIconSize=\(self.treeIconSize) toolbarIconSize=\(self.toolbarIconSize) useNativeToolbarIcons = \(self.useNativeToolbarIcons) useNativeTreeIcons = \(self.useNativeTreeIcons)")
  }

  func shutdown() throws {
    toolbarIconCache.removeAllObjects()
  }

  private func makeGenericCacheKey(_ iconId: IconID) -> String {
    "\(iconId)"
  }

  private func makeFileCacheKey(_ iconId: IconID, _ node: Node) -> String {
    let suffix = URL(fileURLWithPath: node.firstPath).pathExtension
    return "\(iconId):\(suffix)"
  }

  func getTreeIcon(_ node: Node, height: CGFloat) -> NSImage? {
    var icon: NSImage

    let iconId = node.icon
    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG Getting treeIcon for: \(iconId): \(node.nodeIdentifier)")
    }
    let key: String

    var badge: IconID? = nil

    if node.isDir {
      // If dir, determine appropriate badge, if any
      switch iconId {
      case .ICON_DIR_MK:
        badge = .BADGE_MKDIR
        break
      case .ICON_DIR_RM:
        badge = .BADGE_RM
        break
      case .ICON_DIR_MV_SRC:
        badge = .BADGE_MV_SRC
        break
      case .ICON_DIR_UP_SRC:
        badge = .BADGE_UP_SRC
        break
      case .ICON_DIR_CP_SRC:
        badge = .BADGE_CP_SRC
        break
      case .ICON_DIR_MV_DST:
        badge = .BADGE_MV_DST
        break
      case .ICON_DIR_UP_DST:
        badge = .BADGE_UP_DST
        break
      case .ICON_DIR_CP_DST:
        badge = .BADGE_CP_DST
        break
      case .ICON_DIR_TRASHED:
        badge = .BADGE_TRASHED
        break
      case .ICON_GENERIC_DIR:
        // No badge
        break
      default:
        break
      }

      key = makeGenericCacheKey(iconId)

      // Used cached icon if available
      if let cachedIcon = treeIconCache.object(forKey: key as NSString) {
        if SUPER_DEBUG_ENABLED {
          NSLog("DEBUG Returning cached icon for (dir) key '\(key)'")
        }
        return cachedIcon
      }

      icon = NSWorkspace.shared.icon(for: .folder)

      icon = self.addBadgeOverlay(src: icon, badge: badge)

    } else {
      let isFile: Bool
      // If file, determine appropriate badge, if any
      switch iconId {
      case .ICON_FILE_RM:
        badge = .BADGE_RM
        isFile = true
        break
      case .ICON_FILE_MV_SRC:
        badge = .BADGE_MV_SRC
        isFile = true
        break
      case .ICON_FILE_UP_SRC:
        badge = .BADGE_UP_SRC
        isFile = true
        break
      case .ICON_FILE_CP_SRC:
        badge = .BADGE_CP_SRC
        isFile = true
        break
      case .ICON_FILE_MV_DST:
        badge = .BADGE_MV_DST
        isFile = true
        break
      case .ICON_FILE_UP_DST:
        badge = .BADGE_UP_DST
        isFile = true
        break
      case .ICON_FILE_CP_DST:
        badge = .BADGE_CP_DST
        isFile = true
        break
      case .ICON_FILE_TRASHED:
        badge = .BADGE_TRASHED
        isFile = true
        break
      case .ICON_GENERIC_FILE:
        // No badge
        isFile = true
        break

      default:
        isFile = false
        break
      }

      if isFile {
        key = makeFileCacheKey(iconId, node)
      } else {
        key = makeGenericCacheKey(iconId)
      }

      // Now that we have derived the key for the file type, use cached value if available
      if let cachedIcon = treeIconCache.object(forKey: key as NSString) {
        if SUPER_DEBUG_ENABLED {
          NSLog("DEBUG Returning cached icon for (file) key '\(key)'")
        }
        return cachedIcon
      }

      // Get icon for suffix
      let suffix = URL(fileURLWithPath: node.firstPath).pathExtension
      if suffix == "" {
        icon = NSWorkspace.shared.icon(for: .data)
      } else {
        icon = NSWorkspace.shared.icon(forFileType: suffix)
      }

      icon = self.addBadgeOverlay(src: icon, badge: badge)
    }

    // Thanks to "Sweeper" at https://stackoverflow.com/questions/62525921/how-to-get-a-high-resolution-app-icon-for-any-application-on-a-mac
    if let imageRep = icon.bestRepresentation(for: NSRect(x: 0, y: 0, width: height, height: height), context: nil, hints: nil) {
      icon = NSImage(size: imageRep.size)
      icon.addRepresentation(imageRep)
    }

    icon.size = NSSize(width: height, height: height)

    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG Storing icon=\(iconId) with badge=\(badge ?? IconID.NONE) for key: '\(key)'")
    }
    treeIconCache.setObject(icon, forKey: key as NSString)
    return icon
  }

  private func addBadgeOverlay(src icon: NSImage, badge: IconID?) -> NSImage {
    guard let badge = badge else {
      return icon
    }

    let newImage = NSImage(size: icon.size)
    newImage.lockFocus()

    var newImageRect: CGRect = .zero
    newImageRect.size = newImage.size

    let overlay = try! self.backend.getIcon(badge)!

    icon.draw(in: newImageRect)
    let overlayOffset = NSPoint(x: 0, y: 0) // lower-left corner
    overlay.draw(at: overlayOffset, from: newImageRect, operation: .sourceOver, fraction: 1.0)

    newImage.unlockFocus()

    return newImage
  }

  func getToolbarIcon(for iconID: IconID) -> ImageContainer {
    let key = NSNumber(integerLiteral: Int(iconID.rawValue))

    if let cachedIcon = toolbarIconCache.object(forKey: key) {
      return cachedIcon.imageProvider
    } else {
        // create it from scratch then store in the toolbarIconCache
      let imageContainer = self.makeNewImageContainer(for: iconID)
      toolbarIconCache.setObject(ImageContainerWrapper(imageContainer), forKey: key)
      return imageContainer
    }
  }

  private func makeNewImageContainer(for iconID: IconID) -> ImageContainer {
    let iconSize: CGFloat
    if iconID.isToolbarIcon() {
      iconSize = toolbarIconSize

      if self.useNativeToolbarIcons {
        return SystemImage(width: iconSize, height: iconSize, systemImageName: iconID.systemImageName())
      }
    } else {
      iconSize = treeIconSize
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

  private func makeErrorImage(iconSize: CGFloat) -> ImageContainer {
    return SystemImage(width: iconSize, height: iconSize, systemImageName: ICON_DEFAULT_ERROR_SYSTEM_IMAGE_NAME)
  }
}
