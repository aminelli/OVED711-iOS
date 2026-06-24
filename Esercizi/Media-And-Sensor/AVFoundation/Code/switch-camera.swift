
// Cambio fotocamera ant/post senza riavviare la sessione

func switchCamera(
        session: AVCaptureSession, 
        currentInput: AVCaptureDeviceInput
    ) throws -> AVCaptureDeviceInput {
    
    let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
    
    guard let newDevice = AVCaptureDevice.default(
        .builtInWideAngleCamera, 
        for: .video, 
        position: newPosition
    ) else {
        throw CameraError.deviceUnavailable
    }
    let newInput = try AVCaptureDeviceInput(device: newDevice)
    session.beginConfiguration()
    session.removeInput(currentInput)
    if session.canAddInput(newInput) { session.addInput(newInput) }
    session.commitConfiguration()
    return newInput
}