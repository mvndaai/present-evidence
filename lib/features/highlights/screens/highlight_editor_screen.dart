import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/evidence.dart';
import '../../../core/models/highlight.dart';
import '../providers/highlight_provider.dart';
import '../../evidence/providers/evidence_provider.dart';
import '../widgets/zoom_region_selector.dart';

class HighlightEditorScreen extends ConsumerStatefulWidget {
  const HighlightEditorScreen({
    super.key,
    required this.evidenceId,
    this.highlightId,
  });

  final String evidenceId;
  final String? highlightId;

  @override
  ConsumerState<HighlightEditorScreen> createState() =>
      _HighlightEditorScreenState();
}

class _HighlightEditorScreenState
    extends ConsumerState<HighlightEditorScreen> {
  final _nameController = TextEditingController();

  // Video clip
  Duration _clipStart = Duration.zero;
  Duration _clipEnd = const Duration(seconds: 30);

  // PDF pages
  int _startPage = 1;
  int _endPage = 1;

  // Zoom region (fractional)
  ZoomRegion? _zoomRegion;

  bool _isSaving = false;
  Highlight? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.highlightId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    // Fetch from already-loaded list
    final list = ref.read(highlightsProvider(widget.evidenceId)).value ?? [];
    final match =
        list.where((h) => h.id == widget.highlightId).firstOrNull;
    if (match != null) {
      setState(() {
        _existing = match;
        _nameController.text = match.name;
        _clipStart = match.clipStart ?? Duration.zero;
        _clipEnd = match.clipEnd ?? const Duration(seconds: 30);
        _startPage = match.startPage ?? 1;
        _endPage = match.endPage ?? 1;
        _zoomRegion = match.zoomRegion;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final evidenceAsync = ref.watch(evidenceItemProvider(widget.evidenceId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.highlightId == null
            ? 'Add Highlight'
            : 'Edit Highlight'),
      ),
      body: evidenceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (evidence) => _buildEditor(context, evidence),
      ),
    );
  }

  Widget _buildEditor(BuildContext context, Evidence evidence) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Highlight Name',
            hintText: 'e.g. Key moment at 2:15',
            prefixIcon: Icon(Icons.label_outline),
          ),
        ),
        const SizedBox(height: 24),

        // Type-specific controls
        if (evidence.type == EvidenceType.video) ...[
          _SectionTitle('Clip Duration'),
          const SizedBox(height: 8),
          _DurationRangePicker(
            start: _clipStart,
            end: _clipEnd,
            onChanged: (s, e) => setState(() {
              _clipStart = s;
              _clipEnd = e;
            }),
          ),
        ],

        if (evidence.type == EvidenceType.pdf) ...[
          _SectionTitle('Page Range'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _IntField(
                  label: 'Start Page',
                  value: _startPage,
                  min: 1,
                  onChanged: (v) => setState(() => _startPage = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _IntField(
                  label: 'End Page',
                  value: _endPage,
                  min: _startPage,
                  onChanged: (v) => setState(() => _endPage = v),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),
        _SectionTitle('Zoom Region (optional)'),
        const SizedBox(height: 8),
        Text(
          'Drag to select the area to zoom in on during presentation.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        ZoomRegionSelector(
          evidenceId: widget.evidenceId,
          evidenceType: evidence.type,
          initialRegion: _zoomRegion,
          onRegionChanged: (region) => setState(() => _zoomRegion = region),
        ),
        const SizedBox(height: 16),
        if (_zoomRegion != null)
          Tooltip(
            message:
                'Remove the zoom region from this highlight',
            child: TextButton.icon(
              onPressed: () => setState(() => _zoomRegion = null),
              icon: const Icon(Icons.clear),
              label: const Text('Clear Zoom Region'),
            ),
          ),

        const SizedBox(height: 32),
        FilledButton(
          onPressed: _isSaving ? null : () => _save(evidence),
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Highlight'),
        ),
      ],
    );
  }

  Future<void> _save(Evidence evidence) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a highlight name')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final now = DateTime.now();

    final HighlightType type;
    switch (evidence.type) {
      case EvidenceType.video:
        type = HighlightType.videoClip;
      case EvidenceType.pdf:
        type = HighlightType.pdfPages;
      case EvidenceType.image:
        type = HighlightType.imageZoom;
    }

    final highlight = Highlight(
      id: _existing?.id ?? const Uuid().v4(),
      evidenceId: widget.evidenceId,
      name: name,
      type: type,
      clipStart:
          evidence.type == EvidenceType.video ? _clipStart : null,
      clipEnd: evidence.type == EvidenceType.video ? _clipEnd : null,
      startPage:
          evidence.type == EvidenceType.pdf ? _startPage : null,
      endPage: evidence.type == EvidenceType.pdf ? _endPage : null,
      zoomRegion: _zoomRegion,
      createdAt: _existing?.createdAt ?? now,
      createdBy: _existing?.createdBy ?? userId,
    );

    Highlight? result;
    if (_existing == null) {
      result = await ref
          .read(highlightNotifierProvider.notifier)
          .createHighlight(highlight);
    } else {
      result = await ref
          .read(highlightNotifierProvider.notifier)
          .updateHighlight(highlight);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result != null) {
      ref.invalidate(highlightsProvider(widget.evidenceId));
      context.pop();
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

class _DurationRangePicker extends StatelessWidget {
  const _DurationRangePicker({
    required this.start,
    required this.end,
    required this.onChanged,
  });

  final Duration start;
  final Duration end;
  final void Function(Duration start, Duration end) onChanged;

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TimeField(
            label: 'Start',
            value: start,
            onChanged: (v) => onChanged(v, end),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward),
        ),
        Expanded(
          child: _TimeField(
            label: 'End',
            value: end,
            onChanged: (v) => onChanged(start, v),
          ),
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Duration value;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    final hours = value.inHours;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        TextFormField(
          initialValue:
              '${hours > 0 ? '$hours:' : ''}${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          decoration: InputDecoration(
            hintText: 'HH:MM:SS',
            isDense: true,
            contentPadding: const EdgeInsets.all(8),
          ),
          onChanged: (v) {
            final parts = v.split(':');
            if (parts.length < 2) return;
            try {
              int h = 0, m = 0, s = 0;
              if (parts.length == 3) {
                h = int.parse(parts[0]);
                m = int.parse(parts[1]);
                s = int.parse(parts[2]);
              } else {
                m = int.parse(parts[0]);
                s = int.parse(parts[1]);
              }
              onChanged(
                Duration(hours: h, minutes: m, seconds: s),
              );
            } catch (_) {}
          },
        ),
      ],
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        Text('$value',
            style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}
