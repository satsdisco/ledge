import Foundation
import CoreAudio
import Observation

/// One selectable audio output device. Used in the picker dropdown.
struct AudioOutputDevice: Identifiable, Equatable, Hashable {
    let id: AudioDeviceID
    let name: String
    let transportType: UInt32

    var isAirPlay: Bool { transportType == kAudioDeviceTransportTypeAirPlay }

    /// SF Symbol that matches the transport. Falls back to the generic
    /// speaker glyph for unknown / virtual devices.
    var iconName: String {
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:     return "laptopcomputer"
        case kAudioDeviceTransportTypeAirPlay:     return "airplayaudio"
        case kAudioDeviceTransportTypeBluetooth,
             kAudioDeviceTransportTypeBluetoothLE: return "headphones"
        case kAudioDeviceTransportTypeUSB:         return "headphones"
        case kAudioDeviceTransportTypeHDMI:        return "tv"
        case kAudioDeviceTransportTypeDisplayPort: return "display"
        case kAudioDeviceTransportTypeVirtual,
             kAudioDeviceTransportTypeAggregate:   return "rectangle.stack"
        default:                                   return "speaker.wave.2"
        }
    }
}

/// CoreAudio wrapper exposing the system's default output device volume +
/// name + a switchable list of all available outputs. Observable so SwiftUI
/// views update when the user adjusts volume elsewhere (system menu bar,
/// AirPods rotation, AirPlay receiver) or when the output device itself
/// changes (plugging headphones, picking an AirPlay target).
@Observable
final class AudioOutputController {
    /// 0.0 – 1.0. `nil` when the current output device has no volume control
    /// (e.g. some HDMI sinks). UI hides the slider in that case.
    private(set) var volume: Float?

    /// True when the output is muted. `nil` if the device has no mute control.
    private(set) var muted: Bool?

    /// Human-readable name of the active output ("MacBook Pro Speakers",
    /// "Living Room", "AirPods Pro"). Empty until the first refresh.
    private(set) var deviceName: String = ""

    /// True if the active output is an AirPlay device (we treat this as a
    /// signal worth surfacing in the UI — "Volume on Living Room speaker").
    private(set) var isAirPlay: Bool = false

    /// All audio devices on the system that have at least one output stream.
    /// Refreshed when devices come/go.
    private(set) var availableOutputs: [AudioOutputDevice] = []

    /// AudioDeviceID of the active default output. Used to mark the current
    /// selection in the picker.
    var activeDeviceID: AudioDeviceID { deviceID }

    private var deviceID: AudioDeviceID = kAudioObjectUnknown
    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    private var volumeListener: AudioObjectPropertyListenerBlock?
    private var muteListener: AudioObjectPropertyListenerBlock?
    private var devicesListListener: AudioObjectPropertyListenerBlock?

    init() {
        refreshDevice()
        refreshAvailableOutputs()
        installDefaultDeviceListener()
        installDevicesListListener()
    }

    deinit {
        removeDeviceListeners(deviceID: deviceID)
        removeDefaultDeviceListener()
        removeDevicesListListener()
    }

    // MARK: - Public API

    /// Set volume in 0.0 – 1.0. Clamped. No-op if the device has no volume.
    func setVolume(_ value: Float) {
        guard deviceID != kAudioObjectUnknown else { return }
        let clamped = max(0, min(1, value))
        var v = clamped
        let size = UInt32(MemoryLayout<Float32>.size)
        var address = volumeAddress
        guard AudioObjectHasProperty(deviceID, &address) else { return }
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &v)
        if status == noErr {
            volume = clamped
        } else {
            Log.module.error("Set output volume failed: status=\(status)")
        }
    }

    /// Toggle the mute state. No-op if the device has no mute control.
    func toggleMute() {
        guard deviceID != kAudioObjectUnknown else { return }
        var address = muteAddress
        guard AudioObjectHasProperty(deviceID, &address) else { return }
        var newValue: UInt32 = (muted == true) ? 0 : 1
        let status = AudioObjectSetPropertyData(
            deviceID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &newValue
        )
        if status == noErr {
            muted = (newValue == 1)
        }
    }

    // MARK: - Refresh

    /// Set the system's default output to the given device. Used by the
    /// picker dropdown — pick an AirPlay receiver, headphones, etc.
    func setDefaultOutput(_ id: AudioDeviceID) {
        var newID = id
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &newID
        )
        if status != noErr {
            Log.module.error("Set default output failed: status=\(status)")
        }
        // The default-device listener will fire and call refreshDevice() —
        // but call it inline too so the UI updates immediately on the click.
        refreshDevice()
    }

    /// Enumerate all output-capable devices on the system. Cheap; called on
    /// init and whenever kAudioHardwarePropertyDevices changes.
    func refreshAvailableOutputs() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let szStatus = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
        )
        guard szStatus == noErr, size > 0 else {
            availableOutputs = []
            return
        }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids
        )
        guard status == noErr else { return }

        availableOutputs = ids.compactMap { id -> AudioOutputDevice? in
            guard hasOutputStreams(id) else { return nil }
            let name = readDeviceName(id)
            guard !name.isEmpty else { return nil }
            return AudioOutputDevice(
                id: id,
                name: name,
                transportType: readTransportType(id)
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Re-read the current default output device and its volume/name.
    func refreshDevice() {
        removeDeviceListeners(deviceID: deviceID)
        deviceID = currentDefaultOutputDevice()
        if deviceID == kAudioObjectUnknown {
            volume = nil
            muted = nil
            deviceName = ""
            isAirPlay = false
            return
        }
        deviceName = readDeviceName(deviceID)
        isAirPlay = readIsAirPlay(deviceID)
        volume = readVolume(deviceID)
        muted = readMute(deviceID)
        installDeviceListeners(deviceID: deviceID)
    }

    // MARK: - CoreAudio plumbing

    private var volumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func currentDefaultOutputDevice() -> AudioDeviceID {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        return status == noErr ? deviceID : kAudioObjectUnknown
    }

    private func readVolume(_ id: AudioDeviceID) -> Float? {
        var address = volumeAddress
        guard AudioObjectHasProperty(id, &address) else { return nil }
        var v: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &v)
        return status == noErr ? v : nil
    }

    private func readMute(_ id: AudioDeviceID) -> Bool? {
        var address = muteAddress
        guard AudioObjectHasProperty(id, &address) else { return nil }
        var m: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &m)
        return status == noErr ? (m == 1) : nil
    }

    private func readDeviceName(_ id: AudioDeviceID) -> String {
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name)
        guard status == noErr, let unmanaged = name else { return "" }
        return unmanaged.takeRetainedValue() as String
    }

    private func readIsAirPlay(_ id: AudioDeviceID) -> Bool {
        readTransportType(id) == kAudioDeviceTransportTypeAirPlay
    }

    private func readTransportType(_ id: AudioDeviceID) -> UInt32 {
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &transport)
        return status == noErr ? transport : 0
    }

    /// True if the given device has at least one output stream (i.e. it's
    /// a destination we can route audio TO, not a microphone).
    private func hasOutputStreams(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr,
              size > 0 else { return false }
        let buffer = UnsafeMutablePointer<AudioBufferList>.allocate(
            capacity: Int(size) / MemoryLayout<AudioBufferList>.size + 1
        )
        defer { buffer.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, buffer) == noErr else {
            return false
        }
        let bufferList = UnsafeMutableAudioBufferListPointer(buffer)
        return bufferList.reduce(0, { $0 + Int($1.mNumberChannels) }) > 0
    }

    // MARK: - Listeners

    private func installDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.refreshDevice() }
        }
        defaultDeviceListener = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address, DispatchQueue.main, block
        )
    }

    private func removeDefaultDeviceListener() {
        guard let listener = defaultDeviceListener else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address, DispatchQueue.main, listener
        )
        defaultDeviceListener = nil
    }

    private func installDevicesListListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refreshAvailableOutputs()
        }
        devicesListListener = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address, DispatchQueue.main, block
        )
    }

    private func removeDevicesListListener() {
        guard let listener = devicesListListener else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address, DispatchQueue.main, listener
        )
        devicesListListener = nil
    }

    private func installDeviceListeners(deviceID: AudioDeviceID) {
        var volAddr = volumeAddress
        if AudioObjectHasProperty(deviceID, &volAddr) {
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.volume = self.readVolume(self.deviceID)
                }
            }
            volumeListener = block
            AudioObjectAddPropertyListenerBlock(deviceID, &volAddr, DispatchQueue.main, block)
        }

        var muteAddr = muteAddress
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.muted = self.readMute(self.deviceID)
                }
            }
            muteListener = block
            AudioObjectAddPropertyListenerBlock(deviceID, &muteAddr, DispatchQueue.main, block)
        }
    }

    private func removeDeviceListeners(deviceID: AudioDeviceID) {
        guard deviceID != kAudioObjectUnknown else { return }
        if let listener = volumeListener {
            var address = volumeAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &address, DispatchQueue.main, listener)
            volumeListener = nil
        }
        if let listener = muteListener {
            var address = muteAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &address, DispatchQueue.main, listener)
            muteListener = nil
        }
    }
}
