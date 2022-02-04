import Flutter
import Foundation
import AudioToolbox
import CoreAudio
import AVFoundation

var plugin: SwiftFlutterSequencerPlugin!

enum PluginError: Error {
    case engineNotReady
}

public class SwiftFlutterSequencerPlugin: NSObject, FlutterPlugin {
    public var registrar: FlutterPluginRegistrar!
    public var engine: CocoaEngine?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_sequencer", binaryMessenger: registrar.messenger())
        plugin = SwiftFlutterSequencerPlugin()
        plugin.registrar = registrar
        registrar.addMethodCallDelegate(plugin, channel: channel)
    }
    
    public override init() {
        super.init()

        plugin = self
    }
    
    deinit {
        plugin = nil
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if (call.method == "setupAssetManager") {
            result(nil)
        } else if (call.method == "normalizeAssetDir") {
            let assetDir = (call.arguments as AnyObject)["assetDir"] as! String

            result(normalizeAssetDir(registrar: registrar, assetDir: assetDir))
        } else if (call.method == "listAudioUnits") {
            listAudioUnits { result($0) }
        } else if (call.method == "addTrackAudioUnit") {
            let audioUnitId = (call.arguments as AnyObject)["id"] as! String
            addTrackAudioUnit(audioUnitId) { result($0) }
        } else if (call.method == "setupEngine") {
            let sampleRateCallbackPort = (call.arguments as AnyObject)["sampleRateCallbackPort"] as! Dart_Port
            setupEngine(sampleRateCallbackPort: sampleRateCallbackPort)
        } else if (call.method == "destroyEngine") {
            destroyEngine();
        } else if (call.method == "addTrackSfz") {
            let sfzPath = (call.arguments as AnyObject)["sfzPath"] as! String
            let tuningPath = (call.arguments as AnyObject)["tuningPath"] as! String
            let callbackPort = (call.arguments as AnyObject)["callbackPort"] as! Dart_Port
            addTrackSfz(sfzPath: sfzPath, tuningPath: tuningPath, callbackPort: callbackPort)
        } else if (call.method == "addTrackSfzString") {
            let sampleRoot = (call.arguments as AnyObject)["sampleRoot"] as! String
            let sfzString = (call.arguments as AnyObject)["sfzString"] as! String
            let tuningString = (call.arguments as AnyObject)["tuningString"] as! String
            let callbackPort = (call.arguments as AnyObject)["callbackPort"] as! Dart_Port
            addTrackSfzString(sampleRoot: sampleRoot, sfzString: sfzString, tuningString: tuningString, callbackPort: callbackPort);
        } else if (call.method == "addTrackSf2") {
            let path = (call.arguments as AnyObject)["path"] as! String
            let isAsset = (call.arguments as AnyObject)["isAsset"] as! Bool
            let presetIndex = (call.arguments as AnyObject)["presetIndex"] as! Int32
            let callbackPort = (call.arguments as AnyObject)["callbackPort"] as! Dart_Port
            addTrackSf2(path: path, isAsset: isAsset, presetIndex: presetIndex, callbackPort: callbackPort);
        } else if (call.method == "removeTrack") {
            let trackIndex = (call.arguments as AnyObject)["trackIndex"] as! track_index_t
            removeTrack(trackIndex: trackIndex);
        } else if (call.method == "resetTrack") {
            let trackIndex = (call.arguments as AnyObject)["trackIndex"] as! track_index_t
            resetTrack(trackIndex: trackIndex)
        } else if (call.method == "getPosition") {
            result(getPosition())
        } else if (call.method == "getTrackVolume") {
            let trackIndex = (call.arguments as AnyObject)["trackIndex"] as! track_index_t
            result(getTrackVolume(trackIndex: trackIndex))
        } else if (call.method == "getLastRenderTimeUs") {
            result(getLastRenderTimeUs())
        } else if (call.method == "getBufferAvailableCount") {
            let trackIndex = (call.arguments as AnyObject)["trackIndex"] as! track_index_t
            result(getBufferAvailableCount(trackIndex: trackIndex))
        } else if (call.method == "handleEventsNow") {
            let trackIndex = (call.arguments as AnyObject)["trackIndex"] as! track_index_t
            let uintInt8List = (call.arguments as AnyObject)["eventData"] as! FlutterStandardTypedData
            let byte = [UInt8](uintInt8List.data)
            let eventData = UnsafeMutablePointer<UInt8>.allocate(capacity: byte.count)
            for i in 0..<byte.count {
                eventData[i] = byte[i]
            }
            let eventsCount = (call.arguments as AnyObject)["eventsCount"] as! UInt32
            handleEventsNow(trackIndex: trackIndex, eventData: eventData, eventsCount: eventsCount);
        } else if (call.method == "scheduleEvents") {
            let trackIndex = (call.arguments as AnyObject)["trackIndex"] as! track_index_t
            let uintInt8List = (call.arguments as AnyObject)["eventData"] as! FlutterStandardTypedData
            let byte = [UInt8](uintInt8List.data)
            let eventData = UnsafeMutablePointer<UInt8>.allocate(capacity: byte.count)
            for i in 0..<byte.count {
                eventData[i] = byte[i]
            }
            let eventsCount = (call.arguments as AnyObject)["eventsCount"] as! UInt32
            result(scheduleEvents(trackIndex: trackIndex, eventData: eventData, eventsCount: eventsCount))
        } else if (call.method == "clearEvents") {
            let trackIndex = (call.arguments as AnyObject)["trackIndex"] as! track_index_t
            let fromFrame = (call.arguments as AnyObject)["fromFrame"] as! position_frame_t
            clearEvents(trackIndex: trackIndex, fromFrame: fromFrame)
        } else if (call.method == "enginePlay") {
            enginePlay()
        } else if (call.method == "enginePause") {
            enginePause();
        }
    }
}

// Called from method channel
func normalizeAssetDir(registrar: FlutterPluginRegistrar, assetDir: String) -> String? {
    let key = registrar.lookupKey(forAsset: assetDir)
    let path = Bundle.main.path(forResource: key, ofType: nil)
    
    return path
}

// Called from method channel
func listAudioUnits(completion: @escaping ([String]) -> Void) {
    AudioUnitUtils.loadAudioUnits { loadedComponents in
        let ids = loadedComponents.map(AudioUnitUtils.getAudioUnitId)
        
        completion(ids)
    }
}


@_cdecl("setup_engine")
func setupEngine(sampleRateCallbackPort: Dart_Port) {
    plugin.engine = CocoaEngine(sampleRateCallbackPort: sampleRateCallbackPort, registrar: plugin.registrar)
}

@_cdecl("destroy_engine")
func destroyEngine() {
    plugin.engine = nil
}

@_cdecl("add_track_sfz")
func addTrackSfz(sfzPath: UnsafePointer<CChar>, tuningPath: UnsafePointer<CChar>, callbackPort: Dart_Port) {
    plugin.engine!.addTrackSfz(sfzPath: sfzPath, tuningPath: tuningPath) { trackIndex in
        callbackToDartInt32(callbackPort, trackIndex)
    }
}

@_cdecl("add_track_sfz_string")
func addTrackSfzString(sampleRoot: UnsafePointer<CChar>, sfzString: UnsafePointer<CChar>, tuningString: UnsafePointer<CChar>, callbackPort: Dart_Port) {
    plugin.engine!.addTrackSfzString(sampleRoot: sampleRoot, sfzString: sfzString, tuningString: tuningString) { trackIndex in
        callbackToDartInt32(callbackPort, trackIndex)
    }
}

@_cdecl("add_track_sf2")
func addTrackSf2(path: UnsafePointer<CChar>, isAsset: Bool, presetIndex: Int32, callbackPort: Dart_Port) {
    plugin.engine!.addTrackSf2(sf2Path: String(cString: path), isAsset: isAsset, presetIndex: presetIndex) { trackIndex in
        callbackToDartInt32(callbackPort, trackIndex)
    }
}

// Called from method channel
func addTrackAudioUnit(_ audioUnitId: String, completion: @escaping (track_index_t) -> Void) {
    plugin.engine!.addTrackAudioUnit(audioUnitId: audioUnitId, completion: completion)
}

@_cdecl("remove_track")
func removeTrack(trackIndex: track_index_t) {
    let _ = plugin.engine!.removeTrack(trackIndex: trackIndex)
}

@_cdecl("reset_track")
func resetTrack(trackIndex: track_index_t) {
    SchedulerResetTrack(plugin.engine!.scheduler, trackIndex)
}

@_cdecl("get_position")
func getPosition() -> position_frame_t {
    return SchedulerGetPosition(plugin.engine!.scheduler)
}

@_cdecl("get_track_volume")
func getTrackVolume(trackIndex: track_index_t) -> Float32 {
    return SchedulerGetTrackVolume(plugin.engine!.scheduler, trackIndex)
}

@_cdecl("get_last_render_time_us")
func getLastRenderTimeUs() -> UInt64 {
    return SchedulerGetLastRenderTimeUs(plugin.engine!.scheduler)
}

@_cdecl("get_buffer_available_count")
func getBufferAvailableCount(trackIndex: track_index_t) -> UInt32 {
    return SchedulerGetBufferAvailableCount(plugin.engine!.scheduler, trackIndex)
}

@_cdecl("handle_events_now")
func handleEventsNow(trackIndex: track_index_t, eventData: UnsafePointer<UInt8>, eventsCount: UInt32) {
    let events = UnsafeMutablePointer<SchedulerEvent>.allocate(capacity: Int(eventsCount))
    
    rawEventDataToEvents(eventData, eventsCount, events)
    
    SchedulerHandleEventsNow(plugin.engine!.scheduler, trackIndex, UnsafePointer(events), eventsCount)
}

@_cdecl("schedule_events")
func scheduleEvents(trackIndex: track_index_t, eventData: UnsafePointer<UInt8>, eventsCount: UInt32) -> UInt32 {
    let events = UnsafeMutablePointer<SchedulerEvent>.allocate(capacity: Int(eventsCount))
    
    rawEventDataToEvents(eventData, eventsCount, events)
    
    return SchedulerAddEvents(plugin.engine!.scheduler, trackIndex, UnsafePointer(events), eventsCount)
}

@_cdecl("clear_events")
func clearEvents(trackIndex: track_index_t, fromFrame: position_frame_t) {
    SchedulerClearEvents(plugin.engine!.scheduler, trackIndex, fromFrame)
}

@_cdecl("engine_play")
func enginePlay() {
    plugin.engine!.play()
}

@_cdecl("engine_pause")
func enginePause() {
    plugin.engine!.pause()
}
