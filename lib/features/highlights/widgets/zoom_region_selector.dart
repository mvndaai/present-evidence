import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/evidence.dart';
import '../../../core/models/highlight.dart';
import '../../evidence/providers/evidence_provider.dart';

/// Default aspect ratio used for the zoom-region preview canvas.
const _kPreviewAspectRatio = 16.0 / 9.0;

/// Allows the user to drag-select a rectangular zoom region over a preview.
class ZoomRegionSelector extends ConsumerStatefulWidget {
  const ZoomRegionSelector({
    super.key,
    required this.evidenceId,
    required this.evidenceType,
    this.initialRegion,
    required this.onRegionChanged,
  });

  final String evidenceId;
  final EvidenceType evidenceType;
  final ZoomRegion? initialRegion;
  final ValueChanged<ZoomRegion?> onRegionChanged;

  @override
  ConsumerState<ZoomRegionSelector> createState() =>
      _ZoomRegionSelectorState();
}

class _ZoomRegionSelectorState extends ConsumerState<ZoomRegionSelector> {
  Offset? _startLocal;
  Offset? _endLocal;
  Size _boxSize = Size.zero;
  ZoomRegion? _region;

  @override
  void initState() {
    super.initState();
    _region = widget.initialRegion;
  }

  void _onPanStart(DragStartDetails details) {
    _startLocal = details.localPosition;
    _endLocal = details.localPosition;
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _endLocal = details.localPosition;
    setState(() {});
  }

  void _onPanEnd(DragEndDetails _) {
    if (_startLocal == null || _endLocal == null || _boxSize == Size.zero) {
      return;
    }
    final w = _boxSize.width;
    final h = _boxSize.height;

    final l = (_startLocal!.dx / w).clamp(0.0, 1.0);
    final t = (_startLocal!.dy / h).clamp(0.0, 1.0);
    final r = (_endLocal!.dx / w).clamp(0.0, 1.0);
    final b = (_endLocal!.dy / h).clamp(0.0, 1.0);

    _region = ZoomRegion(
      left: l < r ? l : r,
      top: t < b ? t : b,
      right: l < r ? r : l,
      bottom: t < b ? b : t,
    );
    _startLocal = null;
    _endLocal = null;
    widget.onRegionChanged(_region);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final evidenceAsync = ref.watch(evidenceItemProvider(widget.evidenceId));

    return evidenceAsync.when(
      loading: () => const AspectRatio(
        aspectRatio: _kPreviewAspectRatio,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const AspectRatio(
        aspectRatio: _kPreviewAspectRatio,
        child: Center(child: Icon(Icons.image_not_supported)),
      ),
      data: (evidence) {
        final urlAsync = ref.watch(evidenceUrlProvider(evidence));
        return urlAsync.when(
          loading: () => const AspectRatio(
            aspectRatio: _kPreviewAspectRatio,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const AspectRatio(
            aspectRatio: _kPreviewAspectRatio,
            child: Center(child: Icon(Icons.image_not_supported)),
          ),
          data: (url) => AspectRatio(
            aspectRatio: _kPreviewAspectRatio,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _boxSize = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Center(child: Icon(Icons.broken_image)),
                      ),
                      if (_startLocal != null && _endLocal != null)
                        _buildSelectionRect(
                            _startLocal!, _endLocal!, context),
                      if (_region != null && _startLocal == null)
                        _buildSavedRect(_region!, _boxSize, context),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionRect(
      Offset a, Offset b, BuildContext context) {
    final left = a.dx < b.dx ? a.dx : b.dx;
    final top = a.dy < b.dy ? a.dy : b.dy;
    final width = (a.dx - b.dx).abs();
    final height = (a.dy - b.dy).abs();

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
    );
  }

  Widget _buildSavedRect(
      ZoomRegion r, Size boxSize, BuildContext context) {
    return Positioned(
      left: r.left * boxSize.width,
      top: r.top * boxSize.height,
      width: (r.right - r.left) * boxSize.width,
      height: (r.bottom - r.top) * boxSize.height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.tertiary,
            width: 2,
          ),
          color:
              Theme.of(context).colorScheme.tertiary.withOpacity(0.2),
        ),
      ),
    );
  }
}
