// Adapted from github.com/samhenrigold/LidAngleSensor
import IOKit
import QuartzCore

@Observable
final class LidSensor {
    private(set) var angle = 120.0
    private(set) var velocity = 0.0
    private(set) var signedVelocity = 0.0   // + when opening (angle increasing), − when closing
    private(set) var smoothAngle = 120.0    // low-pass angle for smooth visuals
    private(set) var isAvailable = false
    private(set) var statusMessage = "Initializing…"

    @ObservationIgnored private var diagnostic: LASDiagnostic?
    @ObservationIgnored nonisolated(unsafe) private var hidDevice: IOHIDDevice?
    @ObservationIgnored nonisolated(unsafe) private var isDeviceOpen = false
    @ObservationIgnored nonisolated(unsafe) private var timer: Timer?
    @ObservationIgnored private var hidReport = [UInt8](repeating: 0, count: 8)
    @ObservationIgnored private var lastAngle = 0.0
    @ObservationIgnored private var smoothedAngle = 0.0
    @ObservationIgnored private var smoothedVelocity = 0.0
    @ObservationIgnored private var smoothedSignedVelocity = 0.0
    @ObservationIgnored private var lastUpdateTime: TimeInterval = 0
    @ObservationIgnored private var lastMovementTime: TimeInterval = 0
    @ObservationIgnored private var isFirstUpdate = true

    nonisolated private static let noOptions = IOOptionBits(kIOHIDOptionsTypeNone)
    private static let angleSmoothingFactor = 0.25
    private static let velocitySmoothingFactor = 0.3
    private static let movementThreshold = 0.2
    private static let movementTimeout: TimeInterval = 0.15  // tolerance before extra decay
    private static let velocityDecay = 0.982                 // ~1.2s half-life at 30fps
    private static let additionalDecay = 0.992               // gentle extra decay

    init() {
        let diag = LASDiagnostic.run()
        diagnostic = diag
        statusMessage = diag.statusMessage
        if case .foundStandard(let device) = diag.probeResult {
            hidDevice = device
            isAvailable = true
        }
    }

    deinit {
        timer?.invalidate()
        timer = nil
        if isDeviceOpen, let device = hidDevice {
            IOHIDDeviceClose(device, Self.noOptions)
        }
    }

    func start() {
        guard isAvailable, timer == nil, let device = hidDevice else { return }
        guard IOHIDDeviceOpen(device, Self.noOptions) == kIOReturnSuccess else { return }
        isDeviceOpen = true
        timer = .scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if isDeviceOpen, let device = hidDevice {
            IOHIDDeviceClose(device, Self.noOptions)
            isDeviceOpen = false
        }
    }

    private func poll() {
        guard let device = hidDevice else { return }
        var length = CFIndex(hidReport.count)
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &hidReport, &length)
        guard result == kIOReturnSuccess, length >= 3 else { return }
        let rawValue = UInt16(hidReport[2]) << 8 | UInt16(hidReport[1])
        updateVelocity(from: Double(rawValue))
        angle = Double(rawValue)
    }

    private func updateVelocity(from rawAngle: Double) {
        let now = CACurrentMediaTime()
        guard !isFirstUpdate else {
            lastAngle = rawAngle; smoothedAngle = rawAngle
            lastUpdateTime = now; lastMovementTime = now
            isFirstUpdate = false
            return
        }
        let dt = now - lastUpdateTime
        guard dt > 0, dt < 1.0 else { lastUpdateTime = now; return }

        smoothedAngle = Self.angleSmoothingFactor * rawAngle + (1 - Self.angleSmoothingFactor) * smoothedAngle
        let delta = smoothedAngle - lastAngle

        let instantVelocity: Double
        let signedInstant: Double
        if abs(delta) < Self.movementThreshold {
            instantVelocity = 0
            signedInstant = 0
        } else {
            instantVelocity = abs(delta / dt)
            signedInstant = delta / dt
            lastAngle = smoothedAngle
        }

        if instantVelocity > 0 {
            smoothedVelocity = Self.velocitySmoothingFactor * instantVelocity
                + (1 - Self.velocitySmoothingFactor) * smoothedVelocity
            smoothedSignedVelocity = Self.velocitySmoothingFactor * signedInstant
                + (1 - Self.velocitySmoothingFactor) * smoothedSignedVelocity
            lastMovementTime = now
        } else {
            smoothedVelocity *= Self.velocityDecay
            smoothedSignedVelocity *= Self.velocityDecay
        }
        if now - lastMovementTime > Self.movementTimeout {
            smoothedVelocity *= Self.additionalDecay
            smoothedSignedVelocity *= Self.additionalDecay
        }

        lastUpdateTime = now
        velocity = smoothedVelocity
        signedVelocity = smoothedSignedVelocity
        smoothAngle = smoothedAngle
    }
}
