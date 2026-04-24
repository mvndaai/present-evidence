import 'package:flutter/material.dart';
import '../../../core/models/highlight.dart';

/// Displays a full-screen content (image, pdf page frame, etc.) with a dimmed
/// overlay and a zoomed-in inset view of the highlighted region.
///
/// [child] – the full content widget (image / PDF page / video frame).
/// [zoomRegion] – the fractional region to zoom into.
/// [backgroundOpacity] – how opaque the background content is (0=invisible, 1=fully visible).
class ZoomOverlayWidget extends StatelessWidget {
  const ZoomOverlayWidget({
    super.key,
    required this.child,
    required this.zoomRegion,
    this.backgroundOpacity = 0.4,
    this.zoomFactor = 2.5,
  });

  final Widget child;
  final ZoomRegion zoomRegion;
  final double backgroundOpacity;
  final double zoomFactor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // Zoomed rect in pixels
        final rect = zoomRegion.toRect(size);
        final regionW = rect.width.clamp(1.0, size.width);
        final regionH = rect.height.clamp(1.0, size.height);

        // Scale factor to fill a reasonable portion of screen
        final scaleX = size.width * 0.6 / regionW;
        final scaleY = size.height * 0.6 / regionH;
        final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(1.0, 8.0);

        final zoomedW = regionW * scale;
        final zoomedH = regionH * scale;

        // Position the zoomed inset in the center of the screen
        final insetLeft = (size.width - zoomedW) / 2;
        final insetTop = (size.height - zoomedH) / 2;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Background: dimmed full content
            Opacity(
              opacity: backgroundOpacity,
              child: child,
            ),

            // Dark scrim
            Container(
              color: Colors.black.withOpacity(0.4),
            ),

            // Zoomed inset – clipped & scaled
            Positioned(
              left: insetLeft,
              top: insetTop,
              width: zoomedW,
              height: zoomedH,
              child: ClipRect(
                child: OverflowBox(
                  maxWidth: size.width,
                  maxHeight: size.height,
                  alignment: Alignment.topLeft,
                  child: Transform.translate(
                    offset: Offset(-rect.left * scale, -rect.top * scale),
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Border around inset
            Positioned(
              left: insetLeft - 2,
              top: insetTop - 2,
              width: zoomedW + 4,
              height: zoomedH + 4,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
