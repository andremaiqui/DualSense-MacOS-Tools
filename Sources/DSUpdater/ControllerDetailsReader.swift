import Foundation
import IOKit.hid
import GameController

struct ControllerDetails {
    let serialNumber: String?
    let batteryLevel: Int?
    let isCharging: Bool?
}

private final class BatteryReportContext {
    var statusByte: UInt8?
}

enum ControllerDetailsReader {
    private static let vendorID = 0x054C
    private static let productIDs = [0x0CE6, 0x0DF2]

    static func read() -> ControllerDetails {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

        let matching = productIDs.map { productID in
            [
                kIOHIDVendorIDKey as String: vendorID,
                kIOHIDProductIDKey as String: productID
            ] as [String: Any]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
              let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return ControllerDetails(serialNumber: nil, batteryLevel: nil, isCharging: nil)
        }

        let device = devices.first { device in
            let vendor = (IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber)?.intValue
            let product = (IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber)?.intValue
            return vendor == vendorID && productIDs.contains(product ?? 0)
        }
        guard let device else {
            return ControllerDetails(serialNumber: nil, batteryLevel: nil, isCharging: nil)
        }
        defer {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        let serialNumber = readSerialNumber(from: device)
        let battery = readBatteryStatus(from: device)
        return ControllerDetails(
            serialNumber: serialNumber,
            batteryLevel: battery?.level,
            isCharging: battery?.isCharging
        )
    }

    private static func readSerialNumber(from device: IOHIDDevice) -> String? {
        // Factory diagnostic command: SYSTEM (1), READ_SERIAL_NUMBER (19).
        var command = [UInt8](repeating: 0, count: 64)
        command[0] = 0x80
        command[1] = 0x01
        command[2] = 0x13
        let sent = command.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeFeature,
                0x80,
                $0.baseAddress!,
                CFIndex($0.count)
            )
        }
        guard sent == kIOReturnSuccess else { return nil }

        // The controller returns 56-byte data pages in feature report 0x81.
        for _ in 0..<20 {
            var report = [UInt8](repeating: 0, count: 64)
            var length = CFIndex(report.count)
            let result = report.withUnsafeMutableBufferPointer {
                IOHIDDeviceGetReport(
                    device,
                    kIOHIDReportTypeFeature,
                    0x81,
                    $0.baseAddress!,
                    &length
                )
            }
            guard result == kIOReturnSuccess, length >= 4,
                  report[0] == 0x81, report[1] == 0x01, report[2] == 0x13 else {
                Thread.sleep(forTimeInterval: 0.01)
                continue
            }

            let status = report[3]
            guard status == 0x02 || status == 0x03 else {
                Thread.sleep(forTimeInterval: 0.01)
                continue
            }

            let payload = report.dropFirst(4).prefix(32)
            let bytes = Array(payload.prefix { $0 != 0 })
            guard !bytes.isEmpty else { return nil }
            let value = String(bytes: bytes, encoding: .ascii)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value?.isEmpty == false ? value : nil
        }
        return nil
    }

    private static func readBatteryStatus(from device: IOHIDDevice) -> (level: Int, isCharging: Bool)? {
        let context = BatteryReportContext()
        let reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        reportBuffer.initialize(repeating: 0, count: 64)
        defer { reportBuffer.deallocate() }

        let callback: IOHIDReportCallback = { contextPointer, result, _, reportType, reportID, report, reportLength in
            guard result == kIOReturnSuccess,
                  reportType == kIOHIDReportTypeInput,
                  reportID == 0x01,
                  reportLength >= 54,
                  let contextPointer else { return }
            Unmanaged<BatteryReportContext>
                .fromOpaque(contextPointer)
                .takeUnretainedValue()
                .statusByte = report[53]
        }

        IOHIDDeviceRegisterInputReportCallback(
            device,
            reportBuffer,
            64,
            callback,
            Unmanaged.passUnretained(context).toOpaque()
        )
        let runLoopMode = CFRunLoopMode.defaultMode!
        let ioHIDRunLoopMode = RunLoop.Mode.default.rawValue as CFString
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), ioHIDRunLoopMode)
        CFRunLoopRunInMode(runLoopMode, 0.25, true)
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), ioHIDRunLoopMode)
        IOHIDDeviceRegisterInputReportCallback(device, reportBuffer, 64, nil, nil)

        // Prefer GameController's system-provided level when available. It can
        // preserve macOS's displayed percentage (for example, 95%) instead of
        // the controller's coarser 10% HID buckets.
        let sonyControllers = GCController.controllers().filter {
            $0.vendorName?.localizedCaseInsensitiveContains("sony") == true
        }
        if sonyControllers.count == 1,
           let battery = sonyControllers[0].battery {
            let level = battery.batteryLevel
            if level.isFinite, (0...1).contains(level) {
                return (Int((level * 100).rounded()), battery.batteryState == .charging)
            }
        }

        if let status = context.statusByte {
            let capacity = Int(status & 0x0F)
            switch status >> 4 {
            case 0:
                return (min(capacity * 10 + 5, 100), false)
            case 1:
                return (min(capacity * 10 + 5, 100), true)
            case 2:
                return (100, false)
            default:
                break
            }
        }
        return nil
    }

}
