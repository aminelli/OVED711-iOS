
// CameraPreviewView SwiftUI + UIViewRepresentable

import SwiftUI
import AVFoundation

// MARK: - Preview Layer wrapper

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

// MARK: - ViewModel

@Observable @MainActor
final class CameraViewModel {
    var capturedImage: UIImage?
    var errorMessage: String?
    private(set) var session: AVCaptureSession?
    private let cameraSession = CameraSession()

    func setup() async {
        do {
            try await cameraSession.configure()
            session = await cameraSession.captureSession()
            await cameraSession.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func takePhoto() async {
        do {
            let data = try await cameraSession.capturePhoto()
            capturedImage = UIImage(data: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func savePhoto() async {
        guard let image = capturedImage,
              let data = image.jpegData(compressionQuality: 0.9) else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }
        } catch {
            errorMessage = "Salvataggio fallito: \(error.localizedDescription)"
        }
    }

    func tearDown() async {
        await cameraSession.stop()
    }
}

// MARK: - View principale

struct CameraView: View {
    @State private var viewModel = CameraViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            if let session = viewModel.session {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                    .overlay {
                        if let error = viewModel.errorMessage {
                            Text(error).foregroundStyle(.white)
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
            }

            if let captured = viewModel.capturedImage {
                Image(uiImage: captured)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.trailing, 24)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Button {
                Task { await viewModel.takePhoto() }
            } label: {
                Circle()
                    .fill(.white)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(.gray, lineWidth: 3))
            }
            .padding(.bottom, 40)
        }
        .task { await viewModel.setup() }
        .onDisappear { Task { await viewModel.tearDown() } }
    }
}