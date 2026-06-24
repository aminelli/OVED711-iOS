
// Motion Service con AsyncStream



import CoreMotion
import Foundation

// MARK: - Motion Service Actor

actor MotionService {
    private let motionManager = CMMotionManager()
    private var accelContinuation: AsyncStream<CMAccelerometerData>.Continuation?

    let accelerometerStream: AsyncStream<CMAccelerometerData>

    init() {
        var cont: AsyncStream<CMAccelerometerData>.Continuation!
        accelerometerStream = AsyncStream(bufferingPolicy: .bufferingNewest(10)) { cont = $0 }
        accelContinuation = cont
    }

    // MARK: - Accelerometro

    func startAccelerometer(interval: TimeInterval = 1.0 / 30.0) throws {
        guard CMMotionManager.shared?.isAccelerometerAvailable ?? motionManager.isAccelerometerAvailable else {
            throw MotionError.unavailable
        }
        motionManager.accelerometerUpdateInterval = interval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let data, error == nil else { return }
            Task { await self?.publish(data: data) }
        }
    }

    func stopAccelerometer() {
        motionManager.stopAccelerometerUpdates()
        accelContinuation?.finish()
    }

    private func publish(data: CMAccelerometerData) {
        accelContinuation?.yield(data)
    }

    // MARK: - Device Motion (sensor fusion)

    func startDeviceMotion(
        interval: TimeInterval = 1.0 / 60.0,
        using referenceFrame: CMAttitudeReferenceFrame = .xArbitraryZVertical
    ) throws -> AsyncStream<CMDeviceMotionData> {
        guard motionManager.isDeviceMotionAvailable else { throw MotionError.unavailable }

        var cont: AsyncStream<CMDeviceMotionData>.Continuation!
        let stream = AsyncStream<CMDeviceMotionData>(bufferingPolicy: .bufferingNewest(10)) { cont = $0 }

        motionManager.deviceMotionUpdateInterval = interval
        motionManager.startDeviceMotionUpdates(
            using: referenceFrame,
            to: .main
        ) { data, error in
            guard let data, error == nil else { return }
            cont.yield(data)
        }

        return stream
    }
}

enum MotionError: Error { case unavailable }

