import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:pdfx/pdfx.dart';
import 'package:photo_view/photo_view.dart';
import '../../../core/models/evidence.dart';
import '../providers/evidence_provider.dart';

class EvidenceViewerWidget extends ConsumerWidget {
  const EvidenceViewerWidget({super.key, required this.evidence});

  final Evidence evidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(evidenceUrlProvider(evidence));
    return urlAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 8),
            Text('Failed to load: $e'),
          ],
        ),
      ),
      data: (url) {
        switch (evidence.type) {
          case EvidenceType.pdf:
            return _PdfViewer(url: url);
          case EvidenceType.video:
            return _VideoViewer(url: url);
          case EvidenceType.image:
            return _ImageViewer(url: url);
        }
      },
    );
  }
}

// ──────────────────────────── PDF Viewer ────────────────────────────

class _PdfViewer extends StatefulWidget {
  const _PdfViewer({required this.url});
  final String url;

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  PdfController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfController(
      document: PdfDocument.openUrl(widget.url),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PdfView(controller: _controller!);
  }
}

// ──────────────────────────── Video Viewer ────────────────────────────

class _VideoViewer extends StatefulWidget {
  const _VideoViewer({required this.url});
  final String url;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
    );
    _videoController.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          autoPlay: false,
          looping: false,
          allowFullScreen: true,
        );
      });
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Chewie(controller: _chewieController!);
  }
}

// ──────────────────────────── Image Viewer ────────────────────────────

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return PhotoView(
      imageProvider: NetworkImage(url),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      backgroundDecoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}
