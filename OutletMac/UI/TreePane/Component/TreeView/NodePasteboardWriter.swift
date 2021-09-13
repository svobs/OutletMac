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
    var guidValue: GUID
    var fileURLValue: String?

    init(guid: GUID, fileURL: String? = nil) {
        self.guidValue = guid
        self.fileURLValue = fileURL
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.guid, .fileURL]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .guid:
            return guidValue
        case .fileURL:
            return fileURLValue
        default:
            return nil
        }
    }
}
