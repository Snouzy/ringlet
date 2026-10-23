import AVFoundation
import CoreVideo
import Foundation
import Testing
@testable import RingletCore

/// Vidéo H.264 sans son de 1 s, 1920×1080, 10 images/s.
private func makeMovie(at url: URL) async throws {
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 1920, AVVideoHeightKey: 1080,
    ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: 1920, kCVPixelBufferHeightKey as String: 1080,
    ])
    writer.add(input)
    #expect(writer.startWriting())
    writer.startSession(atSourceTime: .zero)
    for frame in 0..<10 {
        while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, try #require(adaptor.pixelBufferPool), &buffer)
        let pixels = try #require(buffer)
        CVPixelBufferLockBaseAddress(pixels, [])
        memset(CVPixelBufferGetBaseAddress(pixels), Int32(frame * 20), CVPixelBufferGetDataSize(pixels))
        CVPixelBufferUnlockBaseAddress(pixels, [])
        adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 10))
    }
    input.markAsFinished()
    await writer.finishWriting()
    #expect(writer.status == .completed)
}

private func tempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ringlet-video-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

@Test func movBecomesMP4NextToIt() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let source = dir.appendingPathComponent("clip.mov")
    try await makeMovie(at: source)
    let result = await VideoExporter.export(source, as: .mp4)
    let output = try #require(result.output)
    #expect(output.lastPathComponent == "clip.mp4")
    let tracks = try await AVURLAsset(url: output).loadTracks(withMediaType: .video)
    #expect(tracks.count == 1)
}

@Test func reductionFitsIn720p() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let source = dir.appendingPathComponent("clip.mov")
    try await makeMovie(at: source)
    let result = await VideoExporter.export(source, as: .hd720)
    let output = try #require(result.output)
    #expect(output.lastPathComponent == "clip-720p.mp4")
    let track = try #require(try await AVURLAsset(url: output).loadTracks(withMediaType: .video).first)
    let size = try await track.load(.naturalSize)
    #expect(size.width <= 1280 && size.height <= 720)
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix(".ringlet") }
    #expect(leftovers.isEmpty)
}

@Test func silentVideoHasNoAudioToExtract() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let source = dir.appendingPathComponent("muet.mov")
    try await makeMovie(at: source)
    let result = await VideoExporter.export(source, as: .audio)
    #expect(result.output == nil)
    #expect(result.error == .noAudio)
    #expect(ResultSummary(results: [result]).text == "muet.mov has no audio")
}

@Test func unreadableVideoFails() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let source = dir.appendingPathComponent("faux.mov")
    try Data("x".utf8).write(to: source)
    #expect(await VideoExporter.export(source, as: .mp4).error == .unreadable)
}
