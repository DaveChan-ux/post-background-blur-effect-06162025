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
    @State private var selectedImageType: ImageType = .light
    @State private var currentLuminance: Double = 0.0
    @State private var currentBlurMaterialName: String = "Regular Material"

    enum ImageType: String, CaseIterable {
        case light = "light"
        case medium = "coffee"
        case dark = "dark"

        var displayName: String {
            switch self {
            case .light: return "light"
            case .medium: return "medium"
            case .dark: return "dark"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                // Bottom layer: image fills entire container (no blur)
                Image(selectedImageType.rawValue)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .onAppear {
                        updateBlurMaterial()
                    }
                    .onChange(of: selectedImageType) { _, _ in
                        updateBlurMaterial()
                    }

                // Middle layer: empty frame with dynamically selected iOS Materials Blur
                Rectangle()
                    .fill(blurMaterial)

                // Top layer: image fit to height of container (no blur)
                Image(selectedImageType.rawValue)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 300)
                    .cornerRadius(0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .cornerRadius(16)

            // Segmented control for image selection
            Picker("Image Type", selection: $selectedImageType) {
                ForEach(ImageType.allCases, id: \.self) { imageType in
                    Text(imageType.displayName)
                        .tag(imageType)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: .infinity)

            // Display blur material and luminance information
            VStack(alignment: .leading, spacing: 8) {
                Text("Blur setting = \(currentBlurMaterialName)")
                    .font(.body)
                Text("Luminance = \(String(format: "%.3f", currentLuminance))")
                    .font(.body)
            }
        }
        .padding()
    }

    private func updateBlurMaterial() {
        // Analyze the image brightness and set appropriate blur material
        if let uiImage = UIImage(named: selectedImageType.rawValue) {
            let analysisResult = ImageBrightnessAnalyzer.getBlurMaterialWithBrightnessAndName(for: uiImage)
            blurMaterial = analysisResult.material
            currentLuminance = analysisResult.brightness
            currentBlurMaterialName = analysisResult.materialName
        }
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

    /// Analyzes image brightness and returns both blur material and brightness value
    /// - Parameter image: UIImage to analyze
    /// - Returns: Tuple containing the material and brightness value
    static func getBlurMaterialWithBrightness(for image: UIImage) -> (material: Material, brightness: Double) {
        let brightness = calculateImageBrightness(image: image)
        let material = selectBlurMaterial(for: brightness)
        return (material: material, brightness: brightness)
    }

    /// Analyzes image brightness and returns blur material, brightness value, and material name
    /// - Parameter image: UIImage to analyze
    /// - Returns: Tuple containing the material, brightness value, and material name
    static func getBlurMaterialWithBrightnessAndName(for image: UIImage) -> (material: Material, brightness: Double, materialName: String) {
        let brightness = calculateImageBrightness(image: image)
        let materialInfo = selectBlurMaterialWithName(for: brightness)
        return (material: materialInfo.material, brightness: brightness, materialName: materialInfo.name)
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
            // Dark background - use ultra thin material
            return .ultraThinMaterial
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

    /// Selects appropriate blur material and name based on brightness value
    /// - Parameter brightness: Brightness value between 0.0 and 1.0
    /// - Returns: Tuple containing material and its name
    private static func selectBlurMaterialWithName(for brightness: Double) -> (material: Material, name: String) {
        switch brightness {
        case 0.0..<0.3:
            // Dark background - use ultra thin material
            return (.ultraThinMaterial, "Ultra Thin Material")
        case 0.3..<0.7:
            // Medium background - use regular material
            return (.regularMaterial, "Regular Material")
        case 0.7...1.0:
            // Light background - use thin material
            return (.thinMaterial, "Thin Material")
        default:
            // Fallback to regular material
            return (.regularMaterial, "Regular Material")
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
