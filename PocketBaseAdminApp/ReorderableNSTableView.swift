//
//  ReorderableNSTableView.swift
//  PocketBaseAdminApp
//
//  Created by AI on 6/28/25.
//

import SwiftUI

#if os(macOS)
import AppKit

/// A SwiftUI wrapper for NSTableView with drag-and-drop row reordering support.
struct ReorderableNSTableView<Record: Identifiable & Equatable>: NSViewRepresentable {
    @Binding var records: [Record]
    var columns: [Column]
    var rowContent: (Record) -> [String] // Each row as array of strings (per column)
    
    struct Column: Identifiable {
        let id = UUID()
        let title: String
        let width: CGFloat?
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let tableView = NSTableView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.headerView = NSTableHeaderView()
        
        // Set up columns
        for (i, column) in columns.enumerated() {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_\(i)"))
            tableColumn.title = column.title
            if let width = column.width {
                tableColumn.width = width
            }
            tableView.addTableColumn(tableColumn)
        }
        
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        
        // Enable drag-and-drop reordering
        tableView.registerForDraggedTypes([.string])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)
        
        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let tableView = nsView.documentView as? NSTableView {
            tableView.reloadData()
        }
    }
    
    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: ReorderableNSTableView
        init(_ parent: ReorderableNSTableView) {
            self.parent = parent
        }
        
        // MARK: Data Source
        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.records.count
        }
        func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
            let record = parent.records[row]
            let colIndex = tableView.tableColumns.firstIndex(of: tableColumn!) ?? 0
            let rowValues = parent.rowContent(record)
            return colIndex < rowValues.count ? rowValues[colIndex] : ""
        }
        // MARK: Drag and Drop
        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            let pb = NSPasteboardItem()
            pb.setString("\(row)", forType: .string)
            return pb
        }
        func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
            dropOperation == .above ? .move : []
        }
        func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            guard let item = info.draggingPasteboard.string(forType: .string), let from = Int(item), from != row else { return false }
            var current = parent.records
            let moved = current.remove(at: from)
            let to = row > from ? row - 1 : row
            current.insert(moved, at: to)
            DispatchQueue.main.async { self.parent.records = current }
            return true
        }
        // MARK: Delegate
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let record = parent.records[row]
            let colIndex = tableView.tableColumns.firstIndex(of: tableColumn!) ?? 0
            let rowValues = parent.rowContent(record)
            let text = NSTextField(labelWithString: colIndex < rowValues.count ? rowValues[colIndex] : "")
            text.lineBreakMode = .byTruncatingTail
            text.isBordered = false
            text.isEditable = false
            text.backgroundColor = .clear
            return text
        }
    }
}

// Example usage in SwiftUI:
/*
struct ContentView: View {
    @State var records: [RecordModel]
    var body: some View {
        ReorderableNSTableView(
            records: $records,
            columns: [
                .init(title: "ID", width: 80),
                .init(title: "Name", width: 160)
            ],
            rowContent: { record in
                [record.id, record.collectionName]
            }
        )
        .frame(minWidth: 320, minHeight: 400)
    }
}
*/
#endif // os(macOS)
