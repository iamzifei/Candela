// Reports what the I2C transport returns for a display, separately from what
// the monitor does about it.
//
// The distinction matters: BrightnessService decides a display supports DDC when
// a write "succeeds", but IOAVServiceWriteI2C reports success as soon as the
// bytes reach the bus. A monitor with DDC/CI switched off in its OSD, or behind
// a link that doesn't carry the channel, still ACKs at that level and then does
// nothing. The app then believes hardware brightness works and never falls back
// to software dimming, so the slider moves and the panel doesn't.
//
// Non-invasive: sends only Get VCP requests, never Set, so nothing on screen
// changes.
//
// Usage:  swift scripts/ddc-transport-probe.swift
import AppKit
import IOKit

typealias IOAVServiceRef = UnsafeMutableRawPointer
@_silgen_name("IOAVServiceCreateWithService")
func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> IOAVServiceRef?
@_silgen_name("IOAVServiceReadI2C")
func IOAVServiceReadI2C(_ service: IOAVServiceRef, _ chip: UInt32, _ offset: UInt32,
                        _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> IOReturn
@_silgen_name("IOAVServiceWriteI2C")
func IOAVServiceWriteI2C(_ service: IOAVServiceRef, _ chip: UInt32, _ dataAddress: UInt32,
                         _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> IOReturn

func className(_ entry: io_service_t) -> String {
    var name = [CChar](repeating: 0, count: 128)
    IOObjectGetClass(entry, &name)
    return String(cString: name)
}

func u32(_ value: Any?) -> UInt32? {
    if let v = value as? Int { return UInt32(bitPattern: Int32(truncatingIfNeeded: v)) }
    if let v = value as? NSNumber { return v.uint32Value }
    return nil
}

/// Screens by (vendor, product), so channels can be named.
var names: [String: String] = [:]
for screen in NSScreen.screens {
    guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
            as? CGDirectDisplayID else { continue }
    names["\(CGDisplayVendorNumber(id))/\(CGDisplayModelNumber(id))"] = screen.localizedName
}

let root = IORegistryGetRootEntry(kIOMainPortDefault)
var iterator: io_iterator_t = 0
guard IORegistryEntryCreateIterator(root, kIOServicePlane,
        IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
    print("registry iterator failed"); exit(1)
}

var channels: [(name: String, service: IOAVServiceRef)] = []
var lastVendor: UInt32 = 0
var lastModel: UInt32 = 0
var entry = IOIteratorNext(iterator)
while entry != IO_OBJECT_NULL {
    if let da = IORegistryEntryCreateCFProperty(entry, "DisplayAttributes" as CFString,
            kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any],
       let pa = da["ProductAttributes"] as? [String: Any],
       let vendor = u32(pa["LegacyManufacturerID"]), let product = u32(pa["ProductID"]) {
        lastVendor = vendor
        lastModel = product
    }
    if className(entry) == "DCPAVServiceProxy" {
        let location = IORegistryEntryCreateCFProperty(entry, "Location" as CFString,
            kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
        if location == nil || location == "External",
           let service = IOAVServiceCreateWithService(kCFAllocatorDefault, entry) {
            let key = "\(lastVendor)/\(lastModel)"
            channels.append((names[key] ?? key, service))
        }
    }
    IOObjectRelease(entry)
    entry = IOIteratorNext(iterator)
}
IOObjectRelease(iterator)
IOObjectRelease(root)

func describe(_ code: IOReturn) -> String {
    code == kIOReturnSuccess ? "success" : "0x" + String(UInt32(bitPattern: code), radix: 16)
}

print("VCP 0x10 (brightness), Get only\n")
for channel in channels {
    print("── \(channel.name)")

    var request: [UInt8] = [0x82, 0x01, 0x10]
    var checksum = UInt8(0x6E ^ 0x51)
    for byte in request { checksum ^= byte }
    request.append(checksum)
    let wrote = IOAVServiceWriteI2C(channel.service, 0x37, 0x51, &request, UInt32(request.count))
    print("   transport write : \(describe(wrote))")

    Thread.sleep(forTimeInterval: 0.05)
    var reply = [UInt8](repeating: 0, count: 12)
    let read = IOAVServiceReadI2C(channel.service, 0x37, 0x51, &reply, UInt32(reply.count))
    print("   transport read  : \(describe(read))")
    print("   reply bytes     : \(reply.map { String(format: "%02X", $0) }.joined(separator: " "))")

    let wellFormed = reply[0] == 0x6E && reply[1] == 0x88 && reply[2] == 0x02
    if wellFormed {
        let maxValue = UInt16(reply[6]) << 8 | UInt16(reply[7])
        let current = UInt16(reply[8]) << 8 | UInt16(reply[9])
        print("   monitor answered: yes — brightness \(current)/\(maxValue)")
        print("   verdict         : DDC works")
    } else if reply[1] == 0x80 {
        print("   monitor answered: null message (length byte 0x80)")
        print("   verdict         : ON THE BUS BUT REFUSING DDC/CI.")
        print("                     The transport says success, so a Set VCP write")
        print("                     would 'succeed' too and the app would believe")
        print("                     hardware brightness works. Enable DDC/CI in the")
        print("                     monitor's OSD, or the link isn't carrying it.")
    } else {
        print("   monitor answered: malformed")
        print("   verdict         : unusable")
    }
    print("")
}
