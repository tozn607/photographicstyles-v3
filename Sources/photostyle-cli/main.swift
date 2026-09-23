import Foundation
import PhotoStyleCore
#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import ImageIO

@discardableResult
func generateSyntheticImage(url: URL, format: String, width: Int = 800, height: Int = 600) -> Bool {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil,
              width: width,
              height: height,
              bitsPerComponent: 8,
              bytesPerRow: width * 4,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
        return false
    }
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.7, alpha: 1.0))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(CGColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1.0))
    context.fillEllipse(in: CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))

    guard let cgImage = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, format as CFString, 1, nil) else {
        return false
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    return CGImageDestinationFinalize(destination)
}
#endif

func printUsage() {
    print("""
    PhotoStyle CLI - Enable Apple Photographic Styles and Portrait Mode on imported pictures

    Usage:
      photostyle <input-image> [-o <output-heic>] [options]
      photostyle --inspect <image-path>
      photostyle --test
      photostyle --version

    Apple Photos Features (Experimental):
      --styles       Apple Photos Photographic Styles (Rust)
                     Generates editable Photographic Styles graph (tone/color/palette)
      --ps3          Photographic Styles 3 (texture + grain)
                     Injects Standard texture_styles metadata + 12 semantic part mattes.
                     Automatically includes and enables --styles.
      --portrait     Apple Portrait Mode (Rust)
                     Generates editable Apple Portrait depth & disparity graph

    Options:
      -o, --output <path>    Output HEIC file path (default: <input-stem>_photostyle.heic)
      --grain-seed <seed>    Custom film grain seed (uint64, default: auto from path)
      --inspect <path>       Inspect ISOBMFF metadata and Apple Photos feature items
      --test                 Run automated self-tests and validation suite
      -h, --help             Show this help information
      -v, --version          Print PhotoStyle version
    """)
}

func runTestSuite() {
    print("========================================")
    print("Running PhotoStyle Self-Test Suite")
    print("========================================")
    var passCount = 0
    var totalCount = 0

    func assertTest(_ name: String, _ condition: Bool, _ details: String = "") {
        totalCount += 1
        if condition {
            passCount += 1
            print("  ✓ PASS: \(name)")
        } else {
            print("  ✗ FAIL: \(name) - \(details)")
        }
    }

    // Test 1: Version and author check
    assertTest("Core library version check", PhotoStyleBridge.version == "0.4.2", "Got: \(PhotoStyleBridge.version)")
    assertTest("App version check", PhotoStyleBridge.appVersion == "1.0.1", "Got: \(PhotoStyleBridge.appVersion)")
    assertTest("Author check", PhotoStyleBridge.author == "@tozn607", "Got: \(PhotoStyleBridge.author)")

    // Test 2: Deterministic grain seed hash
    let seed1 = PhotoStyleBridge.grainSeed(for: "/test/image1.jpg")
    let seed2 = PhotoStyleBridge.grainSeed(for: "/test/image1.jpg")
    let seed3 = PhotoStyleBridge.grainSeed(for: "/test/image2.jpg")
    assertTest("Deterministic grain seed generation", seed1 == seed2 && seed1 != seed3)

    // Test 3: Prepare test inputs
    let fm = FileManager.default
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("photostyle_tests")
    try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let testJpgUrl = tempDir.appendingPathComponent("test_sdr.jpg")
    let testPngUrl = tempDir.appendingPathComponent("test_sdr.png")
    let testJpg = testJpgUrl.path
    let testPng = testPngUrl.path

    // Ensure clean synthetic test images with width & height > 512 (required for delta tiles)
    try? fm.removeItem(at: testJpgUrl)
    try? fm.removeItem(at: testPngUrl)
    generateSyntheticImage(url: testJpgUrl, format: "public.jpeg", width: 800, height: 600)
    generateSyntheticImage(url: testPngUrl, format: "public.png", width: 800, height: 600)

    // Test 4: Convert JPEG with PS3
    let ps3OutputJpg = tempDir.appendingPathComponent("test_ps3.heic").path
    let ps3Options = ConversionOptions(applePhotographicStyles3: true)
    let resJpg = PhotoStyleBridge.convert(inputPath: testJpg, outputPath: ps3OutputJpg, options: ps3Options)

    assertTest("JPEG Conversion with PS3 succeeds", resJpg.success, resJpg.errorMessage ?? "")
    assertTest("JPEG Output verified for Photographic Styles", resJpg.hasStyles)
    assertTest("JPEG Output verified for PS3 texture + grain", resJpg.hasStyles3)

    if let data = try? Data(contentsOf: URL(fileURLWithPath: ps3OutputJpg)) {
        let hasTexture = data.range(of: Data("texture_styles".utf8)) != nil
        let hasStyles = data.range(of: Data("styledeltamap".utf8)) != nil
        let hasNoseMatte = data.range(of: Data("semanticnosematte".utf8)) != nil
        assertTest("Output carries texture_styles metadata URI", hasTexture)
        assertTest("Output carries styledeltamap auxiliary grid", hasStyles)
        assertTest("Output carries 12 semantic part mattes", hasNoseMatte)
    }

    // Test 5: Convert PNG with PS3
    let ps3OutputPng = tempDir.appendingPathComponent("test_png_ps3.heic").path
    let resPng = PhotoStyleBridge.convert(inputPath: testPng, outputPath: ps3OutputPng, options: ps3Options)
    assertTest("PNG Conversion with PS3 succeeds", resPng.success, resPng.errorMessage ?? "")
    assertTest("PNG Output carries Photographic Styles", resPng.hasStyles)
    assertTest("PNG Output carries PS3", resPng.hasStyles3)

    // Test 6: Convert JPEG with Styles 1 only (no PS3)
    let styles1Output = tempDir.appendingPathComponent("test_styles1.heic").path
    let styles1Options = ConversionOptions(applePhotographicStyles: true, applePhotographicStyles3: false)
    let resStyles1 = PhotoStyleBridge.convert(inputPath: testJpg, outputPath: styles1Output, options: styles1Options)
    assertTest("JPEG Conversion with Styles 1 succeeds", resStyles1.success, resStyles1.errorMessage ?? "")
    assertTest("Styles 1 Output verified for Styles", resStyles1.hasStyles)
    assertTest("Styles 1 Output does NOT carry PS3", !resStyles1.hasStyles3)

    if let data = try? Data(contentsOf: URL(fileURLWithPath: styles1Output)) {
        let hasTexture = data.range(of: Data("texture_styles".utf8)) != nil
        let hasStyles = data.range(of: Data("styledeltamap".utf8)) != nil
        assertTest("Styles 1 output carries styledeltamap", hasStyles)
        assertTest("Styles 1 output omits texture_styles", !hasTexture)
    }

    print("========================================")
    print("Test Results: \(passCount)/\(totalCount) passed.")
    print("========================================")
    exit(passCount == totalCount ? 0 : 1)
}

let args = CommandLine.arguments

if args.count <= 1 || args.contains("-h") || args.contains("--help") {
    printUsage()
    exit(0)
}

if args.contains("-v") || args.contains("--version") {
    print("PhotoStyle v\(PhotoStyleBridge.appVersion) • Author: \(PhotoStyleBridge.author) (Core \(PhotoStyleBridge.version))")
    exit(0)
}

if args.contains("--test") {
    runTestSuite()
}

if let inspectIndex = args.firstIndex(of: "--inspect"), inspectIndex + 1 < args.count {
    let inspectPath = args[inspectIndex + 1]
    let info = PhotoStyleBridge.inspect(path: inspectPath)
    if info.success {
        print("ISOBMFF Inspection for \(inspectPath):")
        print("  Mode: \(info.mode ?? "None")")
        print("  Family: \(info.family ?? "None")")
        print("  EDR Scale: \(info.edrScale)")
        print("  Gain Map Max: \(info.gainMapMax)")
    } else {
        print("Inspection notice: \(info.error ?? "No ProXDR/gain map container detected")")
    }
    let gm = PhotoStyleBridge.verifyOutput(path: inspectPath)
    let styles = PhotoStyleBridge.verifyStylesOutput(path: inspectPath)
    let portrait = PhotoStyleBridge.verifyPortraitOutput(path: inspectPath)
    print("\nFeature Summary:")
    print("  ISO Gain Map (HDR): \(gm ? "YES" : "NO")")
    print("  Apple Photographic Styles: \(styles ? "YES" : "NO")")
    print("  Apple Portrait Mode: \(portrait ? "YES" : "NO")")
    exit(0)
}

// Parse conversion arguments
var inputPath: String?
var outputPath: String?
var enableStyles = false
var enablePS3 = false
var enablePortrait = false
var customGrainSeed: UInt64?

var i = 1
while i < args.count {
    let arg = args[i]
    switch arg {
    case "--styles":
        enableStyles = true
    case "--ps3":
        enablePS3 = true
    case "--portrait":
        enablePortrait = true
    case "-o", "--output":
        if i + 1 < args.count {
            outputPath = args[i + 1]
            i += 1
        }
    case "--grain-seed":
        if i + 1 < args.count, let seed = UInt64(args[i + 1]) {
            customGrainSeed = seed
            i += 1
        }
    default:
        if !arg.starts(with: "-") && inputPath == nil {
            inputPath = arg
        }
    }
    i += 1
}

guard let input = inputPath else {
    print("Error: No input file specified.")
    printUsage()
    exit(1)
}

if !FileManager.default.fileExists(atPath: input) {
    print("Error: Input file does not exist at '\(input)'")
    exit(1)
}

// Default output path if not specified
let resolvedOutput: String
if let out = outputPath {
    resolvedOutput = out
} else {
    let inputURL = URL(fileURLWithPath: input)
    let baseName = inputURL.deletingPathExtension().lastPathComponent
    let parentDir = inputURL.deletingLastPathComponent().path
    resolvedOutput = (parentDir as NSString).appendingPathComponent("\(baseName)_photostyle.heic")
}

// Default to PS3 if no options specified
if !enableStyles && !enablePS3 && !enablePortrait {
    print("No features explicitly specified. Defaulting to Photographic Styles 3 (--ps3).")
    enablePS3 = true
}

let options = ConversionOptions(
    applePhotographicStyles: enableStyles,
    applePhotographicStyles3: enablePS3,
    applePortrait: enablePortrait,
    customGrainSeed: customGrainSeed
)

print("Converting: \(input)")
print("Output:     \(resolvedOutput)")
print("Features:")
print("  • Apple Photographic Styles: \(options.applePhotographicStyles ? "Enabled" : "Disabled")")
print("  • Photographic Styles 3 (Texture + Grain): \(options.applePhotographicStyles3 ? "Enabled" : "Disabled")")
print("  • Apple Portrait Mode: \(options.applePortrait ? "Enabled" : "Disabled")")
if let seed = options.customGrainSeed {
    print("  • Custom Grain Seed: \(seed)")
}

let startTime = CFAbsoluteTimeGetCurrent()
let result = PhotoStyleBridge.convert(inputPath: input, outputPath: resolvedOutput, options: options)
let elapsed = CFAbsoluteTimeGetCurrent() - startTime

if result.success {
    print("\n Conversion Succeeded in \(String(format: "%.2f", elapsed))s!")
    print("Input Size:  \(ByteCountFormatter.string(fromByteCount: result.inputSizeBytes, countStyle: .file))")
    print("Output Size: \(ByteCountFormatter.string(fromByteCount: result.outputSizeBytes, countStyle: .file))")
    print("Verified Features in Output:")
    print("  - ISO Gain Map: \(result.hasGainMap ? "✓ Present" : "✗ None")")
    print("  - Photographic Styles: \(result.hasStyles ? "✓ Present (Editable in Apple Photos)" : "✗ None")")
    print("  - Photographic Styles 3: \(result.hasStyles3 ? "✓ Present (Texture & Grain)" : "✗ None")")
    print("  - Portrait Mode: \(result.hasPortrait ? "✓ Present (Editable Aperture & Depth)" : "✗ None")")
    print("\nThe output photo carries editable metadata and is ready for Apple Photos!")
    exit(0)
} else {
    print("\n❌ Conversion Failed:")
    print("Error: \(result.errorMessage ?? "Unknown error")")
    exit(1)
}
