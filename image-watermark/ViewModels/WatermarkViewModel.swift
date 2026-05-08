import SwiftUI
import UniformTypeIdentifiers
import ImageIO

@Observable
class WatermarkViewModel {
    var images: [ImageItem] = []
    var settings = WatermarkSettings()
    var selectedImageID: UUID?
    var outputFolderURL: URL?
    var isProcessing = false
    var processedCount = 0
    var totalCount = 0
    var processingTask: Task<Void, Never>?

    var selectedImage: ImageItem? {
        guard let id = selectedImageID else { return nil }
        return images.first { $0.id == id }
    }

    var outputFolderName: String {
        outputFolderURL?.lastPathComponent ?? "未选择"
    }

    var canProcess: Bool {
        !images.isEmpty && outputFolderURL != nil && !isProcessing
    }

    var imagesWithDate: Int {
        images.filter { $0.exifDate != nil }.count
    }

    // MARK: - Import Images

    func importImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff]
        panel.message = "选择要添加水印的图片"

        guard panel.runModal() == .OK else { return }

        let urls = panel.urls
        for url in urls {
            // Skip duplicates
            guard !images.contains(where: { $0.url == url }) else { continue }

            let thumbnail = EXIFReader.generateThumbnail(from: url)
            let exifDate = EXIFReader.readDateTaken(from: url)
            let deviceInfo = EXIFReader.readDeviceInfo(from: url)

            var item = ImageItem(url: url, thumbnail: thumbnail, exifDate: exifDate, deviceInfo: deviceInfo, locationInfo: nil)
            if exifDate == nil {
                item.status = .noDate
            }
            images.append(item)
        }

        // Auto-select first image
        if selectedImageID == nil, let first = images.first {
            selectedImageID = first.id
        }

        // Async: resolve location info via reverse geocoding
        Task {
            for i in images.indices {
                if images[i].locationInfo == nil {
                    let loc = await EXIFReader.readLocationInfo(from: images[i].url)
                    images[i].locationInfo = loc
                }
            }
        }
    }

    // MARK: - Select Output Folder

    func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "选择输出文件夹"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputFolderURL = url
    }

    // MARK: - Remove Images

    func removeSelected() {
        guard let id = selectedImageID else { return }
        images.removeAll { $0.id == id }
        selectedImageID = images.first?.id
    }

    func clearAll() {
        images.removeAll()
        selectedImageID = nil
    }

    // MARK: - Preview

    func generatePreview() -> NSImage? {
        guard let item = selectedImage,
              let exifDate = item.exifDate,
              let thumbnail = item.thumbnail else {
            return selectedImage?.thumbnail
        }

        // Read original image height for proportional scaling
        let originalHeight = Self.readImageHeight(from: item.url) ?? thumbnail.representations.first.map { $0.pixelsHigh } ?? Int(thumbnail.size.height)

        let config = makeRenderConfig(date: exifDate, deviceInfo: item.deviceInfo, locationInfo: item.locationInfo)
        return WatermarkRenderer.renderPreview(image: thumbnail, originalHeight: originalHeight, config: config)
    }

    private static func readImageHeight(from url: URL) -> Int? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let height = properties[kCGImagePropertyPixelHeight as String] as? Int else {
            return nil
        }
        return height
    }

    // MARK: - Batch Processing

    func startBatchProcessing() {
        guard let outputFolder = outputFolderURL else { return }

        isProcessing = true
        let imagesToProcess = images.filter { $0.exifDate != nil }
        totalCount = imagesToProcess.count
        processedCount = 0

        // Reset statuses
        for i in images.indices {
            if images[i].exifDate != nil {
                images[i].status = .pending
            }
        }

        processingTask = Task {
            let maxConcurrency = ProcessInfo.processInfo.activeProcessorCount

            await withTaskGroup(of: (UUID, ProcessingStatus).self) { group in
                var running = 0

                for item in imagesToProcess {
                    if Task.isCancelled { break }

                    // Mark as processing
                    if let idx = self.images.firstIndex(where: { $0.id == item.id }) {
                        self.images[idx].status = .processing
                    }

                    running += 1
                    let itemID = item.id
                    let itemURL = item.url
                    let date = item.exifDate!
                    let config = self.makeRenderConfig(date: date, deviceInfo: item.deviceInfo, locationInfo: item.locationInfo)
                    let outputURL = outputFolder.appendingPathComponent(item.fileName)

                    group.addTask { @Sendable [config, itemURL, outputURL] in
                        do {
                            guard let rendered = WatermarkRenderer.render(imageAt: itemURL, config: config) else {
                                return (itemID, .failed("渲染失败"))
                            }
                            try WatermarkRenderer.saveImage(rendered, to: outputURL, sourceURL: itemURL, compressionQuality: config.compressionQuality)
                            return (itemID, .completed)
                        } catch {
                            return (itemID, .failed(error.localizedDescription))
                        }
                    }

                    if running >= maxConcurrency {
                        if let result = await group.next() {
                            running -= 1
                            self.updateItemStatus(id: result.0, status: result.1)
                            self.processedCount += 1
                        }
                    }
                }

                // Collect remaining
                for await result in group {
                    self.updateItemStatus(id: result.0, status: result.1)
                    self.processedCount += 1
                }
            }

            self.isProcessing = false
        }
    }

    func cancelProcessing() {
        processingTask?.cancel()
        isProcessing = false
    }

    // MARK: - Helpers

    private func updateItemStatus(id: UUID, status: ProcessingStatus) {
        if let idx = images.firstIndex(where: { $0.id == id }) {
            images[idx].status = status
        }
    }

    private func makeRenderConfig(date: Date, deviceInfo: String? = nil, locationInfo: String? = nil) -> WatermarkRenderer.RenderConfig {
        WatermarkRenderer.RenderConfig(
            date: date,
            dateFormat: settings.dateFormat,
            position: settings.position,
            fontSize: settings.fontSize,
            textColor: NSColor(settings.textColor),
            shadowEnabled: settings.shadowEnabled,
            opacity: settings.opacity,
            marginRatio: settings.marginRatio,
            compressionQuality: settings.compressionQuality,
            deviceInfo: settings.showDeviceInfo ? deviceInfo : nil,
            locationInfo: settings.showLocationInfo ? locationInfo : nil
        )
    }
}
