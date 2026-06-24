
// CameraSession actor con preview e scatto foto

import AVFoundation
import SwiftUI
import Photos

// MARK: - Camera Session Actor

actor CameraSession {
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.app.camera.session", qos: .userInitiated)

    var isRunning: Bool { session.isRunning }

    // MARK: - Setup

    func configure() throws {
        guard await requestCameraPermission() else {
            throw CameraError.permissionDenied
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // Input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video,
                                                    position: .back) else {
            session.commitConfiguration()
            throw CameraError.deviceUnavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.cannotAddInput
        }
        session.addInput(input)

        // Output
        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            throw CameraError.cannotAddOutput
        }
        session.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = true

        session.commitConfiguration()
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            Task { await self.startSession() }
        }
    }

    private func startSession() {
        guard !session.isRunning else { return }
        session.startRunning()
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            Task { await self.stopSession() }
        }
    }

    private func stopSession() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    func captureSession() -> AVCaptureSession { session }

    // MARK: - Foto

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let settings = AVCapturePhotoSettings()
            settings.isHighResolutionPhotoEnabled = true

            let delegate = PhotoCaptureDelegate { result in
                continuation.resume(with: result)
            }
            photoOutput.capturePhoto(with: settings, delegate: delegate)
            // Mantieni il delegate vivo durante la cattura
            Task { _ = delegate }
        }
    }

    // MARK: - Permessi

    private func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }
}

// MARK: - Photo Capture Delegate

final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Result<Data, Error>) -> Void

    init(completion: @Sendable @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error { completion(.failure(error)); return }
        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(CameraError.noData))
            return
        }
        completion(.success(data))
    }
}

// MARK: - Errori

enum CameraError: Error, LocalizedError {
    case permissionDenied
    case deviceUnavailable
    case cannotAddInput
    case cannotAddOutput
    case noData

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Accesso alla camera negato"
        case .deviceUnavailable: return "Camera non disponibile"
        case .cannotAddInput: return "Impossibile aggiungere l'input alla sessione"
        case .cannotAddOutput: return "Impossibile aggiungere l'output alla sessione"
        case .noData: return "Nessun dato dalla foto"
        }
    }
}