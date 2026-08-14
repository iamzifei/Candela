// DDC round-trip probe: proves the full Set + Get VCP path works end to end on a
// given display, then puts the brightness back exactly where it was.
//
// Unlike ddc-write-probe.swift (which is pinned to specific monitors and leaves
// the panel wherever the sweep ended), this one is safe to run on a machine
// someone is using: it reads the current value first, nudges it, reads it back to
// confirm the monitor actually applied the write, and restores the original.
//
// Usage:
//   swift scripts/ddc-roundtrip-probe.swift <vendorID> <productID> [delta]
// Example (ViewSonic VX1622-4K, delta defaults to -25):
//   swift scripts/ddc-roundtrip-probe.swift 23139 5693
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

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2, let targetVendor = UInt32(args[0]), let targetModel = UInt32(args[1]) else {
    print("usage: swift scripts/ddc-roundtrip-probe.swift <vendorID> <productID> [delta]")
    exit(1)
}
let delta = args.count > 2 ? (Int(args[2]) ?? -25) : -25

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

// Same traversal as DDCService: walk the IORegistry depth-first and pair each
// DCPAVServiceProxy with the nearest preceding DisplayAttributes identity.
let root = IORegistryGetRootEntry(kIOMainPortDefault)
var iterator: io_iterator_t = 0
guard IORegistryEntryCreateIterator(root, kIOServicePlane,
        IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
    print("registry iterator failed"); exit(1)
}
var target: IOAVServiceRef?
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
    if className(entry) == "DCPAVServiceProxy",
       lastVendor == targetVendor, lastModel == targetModel, target == nil {
        let location = IORegistryEntryCreateCFProperty(entry, "Location" as CFString,
            kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
        if location == nil || location == "External" {
            target = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)
        }
    }
    IOObjectRelease(entry)
    entry = IOIteratorNext(iterator)
}
IOObjectRelease(iterator)
IOObjectRelease(root)

guard let target else { print("target channel not found"); exit(1) }

/// Reads VCP 0x10 and returns (current, max), or nil if the monitor replies with
/// anything other than a well-formed VCP feature reply.
func readBrightness() -> (current: UInt16, max: UInt16)? {
    var req: [UInt8] = [0x82, 0x01, 0x10]
    var chk = UInt8(0x6E ^ 0x51)
    for b in req { chk ^= b }
    req.append(chk)
    guard IOAVServiceWriteI2C(target, 0x37, 0x51, &req, UInt32(req.count)) == kIOReturnSuccess
    else { return nil }
    Thread.sleep(forTimeInterval: 0.05)

    var reply = [UInt8](repeating: 0, count: 12)
    guard IOAVServiceReadI2C(target, 0x37, 0x51, &reply, UInt32(reply.count)) == kIOReturnSuccess
    else { return nil }
    // 0x6E source echo, 0x88 = length 8 with the MSB length flag, 0x02 = VCP reply.
    guard reply[0] == 0x6E, reply[1] == 0x88, reply[2] == 0x02 else { return nil }
    let maxV = UInt16(reply[6]) << 8 | UInt16(reply[7])
    let curV = UInt16(reply[8]) << 8 | UInt16(reply[9])
    return (curV, maxV)
}

func writeBrightness(_ value: UInt16) -> Bool {
    var chk = UInt8(0x6E ^ 0x51)
    let payload: [UInt8] = [0x84, 0x03, 0x10, UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    for b in payload { chk ^= b }
    var buf = payload + [chk]
    return IOAVServiceWriteI2C(target, 0x37, 0x51, &buf, UInt32(buf.count)) == kIOReturnSuccess
}

print("channel found (vendor=\(targetVendor) model=\(targetModel))")

guard let original = readBrightness() else {
    print("FAIL: could not read a valid brightness reply — nothing written, nothing to restore.")
    exit(1)
}
print("  original brightness: \(original.current)/\(original.max)")

// Clamp the nudge into range so the restore is always a real round trip.
let nudged = UInt16(max(0, min(Int(original.max), Int(original.current) + delta)))
guard nudged != original.current else {
    print("FAIL: nudged value equals original (\(nudged)); pick a different delta.")
    exit(1)
}

print("  writing \(nudged)…")
guard writeBrightness(nudged) else { print("FAIL: write not acked"); exit(1) }
Thread.sleep(forTimeInterval: 0.5)

let after = readBrightness()
print("  read back: \(after.map { "\($0.current)/\($0.max)" } ?? "unreadable")")

print("  restoring \(original.current)…")
_ = writeBrightness(original.current)
Thread.sleep(forTimeInterval: 0.5)
let restored = readBrightness()
print("  final: \(restored.map { "\($0.current)/\($0.max)" } ?? "unreadable")")

if after?.current == nudged, restored?.current == original.current {
    print("PASS: monitor applied the write and the original value was restored.")
} else {
    print("PARTIAL: see values above — the write path may not be honoured by this monitor.")
}
