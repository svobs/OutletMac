//
// Created by Matthew Svoboda on 21/5/19.
// Copyright (c) 2021 Matt Svoboda. All rights reserved.
//

import AppKit

// For drag & drop
extension NSPasteboard.PasteboardType {
    static let guid = NSPasteboard.PasteboardType("com.outlet.guid")
}

class NodePasteboardWriter: NSObject, NSPasteboardWriting {
    var guid: GUID
//    var localFileURL: URL

    init(guid: GUID) {
        self.guid = guid
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.guid]
        // TODO: support fileURL type for external drops
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .guid:
            return guid
//        case .fileURL:
//            return localFileURL
        default:
            return nil
        }
    }
}
