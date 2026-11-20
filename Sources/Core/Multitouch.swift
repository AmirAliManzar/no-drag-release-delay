import Foundation

/// Bridge to `MultitouchSupport.framework`.
///
/// The framework is private, so it is opened with `dlopen` instead of being
/// linked: the app then has no load-time dependency on it and degrades to
/// "unavailable" rather than failing to launch if Apple ever removes it.
///
/// `MTDeviceCreateList` hands out *new* device objects on every call (verified
/// on macOS 27: the pointers change while the device ID stays the same), so
/// devices are identified by `MTDeviceGetDeviceID` and registered exactly once.
final class Multitouch {
    typealias Device = UnsafeMutableRawPointer
    typealias ContactCallback = @convention(c) (Int32, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32

    private typealias CreateListFn = @convention(c) () -> Unmanaged<CFArray>?
    private typealias RegisterFn = @convention(c) (Device?, ContactCallback?) -> Void
    private typealias UnregisterFn = @convention(c) (Device?, ContactCallback?) -> Void
    private typealias StartFn = @convention(c) (Device?, Int32) -> Int32
    private typealias StopFn = @convention(c) (Device?) -> Int32
    private typealias GetIDFn = @convention(c) (Device?, UnsafeMutablePointer<UInt64>?) -> Int32

    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"

    private var handle: UnsafeMutableRawPointer?
    private var devices: [Device] = []
    private var identifiers: Set<UInt64> = []
    private var callback: ContactCallback?

    private var createListFn: CreateListFn?
    private var registerFn: RegisterFn?
    private var unregisterFn: UnregisterFn?
    private var startFn: StartFn?
    private var stopFn: StopFn?
    private var getIDFn: GetIDFn?

    var isAvailable: Bool { handle != nil && createListFn != nil }
    var deviceCount: Int { devices.count }

    /// Opens the framework and starts every trackpad currently attached.
    /// Returns the number of devices that were registered.
    @discardableResult
    func start(callback: ContactCallback) -> Int {
        guard handle == nil else { return refresh() }

        guard let handle = dlopen(Self.frameworkPath, RTLD_NOW) else {
            Log.shared.info("multitouch: framework unavailable")
            return 0
        }
        self.handle = handle

        guard let createList: CreateListFn = symbol("MTDeviceCreateList"),
              let register: RegisterFn = symbol("MTRegisterContactFrameCallback"),
              let start: StartFn = symbol("MTDeviceStart") else {
            Log.shared.info("multitouch: required symbols missing")
            return 0
        }

        createListFn = createList
        registerFn = register
        startFn = start
        unregisterFn = symbol("MTUnregisterContactFrameCallback")
        stopFn = symbol("MTDeviceStop")
        getIDFn = symbol("MTDeviceGetDeviceID")
        self.callback = callback

        return refresh()
    }

    /// Registers any trackpad that was not present at the previous scan.
    @discardableResult
    func refresh() -> Int {
        guard let createListFn, let list = createListFn()?.takeRetainedValue() else { return 0 }

        var added = 0
        for index in 0..<CFArrayGetCount(list) {
            guard let raw = CFArrayGetValueAtIndex(list, index) else { continue }
            let device = Device(mutating: raw)

            let identifier = identity(of: device)
            guard !identifiers.contains(identifier) else { continue }

            identifiers.insert(identifier)
            devices.append(device)
            registerFn?(device, callback)
            _ = startFn?(device, 0)
            added += 1
        }
        return added
    }

    func stop() {
        for device in devices {
            if let stopFn { _ = stopFn(device) }
            if let unregisterFn, let callback { unregisterFn(device, callback) }
        }
        devices.removeAll()
        identifiers.removeAll()
    }

    /// The 64-bit value written by `MTDeviceGetDeviceID` is stable for the life
    /// of the hardware; the pointer is not. A device that reports no ID still
    /// needs a key, so its address is folded into the high half.
    private func identity(of device: Device) -> UInt64 {
        var identifier: UInt64 = 0
        if let getIDFn, getIDFn(device, &identifier) == 0, identifier != 0 {
            return identifier
        }
        return 0xFFFF_0000_0000_0000 | UInt64(UInt(bitPattern: device) & 0xFFFF_FFFF)
    }

    private func symbol<T>(_ name: String) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }
}
