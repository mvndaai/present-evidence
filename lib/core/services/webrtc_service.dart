import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'supabase_service.dart';

/// Describes one connected viewer.
class ViewerInfo {
  final String id;
  final String displayName;
  final RTCPeerConnection? connection;

  const ViewerInfo({
    required this.id,
    required this.displayName,
    this.connection,
  });

  ViewerInfo copyWith({RTCPeerConnection? connection}) => ViewerInfo(
        id: id,
        displayName: displayName,
        connection: connection ?? this.connection,
      );
}

/// WebRTC-based remote presentation service.
///
/// Architecture:
///   Presenter creates a "session" record in Supabase.
///   Each viewer loads the session URL, sees the current slide, and may
///   optionally request a peer connection for content sharing.
///   Signalling (offer / answer / ICE) uses a Supabase realtime channel.
///   Slide-change commands are broadcast over the same channel so every
///   viewer updates simultaneously.
class WebRtcService extends ChangeNotifier {
  WebRtcService(this._client);

  final SupabaseClient _client;

  static const _signalingChannel = 'rtc-signaling';
  static const _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  String? _sessionId;
  bool _isPresenter = false;
  int _currentIndex = 0;
  String? _currentSlideData; // JSON-encoded slide payload
  final Map<String, ViewerInfo> _viewers = {};
  final Map<String, RTCPeerConnection> _peerConnections = {};
  RealtimeChannel? _channel;
  StreamSubscription? _channelSub;
  final List<String> _pendingViewers = [];

  // ---------- Public state ----------
  String? get sessionId => _sessionId;
  bool get isPresenter => _isPresenter;
  int get currentIndex => _currentIndex;
  String? get currentSlideData => _currentSlideData;
  List<ViewerInfo> get viewers => _viewers.values.toList();
  List<String> get pendingViewerIds => List.unmodifiable(_pendingViewers);

  // ---------- Presenter methods ----------

  /// Create a new remote session and return its share URL path.
  Future<String> startSession({required String presentationId}) async {
    const uuid = Uuid();
    _sessionId = uuid.v4();
    _isPresenter = true;
    _currentIndex = 0;

    await _client.from('remote_sessions').insert({
      'id': _sessionId,
      'presentation_id': presentationId,
      'current_index': 0,
      'is_active': true,
    });

    _joinChannel(_sessionId!);
    return _sessionId!;
  }

  /// Advance (or go back) to a specific slide index and notify all viewers.
  Future<void> goToSlide(int index, {Object? slidePayload}) async {
    _currentIndex = index;
    _currentSlideData = slidePayload != null ? jsonEncode(slidePayload) : null;

    await _client.from('remote_sessions').update({
      'current_index': index,
    }).eq('id', _sessionId!);

    _channel?.sendBroadcastMessage(
      event: 'slide_change',
      payload: {
        'index': index,
        'slide_data': _currentSlideData,
      },
    );
    notifyListeners();
  }

  /// Accept a viewer join request.
  Future<void> acceptViewer(String viewerId) async {
    _pendingViewers.remove(viewerId);
    _channel?.sendBroadcastMessage(
      event: 'viewer_accepted',
      payload: {'viewer_id': viewerId, 'current_index': _currentIndex},
    );
    notifyListeners();
  }

  /// Reject a viewer join request.
  void rejectViewer(String viewerId) {
    _pendingViewers.remove(viewerId);
    _channel?.sendBroadcastMessage(
      event: 'viewer_rejected',
      payload: {'viewer_id': viewerId},
    );
    notifyListeners();
  }

  Future<void> endSession() async {
    if (_sessionId == null) return;
    await _client
        .from('remote_sessions')
        .update({'is_active': false}).eq('id', _sessionId!);
    _channel?.sendBroadcastMessage(
      event: 'session_ended',
      payload: {},
    );
    _cleanup();
  }

  // ---------- Viewer methods ----------

  /// Join an existing session as a viewer.
  Future<void> joinSession({
    required String sessionId,
    required String displayName,
  }) async {
    _sessionId = sessionId;
    _isPresenter = false;
    _joinChannel(sessionId);

    // Announce ourselves
    _channel?.sendBroadcastMessage(
      event: 'viewer_join',
      payload: {'display_name': displayName},
    );
  }

  /// Fetch current session state (for initial load).
  Future<Map<String, dynamic>?> fetchSessionState(String sessionId) async {
    final row = await _client
        .from('remote_sessions')
        .select()
        .eq('id', sessionId)
        .maybeSingle();
    return row;
  }

  // ---------- Signalling ----------

  void _joinChannel(String sessionId) {
    _channel = _client.channel('$_signalingChannel:$sessionId');

    _channel!
        .onBroadcast(
          event: 'viewer_join',
          callback: (payload) {
            if (!_isPresenter) return;
            final viewerId = payload['sender_id'] as String? ?? '';
            final displayName = payload['display_name'] as String? ?? 'Viewer';
            _viewers[viewerId] = ViewerInfo(
              id: viewerId,
              displayName: displayName,
            );
            _pendingViewers.add(viewerId);
            notifyListeners();
          },
        )
        .onBroadcast(
          event: 'viewer_accepted',
          callback: (payload) {
            if (_isPresenter) return;
            final viewerId = payload['viewer_id'] as String?;
            if (viewerId == null) return;
            _currentIndex = payload['current_index'] as int? ?? 0;
            notifyListeners();
          },
        )
        .onBroadcast(
          event: 'viewer_rejected',
          callback: (payload) {
            notifyListeners();
          },
        )
        .onBroadcast(
          event: 'slide_change',
          callback: (payload) {
            if (_isPresenter) return;
            _currentIndex = payload['index'] as int? ?? 0;
            _currentSlideData = payload['slide_data'] as String?;
            notifyListeners();
          },
        )
        .onBroadcast(
          event: 'session_ended',
          callback: (_) {
            _cleanup();
            notifyListeners();
          },
        )
        .onBroadcast(
          event: 'rtc_offer',
          callback: (payload) async {
            if (_isPresenter) return;
            await _handleOffer(payload);
          },
        )
        .onBroadcast(
          event: 'rtc_answer',
          callback: (payload) async {
            if (!_isPresenter) return;
            await _handleAnswer(payload);
          },
        )
        .onBroadcast(
          event: 'rtc_ice',
          callback: (payload) async {
            await _handleIce(payload);
          },
        )
        .subscribe();
  }

  // ---------- WebRTC peer connection helpers ----------

  Future<RTCPeerConnection> _createPeerConnection(String peerId) async {
    final config = {
      'iceServers': _iceServers,
    };
    final pc = await createPeerConnection(config);

    pc.onIceCandidate = (candidate) {
      _channel?.sendBroadcastMessage(
        event: 'rtc_ice',
        payload: {
          'target': peerId,
          'candidate': candidate.toMap(),
        },
      );
    };

    pc.onConnectionState = (state) {
      debugPrint('PeerConnection[$peerId] state: $state');
    };

    _peerConnections[peerId] = pc;
    return pc;
  }

  Future<void> _handleOffer(Map<String, dynamic> payload) async {
    final senderId = payload['sender'] as String? ?? '';
    final sdp = payload['sdp'] as String? ?? '';
    final pc = await _createPeerConnection(senderId);
    await pc.setRemoteDescription(
        RTCSessionDescription(sdp, 'offer'));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    _channel?.sendBroadcastMessage(
      event: 'rtc_answer',
      payload: {
        'target': senderId,
        'sdp': answer.sdp,
      },
    );
  }

  Future<void> _handleAnswer(Map<String, dynamic> payload) async {
    final target = payload['target'] as String?;
    if (target == null) return;
    final pc = _peerConnections[target];
    if (pc == null) return;
    final sdp = payload['sdp'] as String? ?? '';
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }

  Future<void> _handleIce(Map<String, dynamic> payload) async {
    final target = payload['target'] as String?;
    if (target == null) return;
    final pc = _peerConnections[target];
    if (pc == null) return;
    final candidateMap =
        Map<String, dynamic>.from(payload['candidate'] as Map);
    await pc.addCandidate(RTCIceCandidate(
      candidateMap['candidate'] as String?,
      candidateMap['sdpMid'] as String?,
      candidateMap['sdpMLineIndex'] as int?,
    ));
  }

  void _cleanup() {
    for (final pc in _peerConnections.values) {
      pc.close();
    }
    _peerConnections.clear();
    _viewers.clear();
    _pendingViewers.clear();
    _channel?.unsubscribe();
    _channelSub?.cancel();
    _channel = null;
    _sessionId = null;
    _currentIndex = 0;
    _currentSlideData = null;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}

final webRtcServiceProvider =
    ChangeNotifierProvider<WebRtcService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return WebRtcService(client);
});
