// Diagnostic for external DDC saturation: mirrors Candela's DCPAVServiceProxy
// registry traversal (nearest-identity pairing, DDCService.swift), then reads
// VCP 0x10 (brightness) three times per live channel, dumping the raw reply
// bytes, header validity, checksum validity, and the parsed current/max.
// Read-only: sends only DDC Get VCP requests, never Set. Run while the
// saturated state is live, with the Candela panel closed:
//   swift scripts/ddc-probe.swift
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

// 1. The CG display list Candela maps against.
print("=== CG external displays ===")
var count: UInt32 = 0
CGGetOnlineDisplayList(16, nil, &count)
var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
CGGetOnlineDisplayList(count, &ids, &count)
for id in ids where CGDisplayIsBuiltin(id) == 0 {
    let name = NSScreen.screens.first {
        ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == id
    }?.localizedName ?? "?"
    print("  id=\(id)  \(name)  vendor=\(CGDisplayVendorNumber(id)) model=\(CGDisplayModelNumber(id)) serial=\(CGDisplaySerialNumber(id))")
}

// 2. Same traversal as Candela: depth-first, nearest preceding identity wins.
print("\n=== DCPAVServiceProxy channels (traversal order) ===")
let root = IORegistryGetRootEntry(kIOMainPortDefault)
var iterator: io_iterator_t = 0
guard IORegistryEntryCreateIterator(root, kIOServicePlane,
        IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
    print("registry iterator failed"); exit(1)
}
var channels: [(service: IOAVServiceRef, identity: String, acked: Bool)] = []
var lastIdentity = "none"
var entry = IOIteratorNext(iterator)
while entry != IO_OBJECT_NULL {
    if let da = IORegistryEntryCreateCFProperty(entry, "DisplayAttributes" as CFString,
            kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any],
       let pa = da["ProductAttributes"] as? [String: Any],
       let vendor = u32(pa["LegacyManufacturerID"]), let product = u32(pa["ProductID"]) {
        let serial = u32(pa["SerialNumber"]) ?? 0
        let name = pa["ProductName"] as? String ?? "?"
        lastIdentity = "vendor=\(vendor) model=\(product) serial=\(serial) (\(name))"
    }
    if className(entry) == "DCPAVServiceProxy" {
        let location = IORegistryEntryCreateCFProperty(entry, "Location" as CFString,
            kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
        if location == nil || location == "External",
           let av = IOAVServiceCreateWithService(kCFAllocatorDefault, entry) {
            var testBuf = [UInt8](repeating: 0, count: 32)
            let acked = IOAVServiceReadI2C(av, 0x37, 0x51, &testBuf, 32) == kIOReturnSuccess
            channels.append((av, lastIdentity, acked))
            print("  #\(channels.count - 1) location=\(location ?? "nil") acked=\(acked) nearest identity: \(lastIdentity)")
        } else {
            print("  (skipped: location=\(location ?? "nil"))")
        }
    }
    IOObjectRelease(entry)
    entry = IOIteratorNext(iterator)
}
IOObjectRelease(iterator)
IOObjectRelease(root)

// 3. Three brightness reads per acked channel, raw bytes and all.
for (i, ch) in channels.enumerated() where ch.acked {
    print("\n=== channel #\(i) VCP 0x10 reads  [\(ch.identity)] ===")
    for attempt in 1...3 {
        var chk = UInt8(0x6E ^ 0x51)
        let payload: [UInt8] = [0x82, 0x01, 0x10]
        for b in payload { chk ^= b }
        var req = payload + [chk]
        let w = IOAVServiceWriteI2C(ch.service, 0x37, 0x51, &req, UInt32(req.count))
        guard w == kIOReturnSuccess else {
            print("  [\(attempt)] request write failed: 0x\(String(w, radix: 16))")
            Thread.sleep(forTimeInterval: 0.1)
            continue
        }
        Thread.sleep(forTimeInterval: 0.04)
        var reply = [UInt8](repeating: 0, count: 12)
        let r = IOAVServiceReadI2C(ch.service, 0x37, 0x51, &reply, UInt32(reply.count))
        guard r == kIOReturnSuccess else {
            print("  [\(attempt)] reply read failed: 0x\(String(r, radix: 16))")
            Thread.sleep(forTimeInterval: 0.1)
            continue
        }
        let hex = reply.map { String(format: "%02X", $0) }.joined(separator: " ")
        let headerOK = reply[0] == 0x6E && reply[2] == 0x02 && reply[3] == 0x00 && reply[4] == 0x10
        var expected = UInt8(0x50)
        for b in reply[0...9] { expected ^= b }
        let checksumOK = expected == reply[10]
        let maxVal = (UInt16(reply[6]) << 8) | UInt16(reply[7])
        let curVal = (UInt16(reply[8]) << 8) | UInt16(reply[9])
        print("  [\(attempt)] \(hex)")
        print("       headerOK=\(headerOK) checksumOK=\(checksumOK) parsed current=\(curVal) max=\(maxVal)")
        Thread.sleep(forTimeInterval: 0.1)
    }
}
print("\nddc-probe: done")
