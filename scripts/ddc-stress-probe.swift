// Interleaved DDC stress test: mimics Candela running with both externals by
// alternating rapid AOC brightness reads (a wedged controller streaming
// garbage, retried like Candela does) with Dell brightness writes and reads.
// Prints per-iteration Dell health so degradation timing is visible.
//   swift scripts/ddc-stress-probe.swift
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

// Locate both channels by identity.
var aoc: IOAVServiceRef?
var dell: IOAVServiceRef?
let root = IORegistryGetRootEntry(kIOMainPortDefault)
var iterator: io_iterator_t = 0
guard IORegistryEntryCreateIterator(root, kIOServicePlane,
        IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
    print("registry iterator failed"); exit(1)
}
var lastVendor: UInt32 = 0
var entry = IOIteratorNext(iterator)
while entry != IO_OBJECT_NULL {
    if let da = IORegistryEntryCreateCFProperty(entry, "DisplayAttributes" as CFString,
            kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any],
       let pa = da["ProductAttributes"] as? [String: Any],
       let vendor = u32(pa["LegacyManufacturerID"]) {
        lastVendor = vendor
    }
    if className(entry) == "DCPAVServiceProxy" {
        let location = IORegistryEntryCreateCFProperty(entry, "Location" as CFString,
            kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
        if location == nil || location == "External" {
            if lastVendor == 1507, aoc == nil {
                aoc = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)
            } else if lastVendor == 4268, dell == nil {
                dell = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)
            }
        }
    }
    IOObjectRelease(entry)
    entry = IOIteratorNext(iterator)
}
IOObjectRelease(iterator)
IOObjectRelease(root)
guard let aoc, let dell else { print("channels not found (aoc=\(aoc != nil) dell=\(dell != nil))"); exit(1) }

func vcpReadRaw(_ svc: IOAVServiceRef) -> [UInt8]? {
    var chk = UInt8(0x6E ^ 0x51)
    let payload: [UInt8] = [0x82, 0x01, 0x10]
    for b in payload { chk ^= b }
    var req = payload + [chk]
    guard IOAVServiceWriteI2C(svc, 0x37, 0x51, &req, UInt32(req.count)) == kIOReturnSuccess else { return nil }
    Thread.sleep(forTimeInterval: 0.04)
    var reply = [UInt8](repeating: 0, count: 12)
    guard IOAVServiceReadI2C(svc, 0x37, 0x51, &reply, UInt32(reply.count)) == kIOReturnSuccess else { return nil }
    return reply
}

func vcpValid(_ reply: [UInt8]) -> Bool {
    guard reply[0] == 0x6E, reply[2] == 0x02, reply[3] == 0x00, reply[4] == 0x10 else { return false }
    var expected = UInt8(0x50)
    for i in 0...9 { expected ^= reply[i] }
    return expected == reply[10]
}

func vcpWrite(_ svc: IOAVServiceRef, _ value: UInt16) -> Bool {
    var chk = UInt8(0x6E ^ 0x51)
    let payload: [UInt8] = [0x84, 0x03, 0x10, UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    for b in payload { chk ^= b }
    var buf = payload + [chk]
    return IOAVServiceWriteI2C(svc, 0x37, 0x51, &buf, UInt32(buf.count)) == kIOReturnSuccess
}

// 20 iterations of Candela-like interleaving: 3 rapid AOC reads (the retry
// pattern its garbage stream provokes), a Dell write (gentle sweep around
// 50), then a Dell read verdict.
print("stress: 20 iterations of [3x AOC read, Dell write, Dell read]")
let sweep: [UInt16] = [50, 46, 42, 38, 42, 46, 50, 54, 58, 62, 58, 54, 50, 46, 42, 46, 50, 54, 50, 50]
var dellCleanCount = 0
for i in 0..<20 {
    var aocGarbage = 0
    for _ in 0..<3 {
        if let r = vcpReadRaw(aoc), !vcpValid(r) { aocGarbage += 1 }
        Thread.sleep(forTimeInterval: 0.05)
    }
    let wrote = vcpWrite(dell, sweep[i])
    Thread.sleep(forTimeInterval: 0.05)
    let dellReply = vcpReadRaw(dell)
    let dellClean = dellReply.map(vcpValid) ?? false
    if dellClean { dellCleanCount += 1 }
    let dellHex = dellReply.map { $0.map { String(format: "%02X", $0) }.joined(separator: " ") } ?? "read failed"
    print("  [\(String(format: "%02d", i + 1))] aocGarbage=\(aocGarbage)/3 dellWrite=\(wrote ? "acked" : "FAIL") dellRead=\(dellClean ? "clean" : "BAD: \(dellHex)")")
    Thread.sleep(forTimeInterval: 0.1)
}
print("stress done: Dell clean \(dellCleanCount)/20")
