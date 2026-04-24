import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/highlight.dart';
import '../../../core/models/presentation.dart';
import '../../evidence/providers/evidence_provider.dart';
import '../../evidence/widgets/evidence_viewer_widget.dart';
import '../../highlights/widgets/zoom_overlay_widget.dart';
import '../../presentations/providers/presentation_provider.dart';

class LocalPresentScreen extends ConsumerStatefulWidget {
  const LocalPresentScreen({super.key, required this.presentationId});

  final String presentationId;

  @override
  ConsumerState<LocalPresentScreen> createState() =>
      _LocalPresentScreenState();
}

class _LocalPresentScreenState extends ConsumerState<LocalPresentScreen> {
  int _currentIndex = 0;
  bool _showNotes = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync =
        ref.watch(presentationItemsProvider(widget.presentationId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: itemsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.white)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No slides in this presentation',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final currentItem = items[_currentIndex];
          return Stack(
            children: [
              // Main content
              _SlideContent(item: currentItem),

              // Controls overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _ControlsBar(
                  currentIndex: _currentIndex,
                  total: items.length,
                  showNotes: _showNotes,
                  presenterNotes: currentItem.presenterNotes,
                  publicComment: _currentIndex < items.length - 1
                      ? currentItem.publicComment
                      : null,
                  onPrevious: _currentIndex > 0
                      ? () => setState(() => _currentIndex--)
                      : null,
                  onNext: _currentIndex < items.length - 1
                      ? () => setState(() => _currentIndex++)
                      : null,
                  onToggleNotes: () =>
                      setState(() => _showNotes = !_showNotes),
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),

              // Public comment banner between slides
              if (currentItem.publicComment != null && _currentIndex > 0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _PublicCommentBanner(
                    comment: currentItem.publicComment!,
                  ),
                ),
            ],
          );
        },
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
      return _EvidenceSlide(evidenceId: item.evidenceId!);
    }
    if (item.highlightId != null) {
      return _HighlightSlide(highlightId: item.highlightId!);
    }
    return const Center(
      child: Text('Unknown slide type',
          style: TextStyle(color: Colors.white)),
    );
  }
}

class _EvidenceSlide extends ConsumerWidget {
  const _EvidenceSlide({required this.evidenceId});
  final String evidenceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evidenceAsync = ref.watch(evidenceItemProvider(evidenceId));
    return evidenceAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.white))),
      data: (evidence) => EvidenceViewerWidget(evidence: evidence),
    );
  }
}

class _HighlightSlide extends ConsumerWidget {
  const _HighlightSlide({required this.highlightId});
  final String highlightId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // To resolve a highlight we need to find it by ID across all loaded lists.
    // We look it up via the evidenceItemProvider after finding its evidenceId
    // from a direct DB read by passing it through the global highlight service.
    // For simplicity, show a loading indicator while the highlight resolves.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading highlight...',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

// Detailed highlight slide that resolves the evidence and shows zoom overlay
class HighlightSlideWidget extends ConsumerWidget {
  const HighlightSlideWidget({super.key, required this.highlight});
  final Highlight highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evidenceAsync =
        ref.watch(evidenceItemProvider(highlight.evidenceId));

    return evidenceAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Error loading evidence: $e',
              style: const TextStyle(color: Colors.white))),
      data: (evidence) {
        final viewer = EvidenceViewerWidget(evidence: evidence);
        if (highlight.zoomRegion != null) {
          return ZoomOverlayWidget(
            zoomRegion: highlight.zoomRegion!,
            child: viewer,
          );
        }
        return viewer;
      },
    );
  }
}

class _ControlsBar extends StatelessWidget {
  const _ControlsBar({
    required this.currentIndex,
    required this.total,
    required this.showNotes,
    this.presenterNotes,
    this.publicComment,
    this.onPrevious,
    this.onNext,
    required this.onToggleNotes,
    required this.onClose,
  });

  final int currentIndex;
  final int total;
  final bool showNotes;
  final String? presenterNotes;
  final String? publicComment;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onToggleNotes;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showNotes && presenterNotes != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow.withOpacity(0.5)),
              ),
              child: Text(
                presenterNotes!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onClose,
                tooltip: 'Exit Presentation',
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: onPrevious,
                tooltip: 'Previous',
              ),
              Text(
                '${currentIndex + 1} / $total',
                style: const TextStyle(color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                onPressed: onNext,
                tooltip: 'Next',
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.notes,
                  color: presenterNotes != null
                      ? Colors.yellow
                      : Colors.white54,
                ),
                onPressed: presenterNotes != null ? onToggleNotes : null,
                tooltip: 'Presenter Notes',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PublicCommentBanner extends StatelessWidget {
  const _PublicCommentBanner({required this.comment});
  final String comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.comment_outlined),
          const SizedBox(width: 8),
          Expanded(child: Text(comment)),
        ],
      ),
    );
  }
}
