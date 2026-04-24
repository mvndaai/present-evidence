import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/services/webrtc_service.dart';
import '../../../core/models/presentation.dart';
import '../../../core/services/presentation_service.dart';
import '../../evidence/providers/evidence_provider.dart';
import '../../evidence/widgets/evidence_viewer_widget.dart';

class RemoteViewerScreen extends ConsumerStatefulWidget {
  const RemoteViewerScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<RemoteViewerScreen> createState() =>
      _RemoteViewerScreenState();
}

class _RemoteViewerScreenState extends ConsumerState<RemoteViewerScreen> {
  String? _displayName;
  bool _joined = false;
  bool _rejected = false;
  String? _presentationId;
  List<PresentationItem> _items = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _fetchSessionInfo();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _fetchSessionInfo() async {
    final rtc = ref.read(webRtcServiceProvider);
    final state = await rtc.fetchSessionState(widget.sessionId);
    if (state != null) {
      setState(() {
        _presentationId = state['presentation_id'] as String?;
      });
    }
  }

  Future<void> _joinSession() async {
    if (_displayName == null || _displayName!.isEmpty) return;
    final rtc = ref.read(webRtcServiceProvider);
    await rtc.joinSession(
      sessionId: widget.sessionId,
      displayName: _displayName!,
    );
    setState(() => _joined = true);

    // Load presentation items for display
    if (_presentationId != null) {
      final items = await ref
          .read(presentationServiceProvider)
          .fetchItems(_presentationId!);
      setState(() => _items = items);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rtcService = ref.watch(webRtcServiceProvider);

    if (!_joined) {
      return _JoinScreen(
        onJoin: (name) {
          _displayName = name;
          _joinSession();
        },
      );
    }

    if (_rejected) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Your request to join was rejected.',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    final currentIndex = rtcService.currentIndex;
    final isEnded = rtcService.sessionId == null;

    if (isEnded) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stop_circle_outlined,
                  color: Colors.white, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Presentation Ended',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Current slide content
          if (_items.isNotEmpty && currentIndex < _items.length)
            _ViewerSlide(item: _items[currentIndex])
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Waiting for presenter...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),

          // Slide indicator
          if (_items.isNotEmpty)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${currentIndex + 1} / ${_items.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _JoinScreen extends StatefulWidget {
  const _JoinScreen({required this.onJoin});

  final ValueChanged<String> onJoin;

  @override
  State<_JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<_JoinScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cast_connected_outlined,
                  size: 64, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'Join Presentation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Your Display Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white38),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onSubmitted: (_) =>
                    widget.onJoin(_controller.text.trim()),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => widget.onJoin(_controller.text.trim()),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Join'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerSlide extends ConsumerWidget {
  const _ViewerSlide({required this.item});
  final PresentationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.evidenceId != null) {
      final evidenceAsync =
          ref.watch(evidenceItemProvider(item.evidenceId!));
      return evidenceAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.white))),
        data: (evidence) => EvidenceViewerWidget(evidence: evidence),
      );
    }
    return const Center(
      child: Text('Loading...',
          style: TextStyle(color: Colors.white)),
    );
  }
}
