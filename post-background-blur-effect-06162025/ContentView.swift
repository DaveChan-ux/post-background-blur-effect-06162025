//
//  ContentView.swift
//  Blur bg effect on post image
//
//  Created by Dave Chan on 6/15/25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var blurMaterial: Material = .regularMaterial

    var body: some View {
        ZStack {
            // Bottom layer: image fills entire container (no blur)
            Image("light")
                .resizable()
                .scaledToFill()
                .clipped()
                .onAppear {
                    // Analyze the image brightness and set appropriate blur material
                    if let uiImage = UIImage(named: "light") {
                        blurMaterial = ImageBrightnessAnalyzer.getBlurMaterial(for: uiImage)
                    }
                }

            // Middle layer: empty frame with dynamically selected iOS Materials Blur
            Rectangle()
                .fill(blurMaterial)

            // Top layer: image fit to height of container (no blur)
            Image("light")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 300)
                .cornerRadius(0)
        }
        .frame(width: 300, height: 300)
        .cornerRadius(16)
        .padding()
    }
}

// MARK: - Image Brightness Analyzer
struct ImageBrightnessAnalyzer {

    /// Analyzes image brightness and returns appropriate blur material
    /// - Parameter image: UIImage to analyze
    /// - Returns: Material based on brightness analysis
    static func getBlurMaterial(for image: UIImage) -> Material {
        let brightness = calculateImageBrightness(image: image)
        return selectBlurMaterial(for: brightness)
    }

    /// Calculates the average brightness of an image
    /// - Parameter image: UIImage to analyze
    /// - Returns: Brightness value between 0.0 (dark) and 1.0 (light)
    private static func calculateImageBrightness(image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.5 }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        let pixelData = UnsafeMutablePointer<UInt8>.allocate(capacity: height * bytesPerRow)
        defer { pixelData.deallocate() }

        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return 0.5 // Default to medium brightness if analysis fails
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalBrightness: Double = 0
        let totalPixels = width * height

        // Sample every nth pixel for performance (adjust sampleRate for accuracy vs performance)
        let sampleRate = max(1, totalPixels / 10000) // Sample roughly 10k pixels max
        var sampledPixels = 0

        for y in stride(from: 0, to: height, by: sampleRate) {
            for x in stride(from: 0, to: width, by: sampleRate) {
                let pixelIndex = ((width * y) + x) * bytesPerPixel

                if pixelIndex + 2 < height * bytesPerRow {
                    let red = Double(pixelData[pixelIndex]) / 255.0
                    let green = Double(pixelData[pixelIndex + 1]) / 255.0
                    let blue = Double(pixelData[pixelIndex + 2]) / 255.0

                    // Calculate luminance using standard formula
                    let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
                    totalBrightness += luminance
                    sampledPixels += 1
                }
            }
        }

        return sampledPixels > 0 ? totalBrightness / Double(sampledPixels) : 0.5
    }

    /// Selects appropriate blur material based on brightness value
    /// - Parameter brightness: Brightness value between 0.0 and 1.0
    /// - Returns: Material appropriate for the brightness level
    private static func selectBlurMaterial(for brightness: Double) -> Material {
        switch brightness {
        case 0.0..<0.3:
            // Dark background - use regular material
            return .regularMaterial
        case 0.3..<0.7:
            // Medium background - use regular material
            return .regularMaterial
        case 0.7...1.0:
            // Light background - use thin material
            return .thinMaterial
        default:
            // Fallback to regular material
            return .regularMaterial
        }
    }

    /// Alternative method using simpler HSB analysis
    /// - Parameter image: UIImage to analyze
    /// - Returns: Material based on HSB brightness analysis
    static func getBlurMaterialUsingHSB(for image: UIImage) -> Material {
        guard let cgImage = image.cgImage else { return .regularMaterial }

        let width = min(cgImage.width, 100) // Limit size for performance
        let height = min(cgImage.height, 100)

        guard let resizedImage = resizeImage(image: image, to: CGSize(width: width, height: height)),
              let cgResizedImage = resizedImage.cgImage else {
            return .regularMaterial
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width

        let pixelData = UnsafeMutablePointer<UInt8>.allocate(capacity: height * bytesPerRow)
        defer { pixelData.deallocate() }

        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return .regularMaterial
        }

        context.draw(cgResizedImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalBrightness: Double = 0
        let totalPixels = width * height

        for i in 0..<totalPixels {
            let pixelIndex = i * bytesPerPixel
            let red = Double(pixelData[pixelIndex]) / 255.0
            let green = Double(pixelData[pixelIndex + 1]) / 255.0
            let blue = Double(pixelData[pixelIndex + 2]) / 255.0

            // Convert to HSB and get brightness
            let color = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
            var brightness: CGFloat = 0
            color.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)

            totalBrightness += Double(brightness)
        }

        let averageBrightness = totalBrightness / Double(totalPixels)
        return selectBlurMaterial(for: averageBrightness)
    }

    /// Helper method to resize image for faster processing
    /// - Parameters:
    ///   - image: Original UIImage
    ///   - size: Target size
    /// - Returns: Resized UIImage
    private static func resizeImage(image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
