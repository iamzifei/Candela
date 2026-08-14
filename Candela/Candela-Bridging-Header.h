//
//  Candela-Bridging-Header.h
//  Candela
//
//  Private API declarations for CGVirtualDisplay and IOAVService.
//  Property names verified against Chromium's virtual_display_mac_util.mm.
//

#ifndef Candela_Bridging_Header_h
#define Candela_Bridging_Header_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// These are private-API declarations, transcribed from disassembly and from other
// projects' headers. Their nullability is not documented anywhere, so most pointers
// here carry no annotation and import into Swift as implicitly-unwrapped optionals.
// Clang's -Wnullability-completeness fires per file as soon as *anything* in it is
// annotated, and the Sidecar section below has to be (a bare `id` under an assume-
// nonnull region imports as `Any` and traps). The test target builds with
// warnings-as-errors, so that combination made the whole suite fail to compile.
//
// Annotating the rest was tried and reverted on 2026-08-15. Auditing the file with
// a file-wide NS_ASSUME_NONNULL compiles clean and then crashes at launch, SIGTRAP
// inside DDCService.buildAVServiceMapByProximity() on the IOAVService path. Reverting
// only the header, with every other change of that session left in place, stops the
// crash — so the cause is established even though the mechanism is not. Changing how
// twenty private-API pointers import into Swift is not a side quest to take on while
// chasing something else, and guessing at nullability we cannot verify is how the
// bug got in.
//
// So: the warning is off for this file, and the imports stay exactly as they are.
// Anyone who wants to audit this properly should do it as its own change, with the
// DDC path exercised on real hardware before and after.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability-completeness"

// MARK: - CGVirtualDisplay Private API (macOS 14+)

@interface CGVirtualDisplayDescriptor : NSObject
@property (nonatomic) CGSize   sizeInMillimeters;   // physical size (width, height) in mm
@property (nonatomic) uint32_t maxPixelsWide;       // max pixel width
@property (nonatomic) uint32_t maxPixelsHigh;       // max pixel height
@property (nonatomic) NSPoint  whitePoint;
@property (nonatomic) NSPoint  redPrimary;
@property (nonatomic) NSPoint  greenPrimary;
@property (nonatomic) NSPoint  bluePrimary;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic, copy) NSString *name;
@property (nonatomic) uint32_t vendorID;
@property (nonatomic) uint32_t productID;
@property (nonatomic) uint32_t serialNum;
@end

@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(NSUInteger)width
                       height:(NSUInteger)height
                  refreshRate:(double)refreshRate;
@property (nonatomic, readonly) NSUInteger width;
@property (nonatomic, readonly) NSUInteger height;
@property (nonatomic, readonly) double     refreshRate;
@end

@interface CGVirtualDisplaySettings : NSObject
@property (nonatomic) BOOL hiDPI;
@property (nonatomic, copy) NSArray *modes;
@end

@interface CGVirtualDisplay : NSObject
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@property (nonatomic, readonly) CGDirectDisplayID displayID;
@end

// MARK: - CGSDisplayMode (advanced resolution switching)

typedef struct {
    uint32_t modeID;
    uint32_t width;
    uint32_t height;
    uint32_t depth;
    double   refreshRate;
    uint32_t flags;        // bit 0x20000 = HiDPI
} CGSDisplayMode;

typedef int CGSConnectionID_t;
// Applies a mode by its raw modeNumber. arg1 is a CONFIG TOKEN from CGBeginDisplayConfiguration,
// NOT the connection id: the call reads it as a CGSConfigData*, so passing the connection id
// segfaults in checkCapacity() on macOS 26. Sequence: CGBeginDisplayConfiguration -> this ->
// CGCompleteDisplayConfiguration. Verified against BetterDisplay's behaviour on Tahoe.
extern CGError CGSConfigureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int32_t modeNumber);
extern CGSConnectionID_t CGSMainConnectionID(void);

// Full CGS mode description for enumeration. CGDisplayCopyAllDisplayModes hides the GPU-scaled
// HiDPI variants of any resolution that collides with a real EDID timing (e.g. 1920x1080 HiDPI,
// whose 3840x2160 backing the panel exposes as a real 4K@50 timing); the private CGS list still
// carries them at full refresh. Layout reverse-engineered; offsets verified at runtime. `density`
// is the backing scale (2.0 == HiDPI); `flags` bit 0x40000000 marks modes macOS deems unusable
// (matches isUsableForDesktopGUI == false). modeNumber == ioDisplayModeID (pass to CGSConfigureDisplayMode).
typedef struct {
    uint32_t modeNumber;   // 0
    uint32_t flags;        // 4
    uint32_t width;        // 8   logical
    uint32_t height;       // 12  logical
    uint32_t depth;        // 16
    uint32_t dc2[42];      // 20
    uint16_t dc3;          // 188
    uint16_t freq;         // 190 refresh in Hz
    uint32_t dc4[4];       // 192
    float    density;      // 208 backing scale
} CGSDisplayModeDescription;   // 212 bytes

extern CGError CGSGetNumberOfDisplayModes(CGDirectDisplayID display, int *nModes);
extern CGError CGSGetDisplayModeDescriptionOfLength(CGDirectDisplayID display, int idx,
                                                    CGSDisplayModeDescription *mode, int length);

// MARK: - SkyLight Private API (physical display disconnect/reconnect, Apple Silicon)

// Enable/disable an individual display inside a CGBeginDisplayConfiguration transaction.
// On Apple Silicon (macOS 13+) disabling performs a true hardware disconnect (identical to
// clamshell): the display is removed from CGGetOnlineDisplayList / CGGetActiveDisplayList.
extern CGError SLSConfigureDisplayEnabled(CGDisplayConfigRef config,
                                          CGDirectDisplayID display,
                                          bool enabled);

// Enumerates ALL displays including ones disabled via SLSConfigureDisplayEnabled. Required to
// recover a disabled display's ID for reconnect, since CGGetOnlineDisplayList omits it.
extern CGError SLSGetDisplayList(uint32_t maxDisplays,
                                 CGDirectDisplayID *displays,
                                 uint32_t *displayCount);

// MARK: - SidecarCore Private API (iPad as a display)

// SidecarCore is not in the public SDK and is not linked; its classes are resolved
// at runtime after dlopen (see SidecarService).
//
// Declared as PROTOCOLS, not @interface. An @interface makes the compiler emit a
// reference to `_OBJC_CLASS_$_SidecarDevice` and friends, and even marked for
// dynamic lookup dyld resolves those at launch — before anything has had a chance
// to dlopen the framework — so the app aborts on start with "symbol not found in
// flat namespace". A protocol emits no class reference at all: the Swift side gets
// the same typed API, and the objects are obtained by name and bit-cast onto these
// protocols, which is sound because ObjC dispatch is by selector.
//
// Verified against the live runtime on macOS 26.6, which is also where the
// surprises came from: the config's flags are boxed NSNumbers rather than BOOLs,
// with nil meaning "leave at the system default", and `configForDevice:` returns
// nil for any device that is not already connected.

NS_ASSUME_NONNULL_BEGIN

@protocol CandelaSidecarDevice <NSObject>
@property (nonatomic, readonly, copy) NSString *name;
/// An NSUUID, not a string — reading it as NSString crashes in
/// `-[__NSConcreteUUID length]`. Its `description` looks like a UUID string, which
/// is exactly why dumping it through KVC made it look like one.
@property (nonatomic, readonly, copy) NSUUID *identifier;
@property (nonatomic, readonly, copy) NSString *localizedDeviceType;
/// Whether this device can act as an additional display at all, as opposed to only
/// receiving drawing input.
@property (nonatomic, readonly) BOOL offersAdditionalDisplay;
@end

@protocol CandelaSidecarDisplayConfig <NSObject>
/// ⚠️ DO NOT SET. "Exclusive" is literal: setting this to YES connected the iPad
/// and blanked both attached external monitors. Observed on macOS 26.6.
///
/// It was set here once, on the guess that "exclusive mode" meant the iPad owning
/// its own display space — i.e. extend rather than mirror. It does not. Extend
/// versus mirror for a Sidecar display is ordinary display mirroring, applied
/// after connecting with CGConfigureDisplayMirrorOfDisplay like any other screen;
/// see SidecarService. Declared only so the name is documented and nobody
/// rediscovers it the same way.
@property (nonatomic, copy, nullable) NSNumber *configureDisplayExclusiveMode;
/// The iPad-side sidebar with the modifier keys.
@property (nonatomic, copy, nullable) NSNumber *showSideBar;
/// The iPad-side Touch Bar strip.
@property (nonatomic, copy, nullable) NSNumber *showTouchBar;
/// The CGDirectDisplayID the session is running on, once connected. Boxed.
@property (nonatomic, copy, nullable) NSNumber *displayID;
@end

@protocol CandelaSidecarDisplayManager <NSObject>
/// Devices that could be connected right now.
@property (nonatomic, readonly, copy) NSArray *devices;
/// Devices currently serving as a display.
@property (nonatomic, readonly, copy) NSArray *connectedDevices;
/// The live config of a CONNECTED device, nil for anything else. The only way to
/// learn which CGDirectDisplayID the iPad ended up on.
- (nullable id<CandelaSidecarDisplayConfig>)configForDevice:(id)device;
- (void)connectToDevice:(id)device
             withConfig:(id)config
             completion:(void (^)(NSError *_Nullable error))completion;
- (void)disconnectFromDevice:(id)device
                  completion:(void (^)(NSError *_Nullable error))completion;
@end

/// The class object of SidecarDisplayManager, addressed as an instance.
///
/// A class method is an instance method of the metaclass, so sending these to the
/// class object works — and unlike a `+` declaration on a protocol it needs no
/// metatype gymnastics on the Swift side.
@protocol CandelaSidecarManagerClass <NSObject>
/// Typed as the protocol, not `id`. Under NS_ASSUME_NONNULL a bare `id` imports as
/// Swift's `Any`, and returning the object through that bridging path traps —
/// `id<Protocol>` imports as a class-constrained existential and returns cleanly.
- (id<CandelaSidecarDisplayManager>)sharedManager;
- (BOOL)isSupported;
@end

/// A metatype cannot be bit-cast onto these protocols — Swift's representation of
/// `AnyClass` is not the bare class pointer, and doing so segfaults inside
/// objc_msgSend. Bind the class to `AnyObject` first (`anyClass as AnyObject`),
/// which does yield the class object, then cast that.

NS_ASSUME_NONNULL_END

// MARK: - IOAVService Private API (Apple Silicon DDC)

typedef void * IOAVServiceRef;
extern IOAVServiceRef IOAVServiceCreate(CFAllocatorRef allocator);
extern IOAVServiceRef IOAVServiceCreateWithService(CFAllocatorRef allocator, io_service_t service);
extern IOReturn IOAVServiceReadI2C(IOAVServiceRef service,
                                   uint32_t chipAddress,
                                   uint32_t offset,
                                   void *outputBuffer,
                                   uint32_t outputBufferSize);
extern IOReturn IOAVServiceWriteI2C(IOAVServiceRef service,
                                    uint32_t chipAddress,
                                    uint32_t dataAddress,
                                    void *inputBuffer,
                                    uint32_t inputBufferSize);

#pragma clang diagnostic pop

#endif /* Candela_Bridging_Header_h */
