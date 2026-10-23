@preconcurrency import AVFoundation
import Foundation

/// Exports vidéo par AVFoundation, à côté de la source : MP4, réduction 720p, ou piste audio seule en M4A.
public enum VideoExporter {
    public enum Preset: Sendable {
        case mp4, hd720, audio

        var sessionPreset: String {
            switch self {
            case .mp4: AVAssetExportPresetHighestQuality
            case .hd720: AVAssetExportPreset1280x720
            case .audio: AVAssetExportPresetAppleM4A
            }
        }
        var fileType: AVFileType { self == .audio ? .m4a : .mp4 }
        var fileExtension: String { self == .audio ? "m4a" : "mp4" }
        var suffix: String { self == .hd720 ? "-720p" : "" }
    }

    public static func export(_ source: URL, as preset: Preset) async -> ConversionResult {
        func failure(_ error: ConversionError) -> ConversionResult { ConversionResult(source: source, output: nil, error: error) }
        let asset = AVURLAsset(url: source)
        guard let tracks = try? await asset.load(.tracks), !tracks.isEmpty else { return failure(.unreadable) }
        if preset == .audio, !tracks.contains(where: { $0.mediaType == .audio }) { return failure(.noAudio) }
        guard let session = AVAssetExportSession(asset: asset, presetName: preset.sessionPreset) else {
            return failure(.unreadable)
        }
        let output = OutputNaming.destination(for: source, fileExtension: preset.fileExtension, suffix: preset.suffix)
        let temporary = OutputNaming.temporary(beside: output)
        session.outputURL = temporary
        session.outputFileType = preset.fileType
        session.shouldOptimizeForNetworkUse = true
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { done.resume() }
        }
        guard session.status == .completed else {
            try? FileManager.default.removeItem(at: temporary)
            return failure(.writeFailed)
        }
        do throws(ConversionError) {
            try OutputNaming.commit(temporary, to: output)
        } catch {
            return failure(error)
        }
        return ConversionResult(source: source, output: output, error: nil)
    }

    /// Un fichier après l'autre : un export vidéo occupe déjà tout l'encodeur matériel.
    public static func exportAll(_ sources: [URL], as preset: Preset) async -> [ConversionResult] {
        var results: [ConversionResult] = []
        for source in sources { results.append(await export(source, as: preset)) }
        return results
    }
}
