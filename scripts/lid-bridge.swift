// Realtime lid-angle bridge for the web version of Mac Harmonium.
//
// macOS pushes the lid sensor's HID reports at only 1 Hz, which is all a
// browser's WebHID can see. This script polls the sensor at 30 Hz (like the
// native app) and streams the angle to http://localhost pages over a
// WebSocket, so the web harmonium gets realtime pumping.
//
//   swift scripts/lid-bridge.swift        (Ctrl-C to stop)
//
// Listens on ws://127.0.0.1:8137 — loopback only, never exposed to the network.
import Foundation
import IOKit.hid
import Network

// --- Find and open the sensor (same probe as the app) ---
let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
IOHIDManagerOpen(manager, 0)
IOHIDManagerSetDeviceMatching(manager, [
    kIOHIDVendorIDKey: 0x05AC, kIOHIDProductIDKey: 0x8104,
    "UsagePage": 0x20, "Usage": 0x8A,
] as CFDictionary)
var sensor: IOHIDDevice? = nil
for d in (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? [] {
    if (IOHIDDeviceGetProperty(d, kIOHIDPrimaryUsagePageKey as CFString) as? Int) == 0x20 { sensor = d }
}
guard let device = sensor, IOHIDDeviceOpen(device, 0) == kIOReturnSuccess else {
    print("No lid angle sensor found (MacBook Pro 2019+ / Air M2+ only).")
    exit(1)
}

func readAngle() -> Int? {
    var report = [UInt8](repeating: 0, count: 8)
    var length = CFIndex(report.count)
    guard IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length) == kIOReturnSuccess,
          length >= 3 else { return nil }
    return Int(report[1]) | (Int(report[2]) << 8)
}

// --- WebSocket server on loopback ---
let params = NWParameters.tcp
params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: 8137)
let ws = NWProtocolWebSocket.Options()
ws.autoReplyPing = true
params.defaultProtocolStack.applicationProtocols.insert(ws, at: 0)

var clients: [NWConnection] = []
let listener = try NWListener(using: params)
listener.newConnectionHandler = { conn in
    conn.stateUpdateHandler = { state in
        if case .failed = state { clients.removeAll { $0 === conn } }
        if case .cancelled = state { clients.removeAll { $0 === conn } }
    }
    conn.start(queue: .main)
    clients.append(conn)
    print("client connected (\(clients.count) total)")
}
listener.start(queue: .main)
print("Lid bridge running on ws://127.0.0.1:8137 — leave this open while playing.")

// --- Poll at 30 Hz, broadcast to all clients ---
Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
    guard !clients.isEmpty, let angle = readAngle() else { return }
    let meta = NWProtocolWebSocket.Metadata(opcode: .text)
    let context = NWConnection.ContentContext(identifier: "angle", metadata: [meta])
    let data = String(angle).data(using: .utf8)!
    for conn in clients {
        conn.send(content: data, contentContext: context, completion: .contentProcessed { _ in })
    }
}
RunLoop.main.run()
