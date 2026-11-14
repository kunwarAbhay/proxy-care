import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens/pc_spacing.dart';

/// The bottom action area (section 3 and usage rules): padded 16 / 24 / 24
/// (top / sides / bottom), buttons full-width and stacked 8px apart, the
/// one filled primary on top and a text button below. Keeps clear of the
/// system gesture area and the keyboard inset handled by `Scaffold`.
class PcBottomActionArea extends StatelessWidget {
  /// Creates an action area.
  const PcBottomActionArea({super.key, required this.children});

  /// Full-width buttons, primary first.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PcSpacing.textInset,
          PcSpacing.space4,
          PcSpacing.textInset,
          PcSpacing.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: PcSpacing.space2),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
