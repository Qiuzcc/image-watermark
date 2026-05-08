import AppKit

enum ProcessingStatus: Equatable {
    case pending
    case processing
    case completed
    case failed(String)
    case noDate
}

struct ImageItem: Identifiable {
    let id = UUID()
    let url: URL
    var fileName: String { url.lastPathComponent }
    var thumbnail: NSImage?
    var exifDate: Date?
    var deviceInfo: String?
    var locationInfo: String?
    var status: ProcessingStatus = .pending
}
