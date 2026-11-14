import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens/pc_shape.dart';

/// The few glyphs the components draw themselves.
///
/// The design system's icon set is a custom outline set on a 24×24 grid
/// with stroke 2 and round caps and joins (Lucide / Feather style). The full
/// set is not part of this milestone; components take any icon widget from
/// the caller. These glyphs are the ones components need internally, drawn
/// to the same grid rules (geometry follows Lucide, ISC license).
enum PcGlyph {
  /// Check mark (stroke 2.5).
  check,

  /// Back arrow.
  arrowLeft,

  /// Close (×).
  close,

  /// Chevron pointing right (list rows, link cards).
  chevronRight,

  /// Chevron pointing down (expandable card).
  chevronDown,

  /// Circle with an exclamation mark (field error).
  alertCircle,
}

/// Draws a [PcGlyph] at the ambient `IconTheme` size and color.
class PcIcon extends StatelessWidget {
  /// Creates a glyph icon.
  const PcIcon(
    this.glyph, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  /// What to draw.
  final PcGlyph glyph;

  /// Overrides the `IconTheme` size.
  final double? size;

  /// Overrides the `IconTheme` color.
  final Color? color;

  /// Announced by screen readers. Decorative glyphs leave it null.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24;
    final resolvedColor =
        color ?? iconTheme.color ?? DefaultTextStyle.of(context).style.color;
    final icon = SizedBox.square(
      dimension: resolvedSize,
      child: CustomPaint(
        painter: _GlyphPainter(
          glyph,
          resolvedColor ?? const Color(0xFF000000),
        ),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: icon);
    return Semantics(label: semanticLabel, image: true, child: icon);
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final PcGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = glyph == PcGlyph.check ? PcStrokes.check : PcStrokes.icon;

    for (final line in _lines[glyph]!) {
      final path = Path()..moveTo(line.first.dx, line.first.dy);
      for (final point in line.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
    if (glyph == PcGlyph.alertCircle) {
      canvas.drawCircle(const Offset(12, 12), 10, paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;

  static const Map<PcGlyph, List<List<Offset>>> _lines = {
    PcGlyph.check: [
      [Offset(20, 6), Offset(9, 17), Offset(4, 12)],
    ],
    PcGlyph.arrowLeft: [
      [Offset(12, 19), Offset(5, 12), Offset(12, 5)],
      [Offset(19, 12), Offset(5, 12)],
    ],
    PcGlyph.close: [
      [Offset(18, 6), Offset(6, 18)],
      [Offset(6, 6), Offset(18, 18)],
    ],
    PcGlyph.chevronRight: [
      [Offset(9, 18), Offset(15, 12), Offset(9, 6)],
    ],
    PcGlyph.chevronDown: [
      [Offset(6, 9), Offset(12, 15), Offset(18, 9)],
    ],
    PcGlyph.alertCircle: [
      [Offset(12, 8), Offset(12, 12)],
      [Offset(12, 16), Offset(12.01, 16)],
    ],
  };
}
