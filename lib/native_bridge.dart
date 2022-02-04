import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import 'models/events.dart';
import 'utils/isolate.dart';

final DynamicLibrary nativeLib = Platform.isAndroid
    ? DynamicLibrary.open('libflutter_sequencer.so')
    : DynamicLibrary.executable();

final nRegisterPostCObject = nativeLib.lookupFunction<
    Void Function(
        Pointer<NativeFunction<Int8 Function(Int64, Pointer<Dart_CObject>)>>
            functionPointer),
    void Function(
        Pointer<NativeFunction<Int8 Function(Int64, Pointer<Dart_CObject>)>>
            functionPointer)>('RegisterDart_PostCObject');

final nSetupEngine = nativeLib
    .lookupFunction<Void Function(Int64), void Function(int)>('setup_engine');

final nDestroyEngine = nativeLib
    .lookupFunction<Void Function(), void Function()>('destroy_engine');

final nAddTrackSf2 = nativeLib.lookupFunction<
    Void Function(Pointer<Utf8>, Int8, Int32, Int64),
    void Function(Pointer<Utf8>, int, int, int)>('add_track_sf2');

final nAddTrackSfz = nativeLib.lookupFunction<
    Void Function(Pointer<Utf8>, Pointer<Utf8>, Int64),
    void Function(Pointer<Utf8>, Pointer<Utf8>, int)>('add_track_sfz');

final nAddTrackSfzString = nativeLib.lookupFunction<
    Void Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int64),
    void Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>,
        int)>('add_track_sfz_string');

final nRemoveTrack = nativeLib
    .lookupFunction<Void Function(Int32), void Function(int?)>('remove_track');

final nResetTrack = nativeLib
    .lookupFunction<Void Function(Int32), void Function(int?)>('reset_track');

final nGetPosition =
    nativeLib.lookupFunction<Uint32 Function(), int Function()>('get_position');

final nGetTrackVolume =
    nativeLib.lookupFunction<Float Function(Int32), double Function(int?)>(
        'get_track_volume');

final nGetLastRenderTimeUs =
    nativeLib.lookupFunction<Uint64 Function(), int Function()>(
        'get_last_render_time_us');

final nGetBufferAvailableCount =
    nativeLib.lookupFunction<Uint32 Function(Int32), int Function(int?)>(
        'get_buffer_available_count');

final nHandleEventsNow = nativeLib.lookupFunction<
    Uint32 Function(Int32?, Pointer<Uint8>?, Uint32),
    int Function(int?, Pointer<Uint8>?, int)>('handle_events_now');

final nScheduleEvents = nativeLib.lookupFunction<
    Uint32 Function(Int32?, Pointer<Uint8>?, Uint32),
    int Function(int?, Pointer<Uint8>?, int)>('schedule_events');

final nClearEvents = nativeLib.lookupFunction<Void Function(Int32, Uint32),
    void Function(int?, int?)>('clear_events');

final nPlay =
    nativeLib.lookupFunction<Void Function(), void Function()>('engine_play');

final nPause =
    nativeLib.lookupFunction<Void Function(), void Function()>('engine_pause');

/// {@macro flutter_sequencer_library_private}
/// This class encapsulates the boilerplate code needed to call into native code
/// and get responses back. It should hide any implementation details from the
/// rest of the library.
class NativeBridge {
  static const MethodChannel _channel = MethodChannel('flutter_sequencer');

  // Must be called once, before any other method
  static Future<int> doSetup() async {
    await _channel.invokeMethod('setupAssetManager');
    nRegisterPostCObject(NativeApi.postCObject);

    if (Platform.isAndroid) {
      return singleResponseFuture<int>((port) => nSetupEngine(port.nativePort));
    }

    return singleResponseFuture<int>((port) async {
      final args = <String, dynamic>{
        'sampleRateCallbackPort': port.nativePort,
      };
      return await _channel.invokeMethod('setupEngine', args);
    });
  }

  /// On Android, this will copy the asset dir from the AssetManager into
  /// context.filesDir, and return the filesystem path to the newly created
  /// dir. Pathnames will be URL-decoded.
  /// On iOS, this will return the filesystem path to the asset dir.
  static Future<String?> normalizeAssetDir(String assetDir) async {
    final args = <String, dynamic>{
      'assetDir': assetDir,
    };
    final result = await _channel.invokeMethod('normalizeAssetDir', args);
    final String? path = result;

    return path;
  }

  static Future<List<String>?> listAudioUnits() async {
    final result = await _channel.invokeMethod('listAudioUnits');
    final List<String>? audioUnitIds = result.cast<String>();

    return audioUnitIds;
  }

  static Future<int> addTrackSf2(
      String filename, bool isAsset, int patchNumber) {
    if (Platform.isAndroid) {
      final filenameUtf8Ptr = filename.toNativeUtf8();
      return singleResponseFuture<int>((port) => nAddTrackSf2(
          filenameUtf8Ptr, isAsset ? 1 : 0, patchNumber, port.nativePort));
    }

    return singleResponseFuture<int>((port) async {
      final args = <String, dynamic> {
        'path': filename,
        'isAsset': isAsset ? 1 : 0,
        'presetIndex': patchNumber,
        'callbackPort': port.nativePort,
      };
      return await _channel.invokeMethod('addTrackSf2', args);
    });
  }

  static Future<int> addTrackSfz(String sfzPath, String? tuningPath) {
    if (Platform.isAndroid) {
      final sfzPathUtf8Ptr = sfzPath.toNativeUtf8();
      final tuningPathUtf8Ptr =
          tuningPath?.toNativeUtf8() ?? Pointer.fromAddress(0);

      return singleResponseFuture<int>((port) =>
          nAddTrackSfz(sfzPathUtf8Ptr, tuningPathUtf8Ptr, port.nativePort));
    }

    return singleResponseFuture<int>((port) async {
        final args = <String, dynamic> {
          'sfzPath': sfzPath,
          'tuningPath': tuningPath ?? Pointer.fromAddress(0).toString(),
          'callbackPort': port.nativePort,
        };
        return await _channel.invokeMethod('addTrackSfz', args);
    });
  }

  static Future<int> addTrackSfzString(
      String sampleRoot, String sfzContent, String? tuningString) {
    if (Platform.isAndroid) {
      final sampleRootUtf8Ptr = sampleRoot.toNativeUtf8();
      final sfzContentUtf8Ptr = sfzContent.toNativeUtf8();
      final tuningStringUtf8Ptr =
          tuningString?.toNativeUtf8() ?? Pointer.fromAddress(0);

      return singleResponseFuture<int>((port) => nAddTrackSfzString(
          sampleRootUtf8Ptr,
          sfzContentUtf8Ptr,
          tuningStringUtf8Ptr,
          port.nativePort));
    }

    return singleResponseFuture<int>((port) async {
      final args = <String, dynamic> {
        'sampleRoot': sampleRoot,
        'sfzString': sfzContent,
        'tuningString': tuningString ?? Pointer.fromAddress(0).toString(),
        'callbackPort': port.nativePort,
      };
      return await _channel.invokeMethod('addTrackSfzString', args);
    });
  }

  static Future<int?> addTrackAudioUnit(String id) async {
    if (Platform.isAndroid) return -1;

    final args = <String, dynamic>{
      'id': id,
    };

    return await _channel.invokeMethod('addTrackAudioUnit', args);
  }

  static void removeTrack(int trackIndex) {
    Platform.isAndroid ? nRemoveTrack(trackIndex) : nRemoveTrack(trackIndex);
  }

  static void resetTrack(int trackIndex) {
    if (Platform.isAndroid) {
      return nResetTrack(trackIndex);
    }

    final args = <String, dynamic> {
      'trackIndex': trackIndex,
    };
    _channel.invokeMethod('resetTrack', args);
  }

  static Future<int> getPosition() async {
    return Platform.isAndroid ? nGetPosition() : await _channel.invokeMethod('getPosition');
  }

  static Future<double> getTrackVolume(int trackIndex) async {
    if (Platform.isAndroid) {
      return nGetTrackVolume(trackIndex);
    }

    final args = <String, dynamic>{
      'trackIndex': trackIndex,
    };
    return await _channel.invokeMethod('getTrackVolume', args);
  }

  static Future<int> getLastRenderTimeUs() async {
    if (Platform.isAndroid) {
      return nGetLastRenderTimeUs();
    }

    return await _channel.invokeMethod('getLastRenderTimeUs');
  }

  static Future<int> getBufferAvailableCount(int trackIndex) async {
    if (Platform.isAndroid) {
      return nGetBufferAvailableCount(trackIndex);
    }

    final args = <String, dynamic> {
      'trackIndex': trackIndex,
    };
    return await _channel.invokeMethod('getBufferAvailableCount', args);
  }

  static Future<int> handleEventsNow(int trackIndex, List<SchedulerEvent> events,
      int sampleRate, double tempo) async {
    if (events.isEmpty) return 0;

    if (Platform.isAndroid) {
      final Pointer<Uint8>? nativeArray =
          calloc<Uint8>(events.length * SCHEDULER_EVENT_SIZE);
      events.asMap().forEach((eventIndex, e) {
        final byteData = e.serializeBytes(sampleRate, tempo, 0);
        for (var byteIndex = 0; byteIndex < byteData.lengthInBytes; byteIndex++) {
          nativeArray![eventIndex * SCHEDULER_EVENT_SIZE + byteIndex] =
              byteData.getUint8(byteIndex);
        }
      });
      return nHandleEventsNow(trackIndex, nativeArray, events.length);
    }

    final Uint8List eventData = Uint8List(events.length * SCHEDULER_EVENT_SIZE);
    events.asMap().forEach((eventIndex, e) {
      final byteData = e.serializeBytes(sampleRate, tempo, 0);
      for (var byteIndex = 0; byteIndex < byteData.lengthInBytes; byteIndex++) {
        eventData[eventIndex * SCHEDULER_EVENT_SIZE + byteIndex] =
            byteData.getUint8(byteIndex);
      }
    });

    final args = <String, dynamic> {
      'trackIndex': trackIndex,
      'eventData': eventData,
      'eventsCount': events.length,
    };

    return await _channel.invokeMethod('handleEventsNow', args);
  }

  static Future<int> scheduleEvents(int trackIndex, List<SchedulerEvent> events,
      int sampleRate, double tempo, int frameOffset) async {
    if (events.isEmpty) return 0;

    if (Platform.isAndroid) {
      final Pointer<Uint8>? nativeArray =
          calloc<Uint8>(events.length * SCHEDULER_EVENT_SIZE);
      events.asMap().forEach((eventIndex, e) {
        final byteData = e.serializeBytes(sampleRate, tempo, frameOffset);
        for (var byteIndex = 0; byteIndex < byteData.lengthInBytes; byteIndex++) {
          nativeArray![eventIndex * SCHEDULER_EVENT_SIZE + byteIndex] =
              byteData.getUint8(byteIndex);
        }
      });
      return nScheduleEvents(trackIndex, nativeArray, events.length);
    }

    final Uint8List eventData = Uint8List(events.length * SCHEDULER_EVENT_SIZE);
    events.asMap().forEach((eventIndex, e) {
      final byteData = e.serializeBytes(sampleRate, tempo, frameOffset);
      for (var byteIndex = 0; byteIndex < byteData.lengthInBytes; byteIndex++) {
        eventData[eventIndex * SCHEDULER_EVENT_SIZE + byteIndex] =
            byteData.getUint8(byteIndex);
      }
    });

    final args = <String, dynamic>{
      'trackIndex': trackIndex,
      'eventData': eventData,
      'eventsCount': events.length,
    };
    return await _channel.invokeMethod('scheduleEvents', args);
  }

  static void clearEvents(int trackIndex, int fromTick) {
    if (Platform.isAndroid) {
      return nClearEvents(trackIndex, fromTick);
    }

    final args = <String, dynamic>{
      'trackIndex': trackIndex,
      'fromFrame': fromTick,
    };
    _channel.invokeMethod('clearEvents', args);
  }

  static void play() {
    Platform.isAndroid ? nPlay() : _channel.invokeMethod('enginePlay');
  }

  static void pause() {
    Platform.isAndroid ? nPause() : _channel.invokeMethod('enginePause');
  }
}
