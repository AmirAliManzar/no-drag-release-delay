import Cocoa

/// Releases a trackpad drag the moment the last finger leaves the trackpad.
///
/// macOS implements "tap to drag" by keeping the left button pressed for a few
/// hundred milliseconds after the finger lifts, so that a second touch can pick
/// the drag up again. That grace period is what makes a drop feel late: the
/// window under the cursor only learns about the release once it expires.
///
/// Posting a mouse-up as soon as contact is lost collapses that wait to a
/// frame. The engine is deliberately conservative, because a synthetic mouse-up
/// that does not belong to a drag is indistinguishable from a stray click:
///
///   * it only acts when *every* contact is gone, so scrolling and two-finger
///     gestures are never interrupted;
///   * it waits `settleDelay` and then requires the left button to *still* be
///     down. A tap-to-click and a physical click both release the button
///     within a frame or two of the contact disappearing, so they never
///     qualify;
///   * it does nothing while drag lock is enabled, since holding the button is
///     the whole point of that setting;
///   * afterwards it swallows the mouse-up the system was going to deliver
///     anyway, so no orphan release lands on whatever is under the cursor.
final class Engine {
    static let shared = Engine()

    /// Stamped on synthetic events so the event tap can recognise its own work.
    private static let marker: Int64 = 0x4E44_5244 // "NDRD"

    /// Contact frames arrive every 8–12 ms. Three frames are enough to tell a
    /// released button from one the system is deliberately holding, and the
    /// resulting latency is an order of magnitude below the delay it removes.
    private static let settleDelay: TimeInterval = 0.035

    /// How long a queued duplicate mouse-up is still considered ours.
    private static let strayWindow: TimeInterval = 1.0

    /// A duplicate that arrives further than this from the synthetic release is
    /// treated as unrelated input.
    private static let strayRadius: CGFloat = 24

    private let lock = NSLock()
    private let multitouch = Multitouch()

    // Contacts are tracked per device and combined as the maximum, so an idle
    // Magic Trackpad cannot mask activity on the built-in one.
    private var contactsByDevice: [UInt64: Int] = [:]
    private var contacts = 0
    private var touchBeganAt: TimeInterval = 0
    private var liftAt: TimeInterval = 0
    private var generation = 0

    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var deviceScan: DispatchSourceTimer?

    /// Button state as observed by the event tap. More trustworthy than
    /// `CGEventSource.buttonState` for a drag the trackpad driver is holding,
    /// and the two are used together.
    private var observedButtonDown = false

    // Bookkeeping for the mouse-up the system still has queued.
    private var syntheticUpAt: TimeInterval = 0
    private var syntheticUpPoint = CGPoint.zero
    private var awaitingStrayUp = false
    private var strayDeadline: TimeInterval = 0
    private var realDownSinceSynthetic = false

    private(set) var releaseCount = 0
    private(set) var swallowedCount = 0
    private(set) var tapReady = false

    var onChange: (() -> Void)?

    // MARK: - Lifecycle

    func start() {
        let count = multitouch.start(callback: multitouchCallback)
        Log.shared.info("multitouch: \(count) device(s)")

        createTapIfPossible()
        startDeviceScan()
    }

    func stop() {
        deviceScan?.cancel()
        deviceScan = nil
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let tapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes)
        }
        tap = nil
        tapSource = nil
        tapReady = false
        multitouch.stop()
    }

    /// A Magic Trackpad can appear long after launch, so the device list is
    /// refreshed on a slow timer. Each scan allocates fresh device objects, so
    /// this is kept infrequent on purpose.
    private func startDeviceScan() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 30, repeating: 60)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let added = self.multitouch.refresh()
            if added > 0 {
                Log.shared.info("multitouch: \(added) new device(s)")
            }
        }
        timer.resume()
        deviceScan = timer
    }

    @discardableResult
    func createTapIfPossible() -> Bool {
        if tap != nil { return true }

        let mask = (1 << CGEventType.leftMouseDown.rawValue)
                 | (1 << CGEventType.leftMouseUp.rawValue)

        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: CGEventMask(mask),
                                          callback: eventTapCallback,
                                          userInfo: nil) else {
            tapReady = false
            DispatchQueue.main.async { self.onChange?() }
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        tapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        tapReady = true
        Log.shared.info("event tap: started")
        DispatchQueue.main.async { self.onChange?() }
        return true
    }

    // MARK: - Contacts

    func contactsChanged(device: UInt64, count: Int) {
        lock.lock()

        if (contactsByDevice[device] ?? 0) == count {
            lock.unlock()
            return
        }
        contactsByDevice[device] = count

        let previous = contacts
        contacts = contactsByDevice.values.max() ?? 0
        let now = uptime()

        if contacts > 0 && previous == 0 {
            touchBeganAt = now
            lock.unlock()
            Log.shared.info("touch began (\(contacts) contact\(contacts == 1 ? "" : "s"))")
            return
        }

        if contacts == 0 && previous > 0 {
            liftAt = now
            let duration = now - touchBeganAt
            lock.unlock()
            Log.shared.info(String(format: "all contacts gone after %.0f ms", duration * 1000))
            scheduleRelease()
            return
        }

        lock.unlock()
    }

    private func scheduleRelease() {
        generation &+= 1
        let token = generation
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + Self.settleDelay) { [weak self] in
            self?.releaseIfNeeded(token)
        }
    }

    private func releaseIfNeeded(_ token: Int) {
        lock.lock()
        guard token == generation, contacts == 0 else {
            lock.unlock()
            return
        }
        let began = touchBeganAt
        let lifted = liftAt
        lock.unlock()

        guard Preferences.shared.isEnabled else { return }
        guard !TrackpadSettings.dragLockEnabled else { return }

        // The decisive check happens now, not at the moment of the lift: a tap
        // to click and a physical click both release the button within a frame
        // or two of the contact disappearing, while a tap-drag keeps it pressed
        // for hundreds of milliseconds.
        let buttonDown = isLeftButtonDown
        let elapsed = (uptime() - lifted) * 1000

        lock.lock()
        let observed = observedButtonDown
        lock.unlock()

        Log.shared.info(String(format: "decision %.0f ms after lift: observed=%@ state=%@",
                               elapsed,
                               observed ? "down" : "up",
                               buttonDown ? "down" : "up"))

        guard observed || buttonDown else { return }

        performRelease(liftedAt: lifted)
    }

    private func performRelease(liftedAt: TimeInterval) {
        let point = CGEvent(source: nil)?.location ?? .zero

        guard let source = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(mouseEventSource: source,
                                  mouseType: .leftMouseUp,
                                  mouseCursorPosition: point,
                                  mouseButton: .left) else {
            Log.shared.info("release failed: could not create the event")
            return
        }
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)

        let now = uptime()
        lock.lock()
        syntheticUpAt = now
        syntheticUpPoint = point
        awaitingStrayUp = true
        strayDeadline = now + Self.strayWindow
        realDownSinceSynthetic = false
        releaseCount += 1
        lock.unlock()

        event.post(tap: .cghidEventTap)

        Log.shared.info(String(format: "released %.0f ms after lift at %.0f,%.0f",
                               (now - liftedAt) * 1000, point.x, point.y))
        DispatchQueue.main.async { self.onChange?() }
    }

    // MARK: - Event tap

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            Log.shared.info("event tap: re-enabled after \(type.rawValue)")
            return Unmanaged.passUnretained(event)
        }

        guard Preferences.shared.isEnabled else { return Unmanaged.passUnretained(event) }

        let now = uptime()
        let marker = event.getIntegerValueField(.eventSourceUserData)

        switch type {
        case .leftMouseDown:
            guard marker != Self.marker else { break }
            logButtonEvent("down", at: now)
            lock.lock()
            observedButtonDown = true
            realDownSinceSynthetic = true
            awaitingStrayUp = false
            lock.unlock()

        case .leftMouseUp:
            if marker == Self.marker {
                lock.lock()
                observedButtonDown = false
                lock.unlock()
                break
            }
            logButtonEvent("up", at: now)

            lock.lock()
            observedButtonDown = false
            lock.unlock()

            lock.lock()
            let swallow = awaitingStrayUp
                && !realDownSinceSynthetic
                && now <= strayDeadline
                && distance(event.location, syntheticUpPoint) < Self.strayRadius
            let delay = now - syntheticUpAt
            if swallow {
                awaitingStrayUp = false
                swallowedCount += 1
            }
            lock.unlock()

            if swallow {
                Log.shared.info(String(format: "swallowed the system's duplicate mouse-up %.0f ms late",
                                       delay * 1000))
                DispatchQueue.main.async { self.onChange?() }
                return nil
            }

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - Helpers

    /// Mouse events are only interesting while a touch is in progress; logging
    /// them unconditionally would record every click in the system.
    private func logButtonEvent(_ kind: String, at now: TimeInterval) {
        lock.lock()
        let active = contacts > 0
        let began = touchBeganAt
        lock.unlock()

        guard active else { return }
        Log.shared.info(String(format: "button %@ +%.0f ms into the touch", kind, (now - began) * 1000))
    }

    private var isLeftButtonDown: Bool {
        CGEventSource.buttonState(.combinedSessionState, button: .left)
            || CGEventSource.buttonState(.hidSystemState, button: .left)
    }

    private func uptime() -> TimeInterval { ProcessInfo.processInfo.systemUptime }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

// MARK: - C callbacks

private func eventTapCallback(_ proxy: CGEventTapProxy,
                              _ type: CGEventType,
                              _ event: CGEvent,
                              _ refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    Engine.shared.handle(type: type, event: event)
}

private func multitouchCallback(_ device: Int32,
                                _ fingers: UnsafeMutableRawPointer?,
                                _ count: Int32,
                                _ timestamp: Double,
                                _ frame: Int32) -> Int32 {
    Engine.shared.contactsChanged(device: UInt64(UInt32(bitPattern: device)), count: Int(count))
    return 0
}
