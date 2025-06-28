//
//  CollectionView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 3/26/25.
//

import SwiftUI
import PocketBaseAdmin
import PocketBase
import OSLog

@Observable @MainActor
final class CollectionState: Identifiable {
    var collection: CollectionModel
    init(collection: CollectionModel) {
        self.collection = collection
    }
    var records: [RecordModel] = []
    var page: Int = 1
    
    var logger = Logger(subsystem: "PocketBaseAdminApp", category: "RecordsState")
    
    var retryCount: Int = 0
    var maxRetryCount: Int = 5
    
    func load(with pocketbase: PocketBase) async {
        do {
            let newRecords = try await Admin(pocketbase: pocketbase)
                .records(collection.name, page: page)
                .items
            await MainActor.run {
                records = newRecords
            }
            retryCount = 0
        } catch {
            let nsError = error as NSError

            if
                nsError.domain == NSURLErrorDomain,
                nsError.code == NSURLErrorCancelled
            {
                retryCount += 1
                try? await Task.sleep(for: .seconds(1))
                if retryCount >= maxRetryCount {
                    retryCount = 0
                    logger.error("Failed to load records after \(self.maxRetryCount) retries with error \(error)")
                    return
                }
                logger.info("Retring to load records... (Retry count: \(self.retryCount))")
                await load(with: pocketbase)
            }
        }
    }
}

struct CollectionView: View {
    @Bindable var state: CollectionState
    
    private var schema: [Field] {
        state.collection.schema ?? []
    }
    
    @Environment(\.pocketbase) private var pocketbase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        Table(state.records) {
            if horizontalSizeClass == .compact {
                TableColumn("Compact") { record in
                    CompactRecordRow(
                        schema: schema,
                        record: record
                    )
                }
            }
            TableColumnForEach(schema) { field in
                TableColumn(field.name) { record in
                    FieldView(field: field, record: record)
                }
            }
        }
        .task {
            Task.detached {
                print("Loading collection records...")
                await state.load(with: pocketbase)
            }
        }
        .refreshable {
            await state.load(with: pocketbase)
        }
        .navigationTitle(state.collection.name)
    }
}

struct CompactRecordRow: View {
    var schema: [Field]
    var record: RecordModel

    @State private var isSelected = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Toggle("Is Selected", isOn: $isSelected)
                    .labelsHidden()
                ForEach(schema, id: \.name) { field in
                    VStack(alignment: .leading) {
                        FieldView(field: field, record: record)
                        Text(field.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct FieldView: View {
    var field: Field
    var record: RecordModel
    
    var body: some View {
        switch field.name {
        case "id":
            Text(record.id)
        case "collectionId":
            Text(record.collectionId)
        case "collectionName":
            Text(record.collectionName)
        case "expand":
            if let expand = record.expand {
                JSONValueView(value: .dictionary(expand))
            }
        default:
            let fieldValue = record.content[field.name] ?? .null
            switch field.type {
            case .password:
                if case .string(let string) = fieldValue {
                    Text(Array(repeating: "•", count: string.count).joined())
                } else {
                    JSONValueView(value: fieldValue)
                }
            default:
                JSONValueView(value: fieldValue)
            }
        }
    }
}

struct JSONValueView: View {
    var value: JSONValue
    var body: some View {
        switch value {
        case .array(let array):
            VStack {
                ForEach(array, id: \.self) { item in
                    JSONValueView(value: item)
                }
            }
        case .bool(let bool):
            Text("\(bool)")
        case .date(let date):
            Text(date, format: .dateTime)
        case .decimal(let decimal):
            Text(decimal, format: .number)
        case .url(let url):
            Link(destination: url) {
                Text(url.absoluteString)
            }
        case .dictionary(let dictionary):
            VStack {
                ForEach(Array(dictionary.keys).sorted(), id: \.self) { key in
                    HStack {
                        Text(key) + Text(verbatim: ":")
                        if let value = dictionary[key] {
                            JSONValueView(value: value)
                        }
                    }
                }
            }
        case .double(let double):
            Text(double, format: .number)
        case .null:
            Text("(Empty)")
                .foregroundStyle(.secondary)
        case .string(let string):
            Text(string)
        case .int(let int):
            Text(int, format: .number)
        }
    }
}

#if os(macOS)
enum UserInterfaceSizeClass {
    case compact
    case regular
}

struct HorizontalSizeClassEnvironmentKey: EnvironmentKey {
    static let defaultValue: UserInterfaceSizeClass = .regular
}

struct VerticalSizeClassEnvironmentKey: EnvironmentKey {
    static let defaultValue: UserInterfaceSizeClass = .regular
}

extension EnvironmentValues {
    var horizontalSizeClass: UserInterfaceSizeClass {
        get { self[HorizontalSizeClassEnvironmentKey.self] }
        set { self[HorizontalSizeClassEnvironmentKey.self] = newValue }
    }

    var verticalSizeClass: UserInterfaceSizeClass {
        get { self[VerticalSizeClassEnvironmentKey.self] }
        set { self[VerticalSizeClassEnvironmentKey.self] = newValue }
    }
}
#endif
