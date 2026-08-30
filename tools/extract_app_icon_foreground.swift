import CoreImage
import CoreVideo
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

guard CommandLine.arguments.count == 3 || CommandLine.arguments.count == 5 else {
    FileHandle.standardError.write(Data(
        "usage: extract_app_icon_foreground.swift INPUT.png MERGED.png [CROWN.png LION.png]\n".utf8
    ))
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let mergedOutputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard
    let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
    let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    throw NSError(domain: "color.king.icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to read input image"])
}

let request = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(cgImage: sourceImage, orientation: .up)
try handler.perform([request])

guard let observation = request.results?.first else {
    throw NSError(domain: "color.king.icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "No foreground instance mask returned"])
}

let context = CIContext(options: [.useSoftwareRenderer: false])
let sourceCI = CIImage(cgImage: sourceImage)
let clearCI = CIImage(color: CIColor.clear).cropped(to: sourceCI.extent)

func softenedMask(forInstances instances: IndexSet) throws -> CIImage {
    let maskBuffer = try observation.generateScaledMaskForImage(
        forInstances: instances,
        from: handler
    )
    var maskCI = CIImage(cvPixelBuffer: maskBuffer)

    if maskCI.extent != sourceCI.extent {
        let scaleX = sourceCI.extent.width / maskCI.extent.width
        let scaleY = sourceCI.extent.height / maskCI.extent.height
        maskCI = maskCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }

    if let contract = CIFilter(name: "CIMorphologyMinimum") {
        contract.setValue(maskCI, forKey: kCIInputImageKey)
        contract.setValue(0.85, forKey: kCIInputRadiusKey)
        maskCI = contract.outputImage?.cropped(to: sourceCI.extent) ?? maskCI
    }

    if let soften = CIFilter(name: "CIGaussianBlur") {
        soften.setValue(maskCI, forKey: kCIInputImageKey)
        soften.setValue(0.35, forKey: kCIInputRadiusKey)
        maskCI = soften.outputImage?.cropped(to: sourceCI.extent) ?? maskCI
    }

    return maskCI
}

func writeForeground(forInstances instances: IndexSet, to outputURL: URL) throws {
    guard let blend = CIFilter(name: "CIBlendWithMask") else {
        throw NSError(domain: "color.king.icon", code: 3, userInfo: [NSLocalizedDescriptionKey: "CIBlendWithMask is unavailable"])
    }
    blend.setValue(sourceCI, forKey: kCIInputImageKey)
    blend.setValue(clearCI, forKey: kCIInputBackgroundImageKey)
    blend.setValue(try softenedMask(forInstances: instances), forKey: kCIInputMaskImageKey)

    guard
        let result = blend.outputImage?.cropped(to: sourceCI.extent),
        let outputImage = context.createCGImage(result, from: sourceCI.extent),
        let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw NSError(domain: "color.king.icon", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to render foreground image"])
    }

    CGImageDestinationAddImage(destination, outputImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "color.king.icon", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unable to write foreground PNG"])
    }
}

func verticalCentroid(forInstance instance: Int) throws -> Double {
    let maskBuffer = try observation.generateScaledMaskForImage(
        forInstances: IndexSet(integer: instance),
        from: handler
    )
    CVPixelBufferLockBaseAddress(maskBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(maskBuffer, .readOnly) }

    let width = CVPixelBufferGetWidth(maskBuffer)
    let height = CVPixelBufferGetHeight(maskBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer)
    let pixelFormat = CVPixelBufferGetPixelFormatType(maskBuffer)
    let baseAddress = CVPixelBufferGetBaseAddress(maskBuffer)!
    var weightedY = 0.0
    var total = 0.0

    if pixelFormat == kCVPixelFormatType_OneComponent32Float {
        let rowStride = bytesPerRow / MemoryLayout<Float>.size
        let pixels = baseAddress.assumingMemoryBound(to: Float.self)
        for y in 0..<height {
            for x in 0..<width {
                let value = Double(pixels[y * rowStride + x])
                weightedY += Double(y) * value
                total += value
            }
        }
    } else if pixelFormat == kCVPixelFormatType_OneComponent8 {
        let pixels = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                let value = Double(pixels[y * bytesPerRow + x]) / 255.0
                weightedY += Double(y) * value
                total += value
            }
        }
    } else {
        throw NSError(domain: "color.king.icon", code: 6, userInfo: [NSLocalizedDescriptionKey: "Unsupported Vision mask pixel format"])
    }

    guard total > 0 else {
        throw NSError(domain: "color.king.icon", code: 7, userInfo: [NSLocalizedDescriptionKey: "Empty foreground instance mask"])
    }
    return weightedY / total
}

try writeForeground(forInstances: observation.allInstances, to: mergedOutputURL)
print("foreground extracted: \(mergedOutputURL.path)")

if CommandLine.arguments.count == 5 {
    guard observation.allInstances.count == 2 else {
        throw NSError(
            domain: "color.king.icon",
            code: 8,
            userInfo: [NSLocalizedDescriptionKey: "Expected exactly two foreground instances for crown and lion"]
        )
    }

    let instancesByTopPosition = try observation.allInstances.sorted {
        try verticalCentroid(forInstance: $0) < verticalCentroid(forInstance: $1)
    }
    let crownOutputURL = URL(fileURLWithPath: CommandLine.arguments[3])
    let lionOutputURL = URL(fileURLWithPath: CommandLine.arguments[4])
    try writeForeground(forInstances: IndexSet(integer: instancesByTopPosition[0]), to: crownOutputURL)
    try writeForeground(forInstances: IndexSet(integer: instancesByTopPosition[1]), to: lionOutputURL)
    print("crown extracted: \(crownOutputURL.path)")
    print("lion extracted: \(lionOutputURL.path)")
}
