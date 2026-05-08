import ImageIO
import AppKit
import CoreLocation

struct EXIFReader {
    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func readDateTaken(from url: URL) -> Date? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }

        // Try EXIF dictionary first
        if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            // Try DateTimeOriginal
            if let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String,
               let date = exifDateFormatter.date(from: dateString) {
                return date
            }
            // Fallback to DateTimeDigitized
            if let dateString = exifDict[kCGImagePropertyExifDateTimeDigitized as String] as? String,
               let date = exifDateFormatter.date(from: dateString) {
                return date
            }
        }

        // Fallback to TIFF DateTime
        if let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
           let dateString = tiffDict[kCGImagePropertyTIFFDateTime as String] as? String,
           let date = exifDateFormatter.date(from: dateString) {
            return date
        }

        return nil
    }

    static func readDeviceInfo(from url: URL) -> String? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }

        var parts: [String] = []

        // Read camera make and model from TIFF dictionary
        if let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            let make = tiffDict[kCGImagePropertyTIFFMake as String] as? String ?? ""
            let model = tiffDict[kCGImagePropertyTIFFModel as String] as? String ?? ""

            // Avoid duplicating make in model (e.g., "Apple iPhone 15 Pro")
            if !model.isEmpty {
                if model.lowercased().contains(make.lowercased()) || make.isEmpty {
                    parts.append(model)
                } else {
                    parts.append("\(make) \(model)")
                }
            } else if !make.isEmpty {
                parts.append(make)
            }
        }

        // Read lens and focal length from EXIF dictionary
        if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let focalLength = exifDict[kCGImagePropertyExifFocalLength as String] as? Double {
                parts.append(String(format: "%.0fmm", focalLength))
            }
            if let fNumber = exifDict[kCGImagePropertyExifFNumber as String] as? Double {
                parts.append(String(format: "f/%.1g", fNumber))
            }
            if let iso = (exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? [Int])?.first {
                parts.append("ISO\(iso)")
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    static func readLocationInfo(from url: URL) async -> String? {
        guard let coordinate = readGPSCoordinate(from: url) else {
            return nil
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                return formatPlacemark(placemark)
            }
        } catch {
            // Geocoding failed, fallback to coordinate string
            return formatCoordinate(coordinate)
        }

        return nil
    }

    static func readGPSCoordinate(from url: URL) -> CLLocationCoordinate2D? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            return nil
        }

        guard let latitude = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double,
              let latRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String,
              let longitude = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double,
              let lonRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String else {
            return nil
        }

        let lat = latRef == "S" ? -latitude : latitude
        let lon = lonRef == "W" ? -longitude : longitude
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private static func formatPlacemark(_ placemark: CLPlacemark) -> String {
        var parts: [String] = []
        if let city = placemark.locality {
            parts.append(city)
        } else if let adminArea = placemark.administrativeArea {
            parts.append(adminArea)
        }
        if let subLocality = placemark.subLocality {
            parts.append(subLocality)
        }
        return parts.isEmpty ? (placemark.name ?? "") : parts.joined(separator: " ")
    }

    private static func formatCoordinate(_ coord: CLLocationCoordinate2D) -> String {
        let latRef = coord.latitude >= 0 ? "N" : "S"
        let lonRef = coord.longitude >= 0 ? "E" : "W"
        return String(format: "%.4f\u{00B0}%@ %.4f\u{00B0}%@", abs(coord.latitude), latRef, abs(coord.longitude), lonRef)
    }

    static func generateThumbnail(from url: URL, maxSize: CGFloat = 800) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
