// Companion to ddc-probe.swift: sends Set VCP 0x10 (brightness) writes to the
// AOC Q27G3XMN's DDC channel, 3 seconds apart, to test whether writes reach
// the monitor while its read path is wedged. Values come from argv:
//   swift scripts/ddc-write-probe.swift 30 80
// Targets ONLY the channel whose nearest registry identity is vendor=1507
// model=45862 (the AOC); everything else is skipped.
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

// First arg picks the monitor: "aoc" (default) or "dell". Remaining args are
// values, or "burst" for a slider-drag simulation (50ms-paced sweep).
var args = Array(CommandLine.arguments.dropFirst())
var targetVendor: UInt32 = 1507
var targetModel: UInt32 = 45862
if args.first == "dell" {
    targetVendor = 4268; targetModel = 41083; args.removeFirst()
} else if args.first == "aoc" {
    args.removeFirst()
}

func className(_ entry: io_service_t) -> String? {
    let buf = UnsafeMutablePointer<CChar>.allocate(capacity: 128)
    defer { buf.deallocate() }
    guard IOObjectGetClass(entry, buf) == KERN_SUCCESS else { return nil }
    return String(cString: buf)
}

func u32(_ value: Any?) -> UInt32? {
    if let v = value as? UInt32 { return v }
    if let v = value as? Int { return UInt32(bitPattern: Int32(truncatingIfNeeded: v)) }
    if let v = value as? NSNumber { return v.uint32Value }
    return nil
}

// Burst mode: mimic a Candela slider drag, one write per 50ms sweeping
// 50 -> 20 -> 80 -> 50 in steps of 2 (about 60 writes over 3 seconds).
var values: [UInt16] = []
var burst = false
if args.first == "burst" {
    burst = true
    var sweep: [UInt16] = []
    sweep.append(contentsOf: stride(from: 50, through: 20, by: -2).map { UInt16($0) })
    sweep.append(contentsOf: stride(from: 22, through: 80, by: 2).map { UInt16($0) })
    sweep.append(contentsOf: stride(from: 78, through: 50, by: -2).map { UInt16($0) })
    values = sweep
} else {
    values = args.compactMap { UInt16($0) }
}
guard !values.isEmpty else { print("usage: swift ddc-write-probe.swift [aoc|dell] <value ... | burst>"); exit(1) }

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
let pacing = burst ? 0.05 : 3.0
print("channel found (vendor=\(targetVendor) model=\(targetModel)); \(values.count) writes, \(Int(pacing * 1000))ms pacing")

var failures = 0
for (i, value) in values.enumerated() {
    var chk = UInt8(0x6E ^ 0x51)
    let payload: [UInt8] = [0x84, 0x03, 0x10, UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    for b in payload { chk ^= b }
    var buf = payload + [chk]
    let ret = IOAVServiceWriteI2C(target, 0x37, 0x51, &buf, UInt32(buf.count))
    if ret != kIOReturnSuccess { failures += 1 }
    if !burst {
        print("  write \(value): \(ret == kIOReturnSuccess ? "acked" : "FAILED 0x" + String(ret, radix: 16))")
    }
    if i < values.count - 1 { Thread.sleep(forTimeInterval: pacing) }
}
if burst { print("  burst complete: \(values.count - failures)/\(values.count) acked") }
print("ddc-write-probe: done")
