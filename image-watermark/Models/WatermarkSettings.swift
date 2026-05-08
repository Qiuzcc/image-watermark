import SwiftUI

enum WatermarkPosition: String, CaseIterable {
    case topLeft = "左上"
    case topRight = "右上"
    case bottomLeft = "左下"
    case bottomRight = "右下"
}

@Observable
class WatermarkSettings {
    var dateFormat: String = "yyyy/MM/dd HH:mm"
    var position: WatermarkPosition = .bottomRight
    var fontSize: Double = 0 // 0 means auto
    var textColor: Color = .white
    var shadowEnabled: Bool = true
    var opacity: Double = 0.85
    var marginRatio: Double = 0.03
    var compressionQuality: Double = 0.95
    var showDeviceInfo: Bool = false
    var showLocationInfo: Bool = false
}
