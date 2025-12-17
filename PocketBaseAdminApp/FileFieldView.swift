//
//  FileFieldView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import NukeUI
import PocketBase
import PocketBaseAdmin
import UniformTypeIdentifiers

#if os(iOS)
import QuickLook
#elseif os(macOS)
import QuickLookUI
#endif

#if os(visionOS)
import RealityKit
#endif

// MARK: - File Type Detection

enum FileCategory {
    case image
    case video
    case audio
    case pdf
    case document
    case archive
    case code
    case model3D
    case unknown

    var icon: String {
        switch self {
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "waveform"
        case .pdf: return "doc.richtext"
        case .document: return "doc.text"
        case .archive: return "archivebox"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .model3D: return "cube"
        case .unknown: return "doc"
        }
    }

    var color: Color {
        switch self {
        case .image: return .blue
        case .video: return .purple
        case .audio: return .orange
        case .pdf: return .red
        case .document: return .blue
        case .archive: return .brown
        case .code: return .green
        case .model3D: return .cyan
        case .unknown: return .gray
        }
    }

    static func from(filename: String) -> FileCategory {
        let ext = (filename as NSString).pathExtension.lowercased()

        switch ext {
        // Images
        case "jpg", "jpeg", "png", "gif", "webp", "svg", "ico", "bmp", "tiff", "tif", "heic", "heif", "avif":
            return .image
        // Videos
        case "mp4", "mov", "avi", "mkv", "webm", "m4v", "mpeg", "mpg", "wmv", "flv":
            return .video
        // Audio
        case "mp3", "wav", "m4a", "aac", "ogg", "flac", "aiff", "wma":
            return .audio
        // PDF
        case "pdf":
            return .pdf
        // 3D Models (Quick Look supports these)
        case "usdz", "usda", "usdc", "usd", "obj", "stl", "dae", "abc", "ply", "gltf", "glb", "3ds", "fbx", "scn":
            return .model3D
        // Documents
        case "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "odt", "ods", "odp", "pages", "numbers", "key":
            return .document
        // Archives
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg":
            return .archive
        // Code
        case "swift", "js", "ts", "py", "rb", "go", "rs", "java", "kt", "c", "cpp", "h", "hpp", "cs", "php", "html", "css", "json", "xml", "yaml", "yml", "md", "sh", "bash", "zsh":
            return .code
        default:
            return .unknown
        }
    }

    var canPreviewInline: Bool {
        switch self {
        case .image, .video, .pdf, .model3D: return true
        default: return false
        }
    }

    /// Whether this file type is visual media (images/videos for card headers)
    var isVisualMedia: Bool {
        switch self {
        case .image, .video: return true
        default: return false
        }
    }
}

// MARK: - File Field View

struct FileFieldView: View {
    let fieldValue: JSONValue
    let record: RecordModel
    let pocketbase: PocketBase
    let isCompact: Bool

    @State private var selectedFileForPreview: FilePreviewItem?

    init(fieldValue: JSONValue, record: RecordModel, pocketbase: PocketBase, isCompact: Bool = false) {
        self.fieldValue = fieldValue
        self.record = record
        self.pocketbase = pocketbase
        self.isCompact = isCompact
    }

    private var filenames: [String] {
        switch fieldValue {
        case .string(let filename) where !filename.isEmpty:
            return [filename]
        case .array(let array):
            return array.compactMap { item -> String? in
                if case .string(let filename) = item, !filename.isEmpty {
                    return filename
                }
                return nil
            }
        default:
            return []
        }
    }

    var body: some View {
        if filenames.isEmpty {
            Text("No files")
                .foregroundStyle(.secondary)
        } else if isCompact {
            compactView
        } else {
            expandedView
        }
    }

    @ViewBuilder
    private var compactView: some View {
        if filenames.count == 1, let filename = filenames.first {
            SingleFileCompactView(
                filename: filename,
                record: record,
                pocketbase: pocketbase,
                onPreview: { item in selectedFileForPreview = item }
            )
            .quickLookPreview($selectedFileForPreview)
        } else {
            HStack(spacing: 4) {
                ForEach(filenames.prefix(3), id: \.self) { filename in
                    FileIconView(filename: filename, size: 20)
                }
                if filenames.count > 3 {
                    Text("+\(filenames.count - 3)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(filenames, id: \.self) { filename in
                SingleFileView(
                    filename: filename,
                    record: record,
                    pocketbase: pocketbase,
                    onPreview: { item in selectedFileForPreview = item }
                )
            }
        }
        .quickLookPreview($selectedFileForPreview)
    }
}

// MARK: - Single File View

struct SingleFileView: View {
    let filename: String
    let record: RecordModel
    let pocketbase: PocketBase
    let onPreview: (FilePreviewItem) -> Void

    private var fileURL: URL {
        pocketbase.fileURL(
            collectionIdOrName: record.collectionName,
            recordId: record.id,
            filename: filename
        )
    }

    private var thumbnailURL: URL {
        pocketbase.fileURL(
            collectionIdOrName: record.collectionName,
            recordId: record.id,
            filename: filename,
            thumb: .fit(width: 200, height: 200)
        )
    }

    private var category: FileCategory {
        FileCategory.from(filename: filename)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or icon based on file type
            fileThumbnail
                .frame(width: 48, height: 48)

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(filename)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(categoryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                // Preview button
                Button {
                    Task {
                        await downloadAndPreview()
                    }
                } label: {
                    Image(systemName: "eye")
                }
                .buttonStyle(.borderless)
                .help("Preview")

                // Open in browser/download
                Link(destination: fileURL) {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .help("Download")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
        )
    }

    @ViewBuilder
    private var fileThumbnail: some View {
        switch category {
        case .image:
            LazyImage(url: thumbnailURL) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if state.error != nil {
                    FileIconView(filename: filename, size: 32)
                } else {
                    ProgressView()
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))

        case .video:
            VideoThumbnailView(thumbnailURL: thumbnailURL, size: 48)

        case .model3D:
            #if os(visionOS)
            Model3DPreviewView(url: fileURL, size: 48)
            #else
            FileIconView(filename: filename, size: 32)
                .frame(width: 48, height: 48)
            #endif

        default:
            FileIconView(filename: filename, size: 32)
                .frame(width: 48, height: 48)
        }
    }

    private var categoryLabel: String {
        switch category {
        case .image: return "Image"
        case .video: return "Video"
        case .audio: return "Audio"
        case .pdf: return "PDF"
        case .document: return "Document"
        case .archive: return "Archive"
        case .code: return "Code"
        case .model3D: return "3D Model"
        case .unknown: return "File"
        }
    }

    @MainActor
    private func downloadAndPreview() async {
        // Download the file to a temp location for Quick Look
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent(filename)

        do {
            // Remove existing file if present
            try? FileManager.default.removeItem(at: localURL)

            let (data, _) = try await URLSession.shared.data(from: fileURL)
            try data.write(to: localURL)

            onPreview(FilePreviewItem(url: localURL))
        } catch {
            print("Failed to download file for preview: \(error)")
        }
    }
}

// MARK: - Single File Compact View (for table cells)

struct SingleFileCompactView: View {
    let filename: String
    let record: RecordModel
    let pocketbase: PocketBase
    let onPreview: (FilePreviewItem) -> Void

    private var thumbnailURL: URL {
        pocketbase.fileURL(
            collectionIdOrName: record.collectionName,
            recordId: record.id,
            filename: filename,
            thumb: .crop(width: 60, height: 60)
        )
    }

    private var fileURL: URL {
        pocketbase.fileURL(
            collectionIdOrName: record.collectionName,
            recordId: record.id,
            filename: filename
        )
    }

    private var category: FileCategory {
        FileCategory.from(filename: filename)
    }

    var body: some View {
        HStack(spacing: 6) {
            if category == .image {
                LazyImage(url: thumbnailURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if state.error != nil {
                        FileIconView(filename: filename, size: 16)
                    } else {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                FileIconView(filename: filename, size: 16)
            }

            Text(filename)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                await downloadAndPreview()
            }
        }
    }

    @MainActor
    private func downloadAndPreview() async {
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent(filename)

        do {
            try? FileManager.default.removeItem(at: localURL)
            let (data, _) = try await URLSession.shared.data(from: fileURL)
            try data.write(to: localURL)
            onPreview(FilePreviewItem(url: localURL))
        } catch {
            print("Failed to download file for preview: \(error)")
        }
    }
}

// MARK: - File Icon View

struct FileIconView: View {
    let filename: String
    let size: CGFloat

    private var category: FileCategory {
        FileCategory.from(filename: filename)
    }

    var body: some View {
        Image(systemName: category.icon)
            .font(.system(size: size * 0.6))
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.15)
                    .fill(category.color.opacity(0.15))
            )
    }
}

// MARK: - Quick Look Preview Item

struct FilePreviewItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    static func == (lhs: FilePreviewItem, rhs: FilePreviewItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Quick Look Preview Modifier

extension View {
    @ViewBuilder
    func quickLookPreview(_ item: Binding<FilePreviewItem?>) -> some View {
        #if os(iOS)
        self.fullScreenCover(item: item) { previewItem in
            QuickLookPreviewController(url: previewItem.url)
                .ignoresSafeArea()
        }
        #elseif os(macOS)
        self.onChange(of: item.wrappedValue) { _, newValue in
            if let previewItem = newValue {
                QuickLookPreviewMac.preview(url: previewItem.url)
                // Reset the binding after showing
                DispatchQueue.main.async {
                    item.wrappedValue = nil
                }
            }
        }
        #else
        self
        #endif
    }
}

// MARK: - iOS Quick Look Controller

#if os(iOS)
struct QuickLookPreviewController: UIViewControllerRepresentable {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, dismiss: dismiss)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let url: URL
        let dismiss: DismissAction

        init(url: URL, dismiss: DismissAction) {
            self.url = url
            self.dismiss = dismiss
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }

        func previewControllerDidDismiss(_ controller: QLPreviewController) {
            dismiss()
        }
    }
}
#endif

// MARK: - macOS Quick Look

#if os(macOS)
import AppKit

enum QuickLookPreviewMac {
    static func preview(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
        // Alternative: Use QLPreviewPanel for in-app preview
        if QLPreviewPanel.sharedPreviewPanelExists() || QLPreviewPanel.shared().isVisible {
            QLPreviewPanel.shared().reloadData()
        } else {
            QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
        }
    }
}
#endif

// MARK: - Image Preview View (for inline image display in inspector)

struct ImagePreviewView: View {
    let url: URL
    let maxHeight: CGFloat

    var body: some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: maxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if state.error != nil {
                ContentUnavailableView {
                    Label("Failed to load", systemImage: "exclamationmark.triangle")
                }
            } else {
                ProgressView()
                    .frame(height: 100)
            }
        }
    }
}

// MARK: - Multi-File Gallery View (for inspector)

struct FileGalleryView: View {
    let filenames: [String]
    let record: RecordModel
    let pocketbase: PocketBase

    @State private var selectedFileForPreview: FilePreviewItem?

    private var imageFiles: [String] {
        filenames.filter { FileCategory.from(filename: $0) == .image }
    }

    private var otherFiles: [String] {
        filenames.filter { FileCategory.from(filename: $0) != .image }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image gallery
            if !imageFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(imageFiles, id: \.self) { filename in
                            let thumbnailURL = pocketbase.fileURL(
                                collectionIdOrName: record.collectionName,
                                recordId: record.id,
                                filename: filename,
                                thumb: .crop(width: 150, height: 150)
                            )

                            LazyImage(url: thumbnailURL) { state in
                                if let image = state.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else if state.error != nil {
                                    FileIconView(filename: filename, size: 40)
                                } else {
                                    ProgressView()
                                }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture {
                                Task {
                                    await downloadAndPreview(filename: filename)
                                }
                            }
                        }
                    }
                }
            }

            // Other files list
            if !otherFiles.isEmpty {
                ForEach(otherFiles, id: \.self) { filename in
                    SingleFileView(
                        filename: filename,
                        record: record,
                        pocketbase: pocketbase,
                        onPreview: { item in selectedFileForPreview = item }
                    )
                }
            }
        }
        .quickLookPreview($selectedFileForPreview)
    }

    @MainActor
    private func downloadAndPreview(filename: String) async {
        let fileURL = pocketbase.fileURL(
            collectionIdOrName: record.collectionName,
            recordId: record.id,
            filename: filename
        )

        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent(filename)

        do {
            try? FileManager.default.removeItem(at: localURL)
            let (data, _) = try await URLSession.shared.data(from: fileURL)
            try data.write(to: localURL)
            selectedFileForPreview = FilePreviewItem(url: localURL)
        } catch {
            print("Failed to download file for preview: \(error)")
        }
    }
}

// MARK: - 3D Model Preview (visionOS)

#if os(visionOS)
/// A view that displays a 3D model using RealityKit Model3D on visionOS
struct Model3DPreviewView: View {
    let url: URL
    let size: CGFloat

    @State private var localURL: URL?
    @State private var isLoading = true
    @State private var loadError: Error?

    var body: some View {
        Group {
            if let localURL {
                Model3D(url: localURL) { model in
                    model
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: size, height: size)
            } else if isLoading {
                ProgressView()
                    .frame(width: size, height: size)
            } else {
                FileIconView(filename: url.lastPathComponent, size: size * 0.6)
                    .frame(width: size, height: size)
            }
        }
        .task {
            await downloadModel()
        }
    }

    @MainActor
    private func downloadModel() async {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = url.lastPathComponent
        let tempURL = tempDir.appendingPathComponent(filename)

        do {
            try? FileManager.default.removeItem(at: tempURL)
            let (data, _) = try await URLSession.shared.data(from: url)
            try data.write(to: tempURL)
            localURL = tempURL
        } catch {
            loadError = error
            print("Failed to download 3D model: \(error)")
        }
        isLoading = false
    }
}
#endif

// MARK: - Video Thumbnail View

/// A view that shows a video file with a play button overlay
struct VideoThumbnailView: View {
    let thumbnailURL: URL
    let size: CGFloat

    var body: some View {
        ZStack {
            LazyImage(url: thumbnailURL) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if state.error != nil {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "film")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .overlay { ProgressView() }
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Play button overlay
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
    }
}
