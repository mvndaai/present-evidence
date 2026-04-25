import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/presentation.dart';
import '../../../core/services/webrtc_service.dart';
import '../../evidence/providers/evidence_provider.dart';
import '../../evidence/widgets/evidence_viewer_widget.dart';
import '../../presentations/providers/presentation_provider.dart';

class RemotePresentScreen extends ConsumerStatefulWidget {
  const RemotePresentScreen({super.key, required this.presentationId});

  final String presentationId;

  @override
  ConsumerState<RemotePresentScreen> createState() =>
      _RemotePresentScreenState();
}

class _RemotePresentScreenState extends ConsumerState<RemotePresentScreen> {
  String? _sessionId;
  bool _isStarting = false;
  int _currentIndex = 0;
  List<PresentationItem> _items = [];
  bool _showNotes = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ref.read(webRtcServiceProvider).endSession();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() => _isStarting = true);
    try {
      final id = await ref.read(webRtcServiceProvider).startSession(
        presentationId: widget.presentationId,
      );
      setState(() {
        _sessionId = id;
        _isStarting = false;
      });
    } catch (e) {
      setState(() => _isStarting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start session: $e')),
        );
      }
    }
  }

  Future<void> _goToSlide(int index) async {
    if (index < 0 || index >= _items.length) return;
    setState(() => _currentIndex = index);
    await ref.read(webRtcServiceProvider).goToSlide(
          index,
          slidePayload: {'item_id': _items[index].id},
        );
  }

  @override
  Widget build(BuildContext context) {
    final rtcService = ref.watch(webRtcServiceProvider);
    final itemsAsync =
        ref.watch(presentationItemsProvider(widget.presentationId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: itemsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.white))),
        data: (items) {
          _items = items;

          if (_sessionId == null) {
            return _StartSessionView(
              isStarting: _isStarting,
              onStart: _startSession,
              onCancel: () => Navigator.of(context).pop(),
            );
          }

          return Stack(
            children: [
              // Main slide content
              if (items.isNotEmpty)
                _SlideContent(item: items[_currentIndex]),

              // Presenter toolbar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _PresenterBar(
                  sessionId: _sessionId!,
                  currentIndex: _currentIndex,
                  total: items.length,
                  viewers: rtcService.viewers,
                  pendingViewers: rtcService.pendingViewerIds,
                  showNotes: _showNotes,
                  presenterNotes: items.isNotEmpty
                      ? items[_currentIndex].presenterNotes
                      : null,
                  onPrevious: _currentIndex > 0
                      ? () => _goToSlide(_currentIndex - 1)
                      : null,
                  onNext: _currentIndex < items.length - 1
                      ? () => _goToSlide(_currentIndex + 1)
                      : null,
                  onGoToSlide: (index) => _showSlideChooser(context, items),
                  onToggleNotes: () =>
                      setState(() => _showNotes = !_showNotes),
                  onAcceptViewer: (id) {
                    ref.read(webRtcServiceProvider).acceptViewer(id);
                  },
                  onRejectViewer: (id) {
                    ref.read(webRtcServiceProvider).rejectViewer(id);
                  },
                  onEndSession: () async {
                    await ref.read(webRtcServiceProvider).endSession();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSlideChooser(BuildContext context, List<PresentationItem> items) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) => ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text(items[i].evidenceId ?? items[i].highlightId ?? ''),
          selected: i == _currentIndex,
          onTap: () {
            Navigator.of(ctx).pop();
            _goToSlide(i);
          },
        ),
      ),
    );
  }
}

class _StartSessionView extends StatelessWidget {
  const _StartSessionView({
    required this.isStarting,
    required this.onStart,
    required this.onCancel,
  });

  final bool isStarting;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cast_outlined,
              size: 64, color: Colors.white),
          const SizedBox(height: 24),
          const Text(
            'Start Remote Presentation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'A shareable link will be generated.\nViewers can watch in real-time via WebRTC.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (isStarting)
            const CircularProgressIndicator()
          else ...[
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Session'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white)),
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SlideContent extends ConsumerWidget {
  const _SlideContent({required this.item});
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
      child: Text('Loading slide...',
          style: TextStyle(color: Colors.white)),
    );
  }
}

class _PresenterBar extends StatelessWidget {
  const _PresenterBar({
    required this.sessionId,
    required this.currentIndex,
    required this.total,
    required this.viewers,
    required this.pendingViewers,
    required this.showNotes,
    this.presenterNotes,
    this.onPrevious,
    this.onNext,
    required this.onGoToSlide,
    required this.onToggleNotes,
    required this.onAcceptViewer,
    required this.onRejectViewer,
    required this.onEndSession,
  });

  final String sessionId;
  final int currentIndex;
  final int total;
  final List<dynamic> viewers;
  final List<String> pendingViewers;
  final bool showNotes;
  final String? presenterNotes;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onGoToSlide;
  final VoidCallback onToggleNotes;
  final ValueChanged<String> onAcceptViewer;
  final ValueChanged<String> onRejectViewer;
  final VoidCallback onEndSession;

  @override
  Widget build(BuildContext context) {
    final shareUrl = 'present-evidence://watch/$sessionId';

    return Container(
      color: Colors.black.withOpacity(0.85),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pending viewer requests
          if (pendingViewers.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Viewer Requests:',
                    style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold),
                  ),
                  ...pendingViewers.map((id) => Row(
                        children: [
                          Expanded(
                            child: Text(id,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: () => onAcceptViewer(id),
                            child: const Text('Accept',
                                style:
                                    TextStyle(color: Colors.green)),
                          ),
                          TextButton(
                            onPressed: () => onRejectViewer(id),
                            child: const Text('Reject',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      )),
                ],
              ),
            ),

          // Notes
          if (showNotes && presenterNotes != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                presenterNotes!,
                style: const TextStyle(color: Colors.white),
              ),
            ),

          // Share URL
          Row(
            children: [
              const Icon(Icons.link, color: Colors.white54, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  shareUrl,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white54, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: shareUrl));
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Controls row
          Row(
            children: [
              // End session
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined,
                    color: Colors.red),
                onPressed: onEndSession,
                tooltip: 'End Session',
              ),

              // Viewers count
              TextButton.icon(
                onPressed: null,
                icon: const Icon(Icons.people_outline,
                    color: Colors.white54),
                label: Text(
                  '${viewers.length}',
                  style: const TextStyle(color: Colors.white54),
                ),
              ),

              const Spacer(),

              // Previous
              IconButton(
                icon: const Icon(Icons.skip_previous,
                    color: Colors.white),
                onPressed: onPrevious,
              ),
              Text(
                '${currentIndex + 1} / $total',
                style: const TextStyle(color: Colors.white),
              ),
              // Next
              IconButton(
                icon: const Icon(Icons.skip_next,
                    color: Colors.white),
                onPressed: onNext,
              ),

              // Jump to slide
              IconButton(
                icon: const Icon(Icons.list, color: Colors.white),
                onPressed: () => onGoToSlide(currentIndex),
                tooltip: 'Jump to slide',
              ),

              const Spacer(),

              // Notes toggle
              IconButton(
                icon: Icon(
                  Icons.notes,
                  color: presenterNotes != null
                      ? Colors.yellow
                      : Colors.white54,
                ),
                onPressed: onToggleNotes,
                tooltip: 'Presenter Notes',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
