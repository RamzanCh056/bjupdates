import 'package:flutter/material.dart';

/// Shared badge widgets so every screen shows them identically.
///
/// Verified = admin-approved identity (blue seal, Icons.verified).
/// Premium  = active paid subscription (gold seal, Icons.verified).
class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 16});

  static const Color color = Color(0xFF3B9EFF);

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.verified, size: size, color: color);
  }
}

class PremiumBadge extends StatelessWidget {
  final double size;
  const PremiumBadge({super.key, this.size = 16});

  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFCE08A), Color(0xFFF3B33F), Color(0xFFC8831A)],
  );

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => gold.createShader(rect),
      blendMode: BlendMode.srcIn,
      child: Icon(Icons.verified, size: size, color: Colors.white),
    );
  }
}

/// Shows the verified and/or premium badges a user holds, side by side.
class BadgeStrip extends StatelessWidget {
  final bool verified;
  final bool premium;
  final double size;
  final double gap;

  const BadgeStrip({
    super.key,
    required this.verified,
    required this.premium,
    this.size = 16,
    this.gap = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (!verified && !premium) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (verified) VerifiedBadge(size: size),
        if (verified && premium) SizedBox(width: gap),
        if (premium) PremiumBadge(size: size),
      ],
    );
  }
}
