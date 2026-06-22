// Vision OCR in tempo reale con AVFoundation e Vision


import AVFoundation
import Vision
import SwiftUI

// MARK: - Video Data Output delegate

actor VisionCameraService: NSObject {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let visionQueue = DispatchQueue(label: "com.app.vision", qos: .userInitiated)

    // Stream di risultati testuali verso la UI
    private var resultsContinuation: AsyncStream<[String]>.Continuation?
    private(set) var resultsStream: AsyncStream<[String]>

    override init() {
        var continuation: AsyncStream<[String]>.Continuation!
        resultsStream = AsyncStream { continuation = $0 }
        resultsContinuation = continuation
        super.init()
    }

    func configure() throws {
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080

        guard let device = AVCaptureDevice.default(for: .video) else {
            throw CameraError.deviceUnavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
        session.addInput(input)

        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(videoOutput) else { throw CameraError.cannotAddOutput }
        session.addOutput(videoOutput)

        session.commitConfiguration()
    }

    func start() { visionQueue.async { self.session.startRunning() } }
    func stop() { visionQueue.async { self.session.stopRunning() } }
    func captureSession() -> AVCaptureSession { session }
}

extension VisionCameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else { return }

            let strings = observations.compactMap { $0.topCandidates(1).first?.string }
            Task { await self?.publish(results: strings) }
        }
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false

        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
            .perform([request])
    }

    private func publish(results: [String]) {
        resultsContinuation?.yield(results)
    }
}

// MARK: - ViewModel OCR

@Observable @MainActor
final class OCRViewModel {
    var recognizedLines: [String] = []
    private(set) var session: AVCaptureSession?
    private let service = VisionCameraService()

    func start() async {
        do {
            try await service.configure()
            session = await service.captureSession()
            await service.start()

            // Consuma lo stream di risultati
            Task {
                for await lines in await service.resultsStream {
                    self.recognizedLines = lines
                }
            }
        } catch {
            print("Errore OCR: \(error)")
        }
    }
}