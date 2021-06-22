//
//  CellFactory.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/5/6.
//  Copyright © 2021 Matt Svoboda. All rights reserved.
//

import Foundation
import AppKit


/**
 Creates or updates cells for the TreeView.
 */
class CellFactory {
  /**
   Thanks to "jnpdx" from here for this:
   https://stackoverflow.com/questions/66165528/how-to-change-nstextfield-font-size-when-used-in-swiftui
   */
  private class CustomFontNSTextField : NSTextField {
    func customSetFont(_ font: NSFont?) {
      super.font = font
    }

    /**
     There seems to be a bug in Apple's code in Big Sur which causes font to be continuously set to system font, size 18.
     Override this to prevent this from happening.
     */
    override var font: NSFont? {
      get {
        return super.font
      }
      set {}
    }
  }

  private class NameCellView : NSTableCellView {
    var checkbox: CellCheckboxButton? = nil

    /** Returns a list of the components, in order */
    func getComponentList() -> [NSControl] {
      var list: [NSControl] = []

      if let imageView = self.imageView {
        list.append(imageView)
      }

      if let checkbox = self.checkbox {
        list.append(checkbox)
      }

      if let textField = self.textField {
        list.append(textField)
      }

      return list
    }
  }

  static func upsertCellToOutlineView(_ tvc: TreeViewController, _ identifier: NSUserInterfaceItemIdentifier, _ guid: GUID) -> NSView? {

    guard let sn = tvc.displayStore.getSN(guid) else {
      NSLog("ERROR [\(tvc.treeID)] viewForTableColumn(): node not found with GUID: \(guid)")
      return nil
    }

    let node = sn.node
    switch identifier.rawValue {
      case "name":
        var cell = tvc.outlineView.makeView(withIdentifier: identifier, owner: tvc.outlineView.delegate) as? NameCellView
        if cell == nil {
          cell = makeNameCell(for: sn, withIdentifier: identifier, tvc)
        }
        // update everything:
        cell!.checkbox?.updateState(sn)  // checkbox is optional
        cell!.imageView!.image = self.makeIcon(sn, cell!, TREE_VIEW_CELL_HEIGHT, tvc)
        cell!.textField!.stringValue = node.name
        cell!.needsLayout = true

        return cell
      case "size":
        var cell = tvc.outlineView.makeView(withIdentifier: identifier, owner: tvc.outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeTextOnlyCell(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = StringUtil.formatByteCount(node.sizeBytes)
        return cell
      case "etc":
        var cell = tvc.outlineView.makeView(withIdentifier: identifier, owner: tvc.outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeTextOnlyCell(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = String(node.etc)
        return cell
      case "mtime":
        var cell = tvc.outlineView.makeView(withIdentifier: identifier, owner: tvc.outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeTextOnlyCell(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = DateUtil.formatTS(node.modifyTS)
        return cell
      case "ctime":
        var cell = tvc.outlineView.makeView(withIdentifier: identifier, owner: tvc.outlineView.delegate) as? NSTableCellView
        if cell == nil {
          cell = makeTextOnlyCell(withIdentifier: identifier)
        }
        cell!.textField!.stringValue = DateUtil.formatTS(node.changeTS)
        return cell
      default:
        NSLog("ERROR [\(tvc.treeID)] unrecognized identifier (ignoring): \(identifier.rawValue)")
        return nil
    }
  }

  // note: it's ok for cellHeight to be larger than necessary (the icon will not be larger than will fit)
  private static func makeIcon(_ sn: SPIDNodePair, _ cell: NSTableCellView, _ cellHeight: CGFloat,
                               _ tvc: TreeViewController) -> NSImage? {
    return tvc.con.app.iconStore.getTreeIcon(sn.node, height: cellHeight)
  }

  private static func makeNameCell(for sn: SPIDNodePair, withIdentifier identifier: NSUserInterfaceItemIdentifier, _ tvc: TreeViewController) -> NameCellView {
    let cell = NameCellView()
    cell.identifier = identifier

    // 1. Checkbox (if applicable)
    if tvc.con.swiftTreeState.hasCheckboxes {
      let checkbox = CellCheckboxButton(sn: sn, parent: tvc)
      checkbox.sizeToFit()
      cell.addSubview(checkbox)
      cell.checkbox = checkbox
    }

    // 2. Icon
    guard let icon = self.makeIcon(sn, cell, TREE_VIEW_CELL_HEIGHT, tvc) else {
      return cell
    }
    // make all the image components:
    let imageView = NSImageView(image: icon)
    imageView.imageFrameStyle = .none
    imageView.imageScaling = .scaleProportionallyDown
    cell.addSubview(imageView)
    cell.imageView = imageView

    // 3. Text field
    let textField = makeCellTextField()
    cell.addSubview(textField)
    cell.textField = textField

    // Constrain the text field within the cell
    textField.sizeToFit()

    var prev: NSControl?
    for widget in cell.getComponentList() {
      widget.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true

      if let previous = prev {
        widget.leadingAnchor.constraint(equalTo: previous.trailingAnchor, constant: 4.0).isActive = true
      } else {
        widget.leadingAnchor.constraint(equalTo: cell.leadingAnchor).isActive = true
      }

      prev = widget
    }

    cell.needsLayout = true

    return cell
  }

  private static func makeCellTextField() -> CustomFontNSTextField {
    let textField = CustomFontNSTextField()
    textField.backgroundColor = NSColor.clear
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.isBordered = false
    textField.isBezeled = false
    textField.isEditable = false
    textField.customSetFont(TREE_VIEW_NSFONT)
    textField.lineBreakMode = .byTruncatingTail
    return textField
  }

  private static func makeTextOnlyCell(withIdentifier identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
    let cell = NSTableCellView()
    cell.identifier = identifier

    let textField = makeCellTextField()
    cell.addSubview(textField)
    cell.textField = textField

    // Constrain the text field within the cell
    textField.heightAnchor.constraint(lessThanOrEqualTo: cell.heightAnchor).isActive = true
    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true
    textField.sizeToFit()
//    textField.setFrameOrigin(NSZeroPoint)

    return cell
  }

}
