//
//  TreeView.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/2/16.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import Cocoa

class BaseView: NSView {
  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  init() {
    super.init(frame: .zero)
    setup()
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setup()
  }

  func setup() {
    addSubviews()
    addConstraints()
  }

  func addSubviews() { }
  func addConstraints() { }
}

class TreeView: BaseView {
  var scrollViewTreeView = NSScrollView()

  var treeView: NSOutlineView = {
    let table = NSOutlineView(frame: .zero)
    table.rowSizeStyle = .large
    table.backgroundColor = .clear

    table.headerView = NSTableHeaderView()
    let nodeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "node"))
    nodeColumn.title = "Nodes"
//    nodeColumn.dataCell = NSTableCellView()
    // TODO!

    nodeColumn.width = 200
    table.addTableColumn(nodeColumn)
    let countColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "count"))
    countColumn.title = "Count"
    countColumn.width = 100
    table.addTableColumn(countColumn)
    return table
  }()

  override func addSubviews() {
    scrollViewTreeView.documentView = treeView
    [scrollViewTreeView].forEach(addSubview)
  }

  override func addConstraints() {
    scrollViewTreeView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([scrollViewTreeView.topAnchor.constraint(equalTo: scrollViewTreeView.superview!.topAnchor),
                                 scrollViewTreeView.leadingAnchor.constraint(equalTo: scrollViewTreeView.superview!.leadingAnchor),
                                 scrollViewTreeView.trailingAnchor.constraint(equalTo: scrollViewTreeView.superview!.trailingAnchor),
                                 scrollViewTreeView.bottomAnchor.constraint(equalTo: scrollViewTreeView.superview!.bottomAnchor)
    ])
  }
}

