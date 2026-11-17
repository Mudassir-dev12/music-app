import 'dart:async';

import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../api/errors.dart';
import '../api/models.dart';
import '../api/music_api.dart';
import '../core/platform/download_store.dart';
import '../core/platform/network_type.dart';
import 'download_models.dart';

typedef DurationResolver = Future<Duration?> Function(String filePath);

class DownloadManager {
  final DownloadStore _store;
  final MusicApi _musicApi;
  final ApiClient _apiClient;
  final NetworkTypeDetector _networkDetector;
  final DurationResolver? _durationResolver;

  DownloadManifest _manifest = const DownloadManifest();
  final List<DownloadItem> _queue = [];
  final Map<String, CancelToken> _cancelTokens = {};
  final Set<String> _activeDownloads = {};
  final Map<String, int> _corruptRetries = {};

  bool _isPaused = false;
  bool _wifiOnly = true;
  int _storageCapMb = 2048; // 2 GB default, 0 = none
  DateTime? _quotaResetTime;

  final _queueController = StreamController<List<DownloadItem>>.broadcast();
  final _manifestController = StreamController<DownloadManifest>.broadcast();

  DownloadManager({
    required DownloadStore store,
    required MusicApi musicApi,
    required ApiClient apiClient,
    NetworkTypeDetector? networkDetector,
    DurationResolver? durationResolver,
  })  : _store = store,
        _musicApi = musicApi,
        _apiClient = apiClient,
        _networkDetector = networkDetector ?? NetworkTypeDetector(),
        _durationResolver = durationResolver;

  Stream<List<DownloadItem>> get queueStream => _queueController.stream;
  Stream<DownloadManifest> get manifestStream => _manifestController.stream;

  List<DownloadItem> get queue => List.unmodifiable(_queue);
  DownloadManifest get manifest => _manifest;
  bool get isPaused => _isPaused;
  bool get wifiOnly => _wifiOnly;
  int get storageCapMb => _storageCapMb;
  DateTime? get quotaResetTime => _quotaResetTime;

  Future<void> init({bool wifiOnly = true, int storageCapMb = 2048}) async {
    _wifiOnly = wifiOnly;
    _storageCapMb = storageCapMb;
    await _store.init();
    await _loadManifest();
    await _cleanupOrphans();
  }

  void setWifiOnly(bool value) {
    _wifiOnly = value;
    if (!_isPaused) {
      _processQueue();
    }
  }

  void setStorageCapMb(int value) {
    _storageCapMb = value;
    if (!_isPaused) {
      _processQueue();
    }
  }

  Future<void> _loadManifest() async {
    if (!_store.isSupported) return;
    try {
      final content = await _store.readManifest();
      if (content != null && content.isNotEmpty) {
        _manifest = DownloadManifest.decode(content);
      } else {
        _manifest = const DownloadManifest();
      }
    } catch (_) {
      // Corrupt manifest -> archive and rebuild
      await _store.archiveCorruptManifest();
      final scannedIds = await _store.listDownloadedVideoIds();
      final rebuiltTracks = <String, ManifestTrack>{};
      for (final vid in scannedIds) {
        final size = await _store.sizeOf(vid);
        rebuiltTracks[vid] = ManifestTrack(
          videoId: vid,
          title: 'Track $vid',
          artist: 'Unknown Artist',
          durationSeconds: 0,
          byteSize: size,
          downloadedAt: DateTime.now(),
          collections: {'manual'},
        );
      }
      _manifest = DownloadManifest(tracks: rebuiltTracks);
      await _store.writeManifest(_manifest.encode());
    }
    _manifestController.add(_manifest);
  }

  Future<void> _saveManifest() async {
    if (!_store.isSupported) return;
    await _store.writeManifest(_manifest.encode());
    _manifestController.add(_manifest);
  }

  Future<void> _cleanupOrphans() async {
    if (!_store.isSupported) return;
    final active = _queue.map((e) => e.videoId).toSet();
    await _store.cleanupOrphanParts(active);
  }

  bool isDownloaded(String videoId) {
    return _manifest.tracks.containsKey(videoId);
  }

  bool isQueuedOrDownloading(String videoId) {
    return _queue.any((item) =>
        item.videoId == videoId &&
        (item.status == DownloadStatus.queued ||
            item.status == DownloadStatus.downloading));
  }

  Future<void> enqueueTrack(
    Track track, {
    String collection = 'manual',
    bool priority = false,
  }) async {
    final videoId = track.videoId;

    // Idempotent: already downloaded
    if (_manifest.tracks.containsKey(videoId)) {
      final existing = _manifest.tracks[videoId]!;
      if (!existing.collections.contains(collection)) {
        final updatedCollections = Set<String>.from(existing.collections)..add(collection);
        _manifest = DownloadManifest(
          tracks: Map<String, ManifestTrack>.from(_manifest.tracks)
            ..[videoId] = existing.copyWith(collections: updatedCollections),
        );
        await _saveManifest();
      }
      return;
    }

    // Already in queue
    final existingIdx = _queue.indexWhere((item) => item.videoId == videoId);
    if (existingIdx != -1) {
      final existing = _queue[existingIdx];
      final updatedCollections = Set<String>.from(existing.collections)..add(collection);
      if (priority && existingIdx > 0) {
        _queue.removeAt(existingIdx);
        _queue.insert(0, existing.copyWith(collections: updatedCollections));
      } else {
        _queue[existingIdx] = existing.copyWith(collections: updatedCollections);
      }
      _emitQueue();
      return;
    }

    final item = DownloadItem(
      videoId: videoId,
      title: track.title,
      artist: track.artist,
      album: track.album,
      durationSeconds: track.durationSeconds,
      thumbnailUrl: track.thumbnail,
      status: DownloadStatus.queued,
      collections: {collection},
    );

    if (priority) {
      _queue.insert(0, item);
    } else {
      _queue.add(item);
    }
    _emitQueue();
    await _processQueue();
  }

  Future<void> enqueueTracks(List<Track> tracks, {String collection = 'manual'}) async {
    for (final t in tracks) {
      await enqueueTrack(t, collection: collection);
    }
  }

  void downloadNext(String videoId) {
    final idx = _queue.indexWhere((e) => e.videoId == videoId);
    if (idx > 0) {
      final item = _queue.removeAt(idx);
      _queue.insert(0, item);
      _emitQueue();
      _processQueue();
    }
  }

  void pause(String videoId) {
    final idx = _queue.indexWhere((e) => e.videoId == videoId);
    if (idx != -1) {
      final item = _queue[idx];
      if (item.status == DownloadStatus.downloading) {
        _cancelTokens[videoId]?.cancel('paused');
        _cancelTokens.remove(videoId);
      }
      _queue[idx] = item.copyWith(status: DownloadStatus.paused);
      _activeDownloads.remove(videoId);
      _emitQueue();
      _processQueue();
    }
  }

  void resume(String videoId) {
    final idx = _queue.indexWhere((e) => e.videoId == videoId);
    if (idx != -1) {
      final item = _queue[idx];
      _queue[idx] = item.copyWith(status: DownloadStatus.queued, failReason: null);
      _emitQueue();
      _processQueue();
    }
  }

  void cancel(String videoId) {
    _cancelTokens[videoId]?.cancel('canceled');
    _cancelTokens.remove(videoId);
    _activeDownloads.remove(videoId);
    _queue.removeWhere((e) => e.videoId == videoId);
    _emitQueue();
    _store.delete(videoId);
    _processQueue();
  }

  void pauseAll() {
    _isPaused = true;
    for (int i = 0; i < _queue.length; i++) {
      final item = _queue[i];
      if (item.status == DownloadStatus.downloading ||
          item.status == DownloadStatus.queued) {
        _cancelTokens[item.videoId]?.cancel('paused');
        _cancelTokens.remove(item.videoId);
        _queue[i] = item.copyWith(status: DownloadStatus.paused);
      }
    }
    _activeDownloads.clear();
    _emitQueue();
  }

  void resumeAll() {
    _isPaused = false;
    for (int i = 0; i < _queue.length; i++) {
      final item = _queue[i];
      if (item.status == DownloadStatus.paused ||
          item.status == DownloadStatus.failed) {
        _queue[i] = item.copyWith(status: DownloadStatus.queued, failReason: null);
      }
    }
    _emitQueue();
    _processQueue();
  }

  void onConnectivityChanged(bool isOnline) {
    if (!isOnline) {
      if (!_isPaused) {
        pauseAll();
      }
    } else {
      if (_isPaused) {
        resumeAll();
      } else {
        _processQueue();
      }
    }
  }

  Future<void> removeDownloadedTrack(String videoId) async {
    _manifest = DownloadManifest(
      tracks: Map<String, ManifestTrack>.from(_manifest.tracks)..remove(videoId),
    );
    await _saveManifest();
    await _store.delete(videoId);
  }

  Future<void> removeCollection(String collectionKey, {bool removeFiles = true}) async {
    final tracksToRemove = <String>[];
    final updatedTracks = Map<String, ManifestTrack>.from(_manifest.tracks);

    for (final entry in _manifest.tracks.entries) {
      final track = entry.value;
      if (track.collections.contains(collectionKey)) {
        final newCollections = Set<String>.from(track.collections)..remove(collectionKey);
        if (newCollections.isEmpty && removeFiles) {
          tracksToRemove.add(entry.key);
          updatedTracks.remove(entry.key);
        } else {
          updatedTracks[entry.key] = track.copyWith(collections: newCollections);
        }
      }
    }

    _manifest = DownloadManifest(tracks: updatedTracks);
    await _saveManifest();

    if (removeFiles) {
      for (final vid in tracksToRemove) {
        await _store.delete(vid);
      }
    }
  }

  Future<void> removeAllDownloads() async {
    pauseAll();
    _queue.clear();
    _emitQueue();
    _manifest = const DownloadManifest();
    await _saveManifest();
    await _store.deleteAllDownloads();
  }

  void _emitQueue() {
    if (!_queueController.isClosed) {
      _queueController.add(List.unmodifiable(_queue));
    }
  }

  bool _isProcessing = false;
  bool _needsRecheck = false;
  Completer<void>? _processingCompleter;

  Future<void> _processQueue() async {
    if (_isPaused) return;
    if (_isProcessing) {
      _needsRecheck = true;
      return _processingCompleter?.future;
    }
    _isProcessing = true;
    _processingCompleter = Completer<void>();
    try {
      do {
        _needsRecheck = false;

        // Check platform support
        if (!_store.isSupported) {
          for (int i = 0; i < _queue.length; i++) {
            if (_queue[i].status == DownloadStatus.queued) {
              _queue[i] = _queue[i].copyWith(
                status: DownloadStatus.failed,
                failReason: FailReason.unsupported,
                errorMessage: 'Downloads are available in the mobile app.',
              );
            }
          }
          _emitQueue();
          return;
        }

        // Check Wi-Fi restriction
        final allowedNetwork = await _networkDetector.isNetworkAllowed(wifiOnly: _wifiOnly);
        if (!allowedNetwork) return;

        // Check quota backoff
        if (_quotaResetTime != null && DateTime.now().isBefore(_quotaResetTime!)) {
          return;
        } else {
          _quotaResetTime = null;
        }

        // Concurrency limit: 2
        while (_activeDownloads.length < 2) {
          final nextIdx = _queue.indexWhere((e) => e.status == DownloadStatus.queued);
          if (nextIdx == -1) break;

          final item = _queue[nextIdx];
          final videoId = item.videoId;

          // Storage cap check before starting
          if (_storageCapMb > 0) {
            final totalUsed = await _store.totalBytesUsed();
            final capBytes = _storageCapMb * 1024 * 1024;
            if (totalUsed >= capBytes) {
              _failItem(videoId, FailReason.storageFull, 'Storage cap exceeded');
              pauseAll();
              return;
            }
          }

          final currentIdx = _queue.indexWhere((e) => e.videoId == videoId);
          if (currentIdx == -1 || _queue[currentIdx].status != DownloadStatus.queued) {
            continue;
          }

          _activeDownloads.add(videoId);
          _queue[currentIdx] = item.copyWith(status: DownloadStatus.downloading);
          _emitQueue();

          // Launch single download in background
          _startDownload(item);
        }
      } while (_needsRecheck);
    } finally {
      _isProcessing = false;
      _processingCompleter?.complete();
      _processingCompleter = null;
    }
  }

  Future<void> _startDownload(DownloadItem item) async {
    final videoId = item.videoId;
    final cancelToken = CancelToken();
    _cancelTokens[videoId] = cancelToken;

    int attempts = 0;
    const retryDelays = [
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 45),
    ];

    while (attempts <= 4) {
      if (cancelToken.isCancelled) {
        _activeDownloads.remove(videoId);
        _cancelTokens.remove(videoId);
        return;
      }

      try {
        // Storage cap check
        if (_storageCapMb > 0) {
          final totalUsed = await _store.totalBytesUsed();
          final capBytes = _storageCapMb * 1024 * 1024;
          if (totalUsed >= capBytes) {
            _failItem(videoId, FailReason.storageFull, 'Storage cap exceeded');
            pauseAll();
            return;
          }
        }

        // Get download ticket
        final ticket = await _musicApi.getAudioTicket(videoId, purpose: 'download');
        if (cancelToken.isCancelled) return;

        // Check offset for Range resume
        final startOffset = await _store.partSizeOf(videoId);
        final writer = await _store.openWriter(videoId, startOffset: startOffset);

        final headers = <String, String>{};
        if (startOffset > 0) {
          headers['Range'] = 'bytes=$startOffset-';
        }

        final resp = await _apiClient.getStream(
          ticket.url,
          headers: headers,
          cancelToken: cancelToken,
        );

        int totalExpected = 0;
        final cl = resp.headers.value('content-length');
        if (cl != null) {
          totalExpected = (int.tryParse(cl) ?? 0) + startOffset;
        }

        _updateProgress(videoId, startOffset, totalExpected);

        int currentDownloaded = startOffset;
        final stream = resp.data?.stream;
        if (stream != null) {
          await for (final chunk in stream) {
            if (cancelToken.isCancelled) {
              await writer.close();
              return;
            }
            await writer.add(chunk);
            currentDownloaded += chunk.length;
            _updateProgress(videoId, currentDownloaded, totalExpected);
          }
        }
        await writer.close();

        // Finalize atomically
        await _store.finalize(videoId, extension: 'm4a');

        // Integrity verification
        if (_durationResolver != null && item.durationSeconds != null && item.durationSeconds! > 0) {
          final filePath = await _store.pathFor(videoId);
          if (filePath != null) {
            final actualDuration = await _durationResolver!(filePath);
            if (actualDuration != null) {
              final diff = (actualDuration.inSeconds - item.durationSeconds!).abs();
              if (diff > 5) {
                await _store.delete(videoId);
                final retryCount = _corruptRetries[videoId] ?? 0;
                if (retryCount < 1) {
                  _corruptRetries[videoId] = retryCount + 1;
                  // Retry once
                  attempts++;
                  continue;
                } else {
                  _failItem(videoId, FailReason.corrupt, 'Duration mismatch');
                  return;
                }
              }
            }
          }
        }

        // Add to manifest
        final fileSize = await _store.sizeOf(videoId);
        final manifestTrack = ManifestTrack(
          videoId: videoId,
          title: item.title,
          artist: item.artist,
          album: item.album,
          durationSeconds: item.durationSeconds ?? 0,
          thumbnailFile: item.thumbnailUrl,
          byteSize: fileSize,
          downloadedAt: DateTime.now(),
          collections: item.collections,
        );

        _manifest = DownloadManifest(
          tracks: Map<String, ManifestTrack>.from(_manifest.tracks)..[videoId] = manifestTrack,
        );
        await _saveManifest();

        // Complete
        _activeDownloads.remove(videoId);
        _cancelTokens.remove(videoId);
        _queue.removeWhere((e) => e.videoId == videoId);
        _emitQueue();
        _processQueue();
        return;

      } on RateLimitError catch (e) {
        _activeDownloads.remove(videoId);
        _cancelTokens.remove(videoId);
        final retrySeconds = e.retryAfterSeconds > 0 ? e.retryAfterSeconds : 60;
        _quotaResetTime = DateTime.now().add(Duration(seconds: retrySeconds));
        _failItem(
          videoId,
          FailReason.quota,
          e.message,
          retryAfter: _quotaResetTime,
        );
        pauseAll();
        return;

      } on ApiError catch (e) {
        if (e is ServerError && e.statusCode == 413) {
          _failItem(videoId, FailReason.tooLarge, e.message);
          return;
        } else if (e is ServerError && (e.statusCode == 404 || e.statusCode == 502)) {
          _failItem(videoId, FailReason.unavailable, e.message);
          return;
        }

        // Network / 5xx retries with backoff
        attempts++;
        if (attempts > 4) {
          _failItem(videoId, FailReason.network, e.message);
          return;
        }
        await Future<void>.delayed(retryDelays[attempts - 1]);

      } catch (e) {
        if (cancelToken.isCancelled) return;
        attempts++;
        if (attempts > 4) {
          _failItem(videoId, FailReason.network, e.toString());
          return;
        }
        await Future<void>.delayed(retryDelays[attempts - 1]);
      }
    }
  }

  void _updateProgress(String videoId, int downloaded, int total) {
    final idx = _queue.indexWhere((e) => e.videoId == videoId);
    if (idx != -1) {
      _queue[idx] = _queue[idx].copyWith(
        bytesDownloaded: downloaded,
        totalBytes: total,
      );
      _emitQueue();
    }
  }

  void _failItem(
    String videoId,
    FailReason reason,
    String message, {
    DateTime? retryAfter,
  }) {
    _activeDownloads.remove(videoId);
    _cancelTokens.remove(videoId);
    final idx = _queue.indexWhere((e) => e.videoId == videoId);
    if (idx != -1) {
      _queue[idx] = _queue[idx].copyWith(
        status: DownloadStatus.failed,
        failReason: reason,
        errorMessage: message,
        retryAfter: retryAfter,
      );
      _emitQueue();
    }
    _processQueue();
  }

  void dispose() {
    _isPaused = true;
    for (final ct in _cancelTokens.values) {
      ct.cancel('disposed');
    }
    _cancelTokens.clear();
    _activeDownloads.clear();
    if (!_queueController.isClosed) {
      _queueController.close();
    }
    if (!_manifestController.isClosed) {
      _manifestController.close();
    }
  }
}
