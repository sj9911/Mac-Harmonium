// Adapted from github.com/samhenrigold/LidAngleSensor
import Foundation
import IOKit.hid

enum LASHardwareSupport: Equatable, CustomStringConvertible {
    case supported(model: String)
    case unsupported(reason: String)
    case unknown(modelIdentifier: String)

    var description: String {
        switch self {
        case .supported(let m): "supported (\(m))"
        case .unsupported(let r): "unsupported (\(r))"
        case .unknown(let id): "unknown (\(id))"
        }
    }
}

enum LASSensorProbeResult: CustomStringConvertible {
    case foundStandard(device: IOHIDDevice)
    case foundVendorSpecific
    case notFound

    var description: String {
        switch self {
        case .foundStandard: "found (standard UsagePage 0x0020)"
        case .foundVendorSpecific: "found (vendor-specific UsagePage 0xFF00)"
        case .notFound: "not found"
        }
    }
}

struct MacModelInfo {
    let identifier: String

    static func current() -> MacModelInfo {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [UInt8](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let identifier = String(decoding: model.prefix(while: { $0 != 0 }), as: UTF8.self)
        return MacModelInfo(identifier: identifier)
    }

    func hardwareSupport() -> LASHardwareSupport {
        if let name = Self.supportedModels[identifier] {
            return .supported(model: name)
        }
        if let reason = Self.unsupportedReason(for: identifier) {
            return .unsupported(reason: reason)
        }
        return .unknown(modelIdentifier: identifier)
    }

    private static let supportedModels: [String: String] = {
        var m: [String: String] = [:]
        m["MacBookPro16,1"] = "MacBook Pro (16-inch, 2019)"
        m["MacBookPro16,4"] = "MacBook Pro (16-inch, 2019)"
        m["MacBookPro18,3"] = "MacBook Pro (14-inch, 2021)"
        m["MacBookPro18,4"] = "MacBook Pro (14-inch, 2021)"
        m["MacBookPro18,1"] = "MacBook Pro (16-inch, 2021)"
        m["MacBookPro18,2"] = "MacBook Pro (16-inch, 2021)"
        m["Mac14,9"]  = "MacBook Pro (14-inch, 2023)"
        m["Mac14,5"]  = "MacBook Pro (14-inch, 2023)"
        m["Mac14,10"] = "MacBook Pro (16-inch, 2023)"
        m["Mac14,6"]  = "MacBook Pro (16-inch, 2023)"
        m["Mac15,3"]  = "MacBook Pro (14-inch, M3, Nov 2023)"
        m["Mac15,6"]  = "MacBook Pro (14-inch, M3 Pro, Nov 2023)"
        m["Mac15,8"]  = "MacBook Pro (14-inch, M3 Max, Nov 2023)"
        m["Mac15,7"]  = "MacBook Pro (16-inch, M3 Pro, Nov 2023)"
        m["Mac15,9"]  = "MacBook Pro (16-inch, M3 Max, Nov 2023)"
        m["Mac15,11"] = "MacBook Pro (16-inch, M3 Max, Nov 2023)"
        m["Mac16,1"]  = "MacBook Pro (14-inch, M4, 2024)"
        m["Mac16,6"]  = "MacBook Pro (14-inch, M4 Pro, 2024)"
        m["Mac16,8"]  = "MacBook Pro (14-inch, M4 Max, 2024)"
        m["Mac16,5"]  = "MacBook Pro (16-inch, M4 Pro, 2024)"
        m["Mac16,7"]  = "MacBook Pro (16-inch, M4 Pro, 2024)"
        m["Mac16,9"]  = "MacBook Pro (16-inch, M4 Max, 2024)"
        m["Mac16,10"] = "MacBook Pro (16-inch, M4 Max, 2024)"
        m["Mac14,2"]  = "MacBook Air (M2, 2022)"
        m["Mac14,15"] = "MacBook Air (15-inch, M2, 2023)"
        m["Mac16,12"] = "MacBook Air (13-inch, M4, 2025)"
        m["Mac16,13"] = "MacBook Air (15-inch, M4, 2025)"
        return m
    }()

    private static func unsupportedReason(for id: String) -> String? {
        let desktopPrefixes = ["Macmini", "MacPro", "iMac"]
        if desktopPrefixes.contains(where: { id.hasPrefix($0) }) {
            return "Desktop Macs do not have a lid angle sensor."
        }
        let studioIDs: Set = ["Mac13,1", "Mac13,2", "Mac14,13", "Mac14,14"]
        if studioIDs.contains(id) { return "Mac Studio does not have a lid angle sensor." }
        let desktopMac16: Set = ["Mac16,2", "Mac16,3", "Mac16,4", "Mac16,11"]
        if desktopMac16.contains(id) { return "Desktop Macs do not have a lid angle sensor." }
        let mbp13: Set = ["MacBookPro17,1", "Mac14,7", "MacBookPro15,2", "MacBookPro15,4", "MacBookPro16,2", "MacBookPro16,3"]
        if mbp13.contains(id) { return "The 13-inch MacBook Pro does not have a lid angle sensor." }
        let oldPrefixes = ["MacBookPro15,1", "MacBookPro15,3", "MacBookPro14,", "MacBookPro13,", "MacBookPro12,", "MacBookPro11,", "MacBookPro10,"]
        if oldPrefixes.contains(where: { id.hasPrefix($0) || id == $0 }) {
            return "This MacBook Pro predates the lid angle sensor (introduced 2019, 16-inch)."
        }
        if id.hasPrefix("MacBookAir") { return "Only MacBook Air M2 (2022) and later have a lid angle sensor." }
        if id.hasPrefix("MacBook") && !id.hasPrefix("MacBookPro") && !id.hasPrefix("MacBookAir") {
            return "The 12-inch MacBook does not have a lid angle sensor."
        }
        return nil
    }
}

extension MacModelInfo {
    private static let noOptions = IOOptionBits(kIOHIDOptionsTypeNone)

    static func probeSensor() -> LASSensorProbeResult {
        if let device = findHIDDevice(usagePage: 0x0020, usage: 0x008A) {
            return .foundStandard(device: device)
        }
        if deviceExistsWithProductID(0x8104) {
            return .foundVendorSpecific
        }
        return .notFound
    }

    private static func findHIDDevice(usagePage: Int, usage: Int) -> IOHIDDevice? {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, noOptions)
        guard IOHIDManagerOpen(manager, noOptions) == kIOReturnSuccess else { return nil }
        defer { IOHIDManagerClose(manager, noOptions) }

        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x05AC,
            kIOHIDProductIDKey as String: 0x8104,
            "UsagePage": usagePage,
            "Usage": usage,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              !devices.isEmpty else { return nil }

        for device in devices {
            guard IOHIDDeviceOpen(device, noOptions) == kIOReturnSuccess else { continue }
            defer { IOHIDDeviceClose(device, noOptions) }
            var report = [UInt8](repeating: 0, count: 8)
            var length = CFIndex(report.count)
            if IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length) == kIOReturnSuccess,
               length >= 3 {
                return device
            }
        }
        return nil
    }

    private static func deviceExistsWithProductID(_ productID: Int) -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, noOptions)
        guard IOHIDManagerOpen(manager, noOptions) == kIOReturnSuccess else { return false }
        defer { IOHIDManagerClose(manager, noOptions) }
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x05AC,
            kIOHIDProductIDKey as String: productID,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return false }
        return !devices.isEmpty
    }
}

struct LASDiagnostic {
    let modelInfo: MacModelInfo
    let hardwareSupport: LASHardwareSupport
    let probeResult: LASSensorProbeResult

    var statusMessage: String {
        switch probeResult {
        case .foundStandard:
            if case .unknown(let id) = hardwareSupport {
                return "Sensor detected. (Model \(id) not yet in compatibility database.)"
            }
            return "Sensor detected and ready."
        case .foundVendorSpecific:
            return "Sensor hardware found but on unsupported vendor interface."
        case .notFound:
            switch hardwareSupport {
            case .supported(let model): return "\(model) should have a sensor, but it wasn't detected. Try restarting."
            case .unsupported(let reason): return reason
            case .unknown: return "No lid angle sensor detected on this Mac."
            }
        }
    }

    static let shared: LASDiagnostic = {
        let model = MacModelInfo.current()
        let diag = LASDiagnostic(
            modelInfo: model,
            hardwareSupport: model.hardwareSupport(),
            probeResult: MacModelInfo.probeSensor()
        )
        print("[Mac Harmonium] Model: \(model.identifier), sensor: \(diag.probeResult)")
        return diag
    }()

    static func run() -> LASDiagnostic { shared }
}
