//
//  OutlineViewFactory.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/5/6.
//  Copyright © 2021 Matt Svoboda. All rights reserved.
//

import AppKit

class OutlineViewFactory {

  // The word "build" is used loosely here, since the topView and outlineView are already created.
  // But do not call this more than once, because it adds components.
  static func buildOutlineView(_ topView: NSView, outlineView: NSOutlineView) {
    let scrollView = OutlineViewFactory.addScrollView(topView)

    outlineView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
    outlineView.autosaveTableColumns = true
    outlineView.autosaveExpandedItems = true
    outlineView.rowSizeStyle = .large
    outlineView.lineBreakMode = .byTruncatingTail
    outlineView.cell?.truncatesLastVisibleLine = true
    outlineView.autoresizesOutlineColumn = true
    outlineView.indentationPerLevel = 16
    outlineView.appearance = NSAppearance(named: NSAppearance.Name.vibrantDark)

    outlineView.headerView = NSTableHeaderView()

    // Columns:

    let nodeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: NAME_COL_KEY))
    nodeColumn.title = "Name"
    nodeColumn.width = 300
    nodeColumn.minWidth = 150
    nodeColumn.isEditable = false
    outlineView.addTableColumn(nodeColumn)
    nodeColumn.sortDescriptorPrototype = NSSortDescriptor(key: NAME_COL_KEY, ascending: true)

    let sizeBytesCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: SIZE_COL_KEY))
    sizeBytesCol.title = "Size"
    sizeBytesCol.width = 70
    sizeBytesCol.minWidth = 70
    sizeBytesCol.isEditable = false
    outlineView.addTableColumn(sizeBytesCol)
    sizeBytesCol.sortDescriptorPrototype = NSSortDescriptor(key: SIZE_COL_KEY, ascending: true)

    let etcCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: ETC_COL_KEY))
    etcCol.title = "Etc"
    etcCol.width = 200
    etcCol.minWidth = 100
    etcCol.isEditable = false
    outlineView.addTableColumn(etcCol)

    let mtimeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: MODIFY_TS_COL_KEY))
    mtimeCol.title = "Modification Time"
    mtimeCol.width = 200
    mtimeCol.minWidth = 100
    mtimeCol.isEditable = false
    outlineView.addTableColumn(mtimeCol)
    mtimeCol.sortDescriptorPrototype = NSSortDescriptor(key: MODIFY_TS_COL_KEY, ascending: true)

    let ctimeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: META_CHANGE_TS_COL_KEY))
    ctimeCol.title = "Meta Change Time"
    ctimeCol.width = 200
    ctimeCol.minWidth = 100
    ctimeCol.isEditable = false
//    ctimeCol.isHidden = true
    outlineView.addTableColumn(ctimeCol)
    ctimeCol.sortDescriptorPrototype = NSSortDescriptor(key: META_CHANGE_TS_COL_KEY, ascending: true)

//    outlineView.backgroundColor = .clear
//    outlineView.usesAlternatingRowBackgroundColors = true // TODO: the colors are screwed up when this is used
//    outlineView.gridStyleMask = .dashedHorizontalGridLineMask
//    outlineView.selectionHighlightStyle = .sourceList // selection highlight has rounded corners (TODO: this introduces ugly extra space)
    outlineView.autosaveExpandedItems = true
    outlineView.usesAutomaticRowHeights = true  // set row height to match font

    scrollView.documentView = outlineView
    outlineView.frame = scrollView.bounds

  }

  private static func addScrollView(_ parentView: NSView) -> NSScrollView {
    let scrollView = NSScrollView()

    scrollView.backgroundColor = NSColor.clear
    scrollView.drawsBackground = false
    scrollView.hasHorizontalScroller = true
    scrollView.hasVerticalScroller = true
    scrollView.horizontalPageScroll = 10
    scrollView.verticalLineScroll = 19
    scrollView.verticalPageScroll = 10
    scrollView.automaticallyAdjustsContentInsets = true

    parentView.addSubview(scrollView)
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    parentView.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .left, relatedBy: .equal, toItem: parentView, attribute: .left, multiplier: 1.0, constant: 0))
    parentView.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal, toItem: parentView, attribute: .top, multiplier: 1.0, constant: 0))
    parentView.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .right, relatedBy: .equal, toItem: parentView, attribute: .right, multiplier: 1.0, constant: 0))
    parentView.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .bottom, relatedBy: .equal, toItem: parentView, attribute: .bottom, multiplier: 1.0, constant: 0))


    return scrollView
  }

}
