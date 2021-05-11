//
// Created by Matthew Svoboda on 21/5/10.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import SwiftUI

/**
 Container class for all GDrive root chooser dialog data. Actual view starts with GDriveRootChooserContent
 */
class MergePreview: PopUpTreePanel {

    override init(_ app: OutletApp, _ con: TreePanelControllable, initialSelection: SPIDNodePair? = nil) {
        super.init(app, con, initialSelection: initialSelection)
        assert(con.treeID == ID_MERGE_TREE)
        self.window.center()
        self.window.title = "Confirm Merge"

//        window.contentView = NSHostingView(rootView: content)
//    window.setDefaultButtonCell(
    }

}
