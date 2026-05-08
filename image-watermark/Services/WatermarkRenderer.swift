import AppKit
import ImageIO
import CoreGraphics
import CoreText
import UniformTypeIdentifiers

struct WatermarkRenderer {
    struct RenderConfig {
        let date: Date
        let dateFormat: String
        let position: WatermarkPosition
        let fontSize: Double // 0 = auto
        let textColor: NSColor
        let shadowEnabled: Bool
        let opacity: Double
        let marginRatio: Double
        let compressionQuality: Double
        let deviceInfo: String? // nil = don't show device info
        let locationInfo: String? // nil = don't show location
    }

    static func render(imageAt url: URL, config: RenderConfig) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

        // Calculate font size
        let calculatedFontSize: CGFloat
        if config.fontSize > 0 {
            calculatedFontSize = CGFloat(config.fontSize)
        } else {
            calculatedFontSize = max(CGFloat(height) * 0.03, 24.0)
        }

        // Create bitmap context
        let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Draw original image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Draw watermark text using Core Text (thread-safe)
        drawWatermarkText(in: context, width: width, height: height, fontSize: calculatedFontSize, config: config)

        return context.makeImage()
    }

    static func saveImage(_ cgImage: CGImage, to url: URL, sourceURL: URL, compressionQuality: Double = 1.0) throws {
        // Determine output type from file extension
        let utType = utTypeForURL(url) ?? UTType.jpeg

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            utType.identifier as CFString,
            1,
            nil
        ) else {
            throw WatermarkError.cannotCreateDestination
        }

        // Copy original metadata
        var imageProperties: [String: Any] = [:]
        if let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
           let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
            imageProperties = sourceProperties
        }

        // Set JPEG/HEIC compression quality
        if utType == .jpeg || utType == .heic {
            imageProperties[kCGImageDestinationLossyCompressionQuality as String] = compressionQuality
        }

        CGImageDestinationAddImage(destination, cgImage, imageProperties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw WatermarkError.cannotFinalize
        }
    }

    static func renderPreview(image: NSImage, originalHeight: Int, config: RenderConfig) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

        // Calculate font size based on ORIGINAL image dimensions, then scale to thumbnail
        let scaleFactor = CGFloat(height) / CGFloat(originalHeight)
        let calculatedFontSize: CGFloat
        if config.fontSize > 0 {
            calculatedFontSize = CGFloat(config.fontSize) * scaleFactor
        } else {
            let originalFontSize = max(CGFloat(originalHeight) * 0.03, 24.0)
            calculatedFontSize = originalFontSize * scaleFactor
        }

        let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Draw watermark text using Core Text (thread-safe)
        drawWatermarkText(in: context, width: width, height: height, fontSize: calculatedFontSize, config: config)

        guard let resultImage = context.makeImage() else { return nil }
        return NSImage(cgImage: resultImage, size: NSSize(width: width, height: height))
    }

    // MARK: - Core Text Drawing (Thread-Safe)

    private static func drawWatermarkText(
        in context: CGContext,
        width: Int,
        height: Int,
        fontSize: CGFloat,
        config: RenderConfig
    ) {
        // Format date string, append location if available
        let formatter = DateFormatter()
        formatter.dateFormat = config.dateFormat
        var firstLine = formatter.string(from: config.date)
        if let locationInfo = config.locationInfo, !locationInfo.isEmpty {
            firstLine += "  " + locationInfo
        }

        // Build lines: date (+location) on first line, device info on second line (if enabled)
        var textLines: [String] = [firstLine]
        if let deviceInfo = config.deviceInfo, !deviceInfo.isEmpty {
            textLines.append(deviceInfo)
        }

        // Create fonts
        let ctFont = CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
        let smallFont = CTFontCreateWithName("Menlo" as CFString, fontSize * 0.75, nil)

        // Prepare text color with opacity
        let colorWithOpacity = config.textColor.withAlphaComponent(CGFloat(config.opacity))
        let cgColor = colorWithOpacity.cgColor

        let mainAttributes: [CFString: Any] = [
            kCTFontAttributeName: ctFont,
            kCTForegroundColorAttributeName: cgColor
        ]
        let subAttributes: [CFString: Any] = [
            kCTFontAttributeName: smallFont,
            kCTForegroundColorAttributeName: cgColor
        ]

        // Measure each line
        struct LineMetrics {
            let ctLine: CTLine
            let width: CGFloat
            let ascent: CGFloat
            let descent: CGFloat
            let leading: CGFloat
            var height: CGFloat { ascent + descent + leading }
        }

        var metrics: [LineMetrics] = []
        for (index, text) in textLines.enumerated() {
            let attrs = index == 0 ? mainAttributes : subAttributes
            let attrString = CFAttributedStringCreate(kCFAllocatorDefault, text as CFString, attrs as CFDictionary)!
            let ctLine = CTLineCreateWithAttributedString(attrString)
            var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
            let w = CGFloat(CTLineGetTypographicBounds(ctLine, &a, &d, &l))
            metrics.append(LineMetrics(ctLine: ctLine, width: w, ascent: a, descent: d, leading: l))
        }

        // Calculate total block dimensions
        let lineSpacing: CGFloat = fontSize * 0.3
        let maxLineWidth = metrics.map(\.width).max() ?? 0
        let totalHeight = metrics.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(metrics.count - 1, 0))

        // Calculate block position
        let margin = CGFloat(config.marginRatio) * CGFloat(height)
        let blockOriginX: CGFloat
        let blockOriginY: CGFloat // bottom of the text block

        switch config.position {
        case .bottomRight:
            blockOriginX = CGFloat(width) - maxLineWidth - margin
            blockOriginY = margin
        case .bottomLeft:
            blockOriginX = margin
            blockOriginY = margin
        case .topRight:
            blockOriginX = CGFloat(width) - maxLineWidth - margin
            blockOriginY = CGFloat(height) - totalHeight - margin
        case .topLeft:
            blockOriginX = margin
            blockOriginY = CGFloat(height) - totalHeight - margin
        }

        // Draw lines top-to-bottom (in CG coords: highest y first)
        var currentY = blockOriginY + totalHeight
        for (index, info) in metrics.enumerated() {
            currentY -= info.ascent
            let lineX: CGFloat
            switch config.position {
            case .bottomRight, .topRight:
                lineX = blockOriginX + maxLineWidth - info.width
            case .bottomLeft, .topLeft:
                lineX = blockOriginX
            }

            let drawPoint = CGPoint(x: lineX, y: currentY)

            if config.shadowEnabled {
                context.saveGState()
                context.setShadow(
                    offset: CGSize(width: 2, height: -2),
                    blur: 3,
                    color: NSColor.black.withAlphaComponent(0.8).cgColor
                )
                context.textPosition = drawPoint
                CTLineDraw(info.ctLine, context)
                context.restoreGState()
            } else {
                context.textPosition = drawPoint
                CTLineDraw(info.ctLine, context)
            }

            currentY -= (info.descent + info.leading)
            if index < metrics.count - 1 {
                currentY -= lineSpacing
            }
        }
    }

    private static func utTypeForURL(_ url: URL) -> UTType? {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg":
            return .jpeg
        case "png":
            return .png
        case "heic", "heif":
            return .heic
        case "tiff", "tif":
            return .tiff
        default:
            return .jpeg
        }
    }
}

enum WatermarkError: LocalizedError {
    case cannotCreateDestination
    case cannotFinalize
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .cannotCreateDestination:
            return "无法创建输出文件"
        case .cannotFinalize:
            return "保存图片失败"
        case .renderFailed:
            return "渲染水印失败"
        }
    }
}
