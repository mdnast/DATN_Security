import 'package:flutter/material.dart';

class GuardMailLogo extends StatelessWidget {
  final double size;
  final bool showTitle;
  final double titleFontSize;
  final double spacing;

  const GuardMailLogo({
    super.key,
    this.size = 72,
    this.showTitle = true,
    this.titleFontSize = 24,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final logo = _buildLogoMark();

    if (!showTitle) return logo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        SizedBox(height: spacing),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ward',
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? Colors.white : const Color(0xFF202124),
              ),
            ),
            Text(
              'Mail',
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: const Color(0xFF4285F4),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF34A853),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF34A853).withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoMark() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: Image.asset(
        'lib/img/z7237230542816_f58f6ecbbeacba85be0b0eac32b0c70f-removebg-preview.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
