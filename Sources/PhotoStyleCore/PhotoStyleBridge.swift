import Foundation
import CPhotoStyleCore

public struct ConversionOptions: Sendable {
    /// Apple Photos Photographic Styles (Rust)
    /// Included in Photographic Styles 3; turn that off to change this.
    public var applePhotographicStyles: Bool

    /// Photographic Styles 3 (texture + grain)
    /// Output carries a Standard texture_styles item so Apple Photos offers
    /// texture/grain editing; selects Apple Standard output and disables GPU encoding.
    public var applePhotographicStyles3: Bool

    /// Apple Portrait Mode (Rust)
    public var applePortrait: Bool

    /// Optional custom grain seed (defaults to hash of input path)
    public var customGrainSeed: UInt64?

    public init(
        applePhotographicStyles: Bool = false,
        applePhotographicStyles3: Bool = false,
        applePortrait: Bool = false,
        customGrainSeed: UInt64? = nil
    ) {
        self.applePhotographicStyles3 = applePhotographicStyles3
        // PS3 includes Photographic Styles 1
        self.applePhotographicStyles = applePhotographicStyles3 ? true : applePhotographicStyles
        self.applePortrait = applePortrait
        self.customGrainSeed = customGrainSeed
    }
}

public struct PhotoConversionResult: Sendable {
    public let success: Bool
    public let inputPath: String
    public let outputPath: String
    public let inputSizeBytes: Int64
    public let outputSizeBytes: Int64
    public let hasGainMap: Bool
    public let hasStyles: Bool
    public let hasStyles3: Bool
    public let hasPortrait: Bool
    public let errorMessage: String?
    public let mode: String?
    public let family: String?

    public init(
        success: Bool,
        inputPath: String,
        outputPath: String,
        inputSizeBytes: Int64 = 0,
        outputSizeBytes: Int64 = 0,
        hasGainMap: Bool = false,
        hasStyles: Bool = false,
        hasStyles3: Bool = false,
        hasPortrait: Bool = false,
        errorMessage: String? = nil,
        mode: String? = nil,
        family: String? = nil
    ) {
        self.success = success
        self.inputPath = inputPath
        self.outputPath = outputPath
        self.inputSizeBytes = inputSizeBytes
        self.outputSizeBytes = outputSizeBytes
        self.hasGainMap = hasGainMap
        self.hasStyles = hasStyles
        self.hasStyles3 = hasStyles3
        self.hasPortrait = hasPortrait
        self.errorMessage = errorMessage
        self.mode = mode
        self.family = family
    }
}

public enum PhotoStyleBridge {
    public static let appVersion: String = "1.0.2"
    public static let author: String = "@tozn607"

    public static var version: String {
        guard let cStr = xdremux_version() else { return "unknown" }
        defer { xdremux_free_string(cStr) }
        return String(cString: cStr)
    }

    public static func verifyOutput(path: String) -> Bool {
        return path.withCString { xdremux_verify_output($0) }
    }

    public static func verifyStylesOutput(path: String) -> Bool {
        return path.withCString { xdremux_verify_styles_output($0) }
    }

    public static func verifyPortraitOutput(path: String) -> Bool {
        return path.withCString { xdremux_verify_portrait_output($0) }
    }

    public static func inspect(path: String) -> (success: Bool, mode: String?, family: String?, edrScale: Double, gainMapMax: Double, error: String?) {
        let res = path.withCString { xdremux_inspect($0) }
        defer { xdremux_free_result(res) }
        let mode = res.mode != nil ? String(cString: res.mode) : nil
        let family = res.family != nil ? String(cString: res.family) : nil
        let error = res.error_message != nil ? String(cString: res.error_message) : nil
        return (res.success, mode, family, res.edr_scale, res.gain_map_max, error)
    }

    public static func grainSeed(for path: String) -> UInt64 {
        var h: UInt64 = 0
        for b in path.utf8 {
            h = (h &* 31 &+ UInt64(b)) & 0x7FFFFFFF
        }
        return h
    }

    public static func injectTextureStyles(input: String, output: String, grainSeed: UInt64) -> Bool {
        return input.withCString { inPtr in
            output.withCString { outPtr in
                xdremux_inject_texture_styles(inPtr, outPtr, grainSeed) != 0
            }
        }
    }

    public static func injectSemanticMattes(input: String, output: String) -> Bool {
        return input.withCString { inPtr in
            output.withCString { outPtr in
                xdremux_inject_semantic_mattes(inPtr, outPtr) != 0
            }
        }
    }

    public static func attachStyles(input: String, output: String, grainSeed: UInt64) -> (success: Bool, message: String) {
        guard let jsonPtr = input.withCString({ inPtr in
            output.withCString { outPtr in
                xdremux_attach_styles(inPtr, outPtr, grainSeed)
            }
        }) else {
            return (false, "Failed to call attach_styles")
        }
        defer { xdremux_free_string(jsonPtr) }
        let jsonStr = String(cString: jsonPtr)
        return (jsonStr.contains("\"status\":\"attached\"") || jsonStr.contains("\"status\":\"already-complete\""), jsonStr)
    }

    public static func convert(
        inputPath: String,
        outputPath: String,
        options: ConversionOptions
    ) -> PhotoConversionResult {
        let fileManager = FileManager.default
        let inAttrs = try? fileManager.attributesOfItem(atPath: inputPath)
        let inSize = (inAttrs?[.size] as? NSNumber)?.int64Value ?? 0

        // If PS3 is requested, effectiveStyles is always true
        let effectiveStyles = options.applePhotographicStyles || options.applePhotographicStyles3
        let effectivePortrait = options.applePortrait

        var config = ConvertConfig(
            oppo_compat: 0, // Apple Standard output
            oppo_camera_tail: 0, // No Oppo private tail
            strict_tmap: 0,
            apple_photographic_styles: effectiveStyles ? 1 : 0,
            apple_portrait: effectivePortrait ? 1 : 0
        )

        // Ensure parent directory exists for output
        let outURL = URL(fileURLWithPath: outputPath)
        try? fileManager.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let result = inputPath.withCString { inPtr in
            outputPath.withCString { outPtr in
                xdremux_convert(inPtr, outPtr, &config)
            }
        }
        defer { xdremux_free_result(result) }

        guard result.success else {
            let errorMsg = result.error_message != nil ? String(cString: result.error_message) : "Unknown conversion failure"
            return PhotoConversionResult(
                success: false,
                inputPath: inputPath,
                outputPath: outputPath,
                inputSizeBytes: inSize,
                errorMessage: errorMsg
            )
        }

        // Verify primary conversion output
        if effectiveStyles && !verifyStylesOutput(path: outputPath) {
            return PhotoConversionResult(
                success: false,
                inputPath: inputPath,
                outputPath: outputPath,
                inputSizeBytes: inSize,
                errorMessage: "Output is missing Apple Photographic Styles data"
            )
        }

        if effectivePortrait && !verifyPortraitOutput(path: outputPath) {
            return PhotoConversionResult(
                success: false,
                inputPath: inputPath,
                outputPath: outputPath,
                inputSizeBytes: inSize,
                errorMessage: "Output is missing Apple Portrait data"
            )
        }

        var styles3Success = false
        if options.applePhotographicStyles3 {
            let seed = options.customGrainSeed ?? grainSeed(for: inputPath)
            let injectedTexture = injectTextureStyles(input: outputPath, output: outputPath, grainSeed: seed)
            guard injectedTexture else {
                return PhotoConversionResult(
                    success: false,
                    inputPath: inputPath,
                    outputPath: outputPath,
                    inputSizeBytes: inSize,
                    errorMessage: "PS3 texture_styles injection failed"
                )
            }
            let injectedMattes = injectSemanticMattes(input: outputPath, output: outputPath)
            guard injectedMattes else {
                return PhotoConversionResult(
                    success: false,
                    inputPath: inputPath,
                    outputPath: outputPath,
                    inputSizeBytes: inSize,
                    errorMessage: "PS3 semantic mattes injection failed"
                )
            }
            styles3Success = true
        }

        let outAttrs = try? fileManager.attributesOfItem(atPath: outputPath)
        let outSize = (outAttrs?[.size] as? NSNumber)?.int64Value ?? 0
        let hasGainMap = verifyOutput(path: outputPath)
        let hasStyles = verifyStylesOutput(path: outputPath)
        let hasPortrait = verifyPortraitOutput(path: outputPath)
        let mode = result.mode != nil ? String(cString: result.mode) : nil
        let family = result.family != nil ? String(cString: result.family) : nil

        return PhotoConversionResult(
            success: true,
            inputPath: inputPath,
            outputPath: outputPath,
            inputSizeBytes: inSize,
            outputSizeBytes: outSize,
            hasGainMap: hasGainMap,
            hasStyles: hasStyles,
            hasStyles3: styles3Success,
            hasPortrait: hasPortrait,
            mode: mode,
            family: family
        )
    }
}
