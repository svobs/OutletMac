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
  func getNSImage() -> NSImage

  var isGrayscale: Bool { get }

  var width: CGFloat { get }
  var height: CGFloat { get }
}

fileprivate func makeErrorImage(iconSize: CGFloat) -> ImageContainer {
  return SystemImage(width: iconSize, height: iconSize, systemImageName: ICON_DEFAULT_ERROR_SYSTEM_IMAGE_NAME)
}

fileprivate func makeErrorNSImage(width: CGFloat, height: CGFloat) -> NSImage {
  let nsImage = NSImage(systemSymbolName: ICON_DEFAULT_ERROR_SYSTEM_IMAGE_NAME, accessibilityDescription: nil)!
  nsImage.size = NSSize(width: width, height: height)
  return nsImage
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

  func getNSImage() -> NSImage {
    NSLog("ERROR getNSImage() should not be called for LocalImage (name='\(imageName)'); returning error image instead")
    return makeErrorNSImage(width: self.width, height: self.height)
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

  func getNSImage() -> NSImage {
    if let nsImage = NSImage(systemSymbolName: self.systemImageName, accessibilityDescription: nil) {
      nsImage.size = NSSize(width: height, height: height)
      return nsImage
    } else {
      return makeErrorNSImage(width: self.width, height: self.height)
    }
  }

  func getImage() -> Image {
    return Image(systemName: self.systemImageName)
      .renderingMode(.template)
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

  func getNSImage() -> NSImage {
    return nsImage
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
  var nodeIconSize: CGFloat = (CGFloat)(DEFAULT_ICON_SIZE)
  var toolbarIconSize: CGFloat = (CGFloat)(DEFAULT_ICON_SIZE)
  var useNativeToolbarIcons: Bool = true
  var useNativeNodeIcons: Bool = true

  private let dq = DispatchQueue(label: "IconStore-SerialQueue") // custom dispatch queues are serial by default

  // These are thread-safe classes. However, we need the DQ above to guarantee atomicity
  private let toolbarIconCache = NSCache<NSNumber, ImageContainerWrapper>()
  private let nodeIconCache = NSCache<NSString, NSImage>()

  init(_ backend: OutletBackend) {
    self.backend = backend
  }

  func start() throws {
    NSLog("DEBUG IconStore starting: getting config values from gRPC")
    self.nodeIconSize = (CGFloat)(try self.backend.getIntConfig(CFG_KEY_TREE_ICON_SIZE, defaultVal: DEFAULT_ICON_SIZE))
    self.toolbarIconSize = (CGFloat)(try self.backend.getIntConfig(CFG_KEY_TOOLBAR_ICON_SIZE, defaultVal: DEFAULT_ICON_SIZE))
    self.useNativeToolbarIcons = try self.backend.getBoolConfig(CFG_KEY_USE_NATIVE_TOOLBAR_ICONS, defaultVal: useNativeToolbarIcons)
    self.useNativeNodeIcons = try self.backend.getBoolConfig(CFG_KEY_USE_NATIVE_TREE_ICONS, defaultVal: useNativeNodeIcons)
    NSLog("DEBUG IconStore: nodeIconSize=\(self.nodeIconSize) toolbarIconSize=\(self.toolbarIconSize) useNativeToolbarIcons = \(self.useNativeToolbarIcons) useNativeNodeIcons = \(self.useNativeNodeIcons)")
  }

  func shutdown() throws {
    toolbarIconCache.removeAllObjects()
    nodeIconCache.removeAllObjects()
  }

  func getNodeIcon(_ node: Node, height: CGFloat) -> NSImage? {
    let iconId = node.icon
    if TRACE_ENABLED {
      NSLog("DEBUG Getting nodeIcon for: \(iconId): \(node.nodeIdentifier)")
    }

    if node.isEphemeral {
      // FIXME: should not be getting toolbar icon here
      let toolIcon = self.getToolbarIcon(for: iconId)
      return toolIcon.getNSImage()
    } else {
      var icon: NSImage? = nil
      self.dq.sync {
        if node.isDir {
          icon = self.getIconForDirNode(node, height)
        } else {
          icon = self.getIconForFileNode(node, height)
        }
      }
      return icon
    }
  }

  private func getBestRepresentation(_ icon: NSImage, _ height: CGFloat) -> NSImage {
    var bestRep: NSImage = icon
    // Thanks to "Sweeper" at https://stackoverflow.com/questions/62525921/how-to-get-a-high-resolution-app-icon-for-any-application-on-a-mac
    if let imageRep = icon.bestRepresentation(for: NSRect(x: 0, y: 0, width: height, height: height), context: nil, hints: nil) {
      bestRep = NSImage(size: imageRep.size)
      bestRep.addRepresentation(imageRep)
    }

    bestRep.size = NSSize(width: height, height: height)
    return bestRep
  }

  private func getIconForDirNode(_ node: Node, _ height: CGFloat) -> NSImage {
    let iconID = node.icon
    let key: String = makeSimpleIconCacheKey(iconID)

    if let cachedIcon = nodeIconCache.object(forKey: key as NSString) {
      // Used cached icon if available
      if TRACE_ENABLED {
        NSLog("DEBUG Returning cached icon for (dir) key '\(key)'")
      }
      return cachedIcon
    }

    // else build new icon

    var badge: IconID? = nil
    // If dir, determine appropriate badge, if any
    switch iconID {
    case .ICON_DIR_MK:
      badge = .BADGE_MKDIR
    case .ICON_DIR_RM:
      badge = .BADGE_RM
    case .ICON_DIR_MV_SRC:
      badge = .BADGE_MV_SRC
    case .ICON_DIR_UP_SRC:
      badge = .BADGE_UP_SRC
    case .ICON_DIR_CP_SRC:
      badge = .BADGE_CP_SRC
    case .ICON_DIR_MV_DST:
      badge = .BADGE_MV_DST
    case .ICON_DIR_UP_DST:
      badge = .BADGE_UP_DST
    case .ICON_DIR_CP_DST:
      badge = .BADGE_CP_DST
    case .ICON_DIR_TRASHED:
      badge = .BADGE_TRASHED
    case .ICON_DIR_PENDING_DOWNSTREAM_OP:
      badge = .BADGE_PENDING_DOWNSTREAM_OP
    case .ICON_DIR_ERROR:
      badge = .BADGE_ERROR
    case .ICON_GENERIC_DIR:
      // No badge
      break
    default:
      // create it from scratch then store in the toolbarIconCache
      assert(!iconID.isToolbarIcon(), "Expected to not be a toolbar icon: \(iconID)")
      let imageContainer = self.makeNewImageContainer(for: iconID)
      let nsImage = imageContainer.getNSImage()
      nodeIconCache.setObject(nsImage, forKey: key as NSString)
      return nsImage
    }

    let baseIcon = NSWorkspace.shared.icon(for: .folder)

    return buildAndCacheMacIcon(iconID, baseIcon, height, badge, key)
  }

  private func getIconForFileNode(_ node: Node, _ height: CGFloat) -> NSImage {
    let iconID = node.icon
    let key: String = makeFileIconCacheKey(iconID, node)

    // Now that we have derived the key for the file type, use cached value if available
    if let cachedIcon = nodeIconCache.object(forKey: key as NSString) {
      if TRACE_ENABLED {
        NSLog("DEBUG Returning cached icon for (file) key '\(key)'")
      }
      return cachedIcon
    } else {
      // build new icon

      var badge: IconID? = nil
      // If file, determine appropriate badge, if any
      switch iconID {
      case .ICON_FILE_RM:
        badge = .BADGE_RM
      case .ICON_FILE_MV_SRC:
        badge = .BADGE_MV_SRC
      case .ICON_FILE_UP_SRC:
        badge = .BADGE_UP_SRC
      case .ICON_FILE_CP_SRC:
        badge = .BADGE_CP_SRC
      case .ICON_FILE_MV_DST:
        badge = .BADGE_MV_DST
      case .ICON_FILE_UP_DST:
        badge = .BADGE_UP_DST
      case .ICON_FILE_CP_DST:
        badge = .BADGE_CP_DST
      case .ICON_FILE_TRASHED:
        badge = .BADGE_TRASHED
      case .ICON_FILE_ERROR:
        badge = .BADGE_ERROR
      case .ICON_GENERIC_FILE:
        // No badge
        break
      default:
        // not a file?
        assert(!iconID.isToolbarIcon(), "Expected to not be a toolbar icon: \(iconID)")
        let imageContainer = self.makeNewImageContainer(for: iconID)
        let nsImage = imageContainer.getNSImage()
        nodeIconCache.setObject(nsImage, forKey: key as NSString)
        return nsImage
      }

      var baseIcon: NSImage
      // Get icon for suffix
      let suffix = URL(fileURLWithPath: node.firstPath).pathExtension
      if suffix == "" {
        baseIcon = NSWorkspace.shared.icon(for: .data)
      } else {
        baseIcon = NSWorkspace.shared.icon(forFileType: suffix)
      }

      return buildAndCacheMacIcon(iconID, baseIcon, height, badge, key)
    }
  }

  private func buildAndCacheMacIcon(_ iconID: IconID, _ baseIcon: NSImage, _ height: CGFloat, _ badge: IconID?, _ key: String)-> NSImage {
    let baseIcon = self.getBestRepresentation(baseIcon, height)
    let icon = self.addBadgeOverlay(src: baseIcon, badge: badge)
    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG Storing icon=\(iconID) with badge=\(badge ?? IconID.NONE) for key: '\(key)'")
    }
    nodeIconCache.setObject(icon, forKey: key as NSString)
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
    NSLog("DEBUG getToolbarIcon(): Current queue: '\(DispatchQueue.currentQueueLabel ?? "nil")'")

    let key = self.makeToolbarCacheKey(iconID)

    var imageContainer: ImageContainer! = nil
    self.dq.sync {
      if let cachedIcon = toolbarIconCache.object(forKey: key) {
        imageContainer = cachedIcon.imageProvider
      } else {
        // create it from scratch then store in the toolbarIconCache
        imageContainer = self.makeNewImageContainer(for: iconID)
        toolbarIconCache.setObject(ImageContainerWrapper(imageContainer), forKey: key)
      }
    }
    if SUPER_DEBUG_ENABLED {
      NSLog("DEBUG getToolbarIcon(): Returning toolbar icon for key '\(key)'")
    }
    return imageContainer
  }
  
  private func makeToolbarCacheKey(_ iconID: IconID) -> NSNumber {
    return NSNumber(integerLiteral: Int(iconID.rawValue))
  }

  private func makeSimpleIconCacheKey(_ iconID: IconID) -> String {
    "\(iconID)"
  }

  private func makeFileIconCacheKey(_ iconID: IconID, _ node: Node) -> String {
    let suffix = URL(fileURLWithPath: node.firstPath).pathExtension
    return "\(iconID):\(suffix)"
  }

  private func makeNewImageContainer(for iconID: IconID) -> ImageContainer {
    let iconSize: CGFloat
    if iconID.isToolbarIcon() {
      // Toolbar icon
      iconSize = toolbarIconSize

      if self.useNativeToolbarIcons {
        return SystemImage(width: iconSize, height: iconSize, systemImageName: iconID.systemImageName())
      }
    } else {
      // Node icon
      iconSize = nodeIconSize
    }

    do {
      if let nsImage = try self.backend.getIcon(iconID) {
        return NetworkImage(width: iconSize, height: iconSize, nsImage: nsImage)
      } else {
        NSLog("ERROR Server returned nil for image ID \(iconID)")
        return makeErrorImage(iconSize: iconSize)
      }
    } catch {
      NSLog("ERROR Failed to load image ID \(iconID) from server: \(error)")
      return makeErrorImage(iconSize: iconSize)
    }
  }

}
