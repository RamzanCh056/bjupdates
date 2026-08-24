import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';

const Color _premiumPurple = indigoColor;
const Color _premiumPurpleLight = recntsColor;
const Color _cardBg = darkBackgroundPrimary;
const Color _surfaceBg = Color(0xFF2A2A2A);
const Color _textMuted = Color(0xFFB0B0B0);

Future<void> showPremiumUnlockDialog(
  BuildContext context, {
  required String titleString,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _premiumPurple.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _premiumPurple.withValues(alpha: 0.15),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lock icon with glow
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _premiumPurple.withValues(alpha: 0.4),
                          _premiumPurple.withValues(alpha: 0.15),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _premiumPurple.withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        "assets/dialog_icons/lock.png",
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                        color: _premiumPurpleLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Premium Feature',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    titleString,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Upgrade button with gradient
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [_premiumPurple, _premiumPurpleLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _premiumPurple.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) =>
                          //         const PremiumSubscriptionScreen(),
                          //   ),
                        //  );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Upgrade to Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                 
                ],
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Material(
                color: _surfaceBg,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => Navigator.of(ctx).pop(),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: _textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
