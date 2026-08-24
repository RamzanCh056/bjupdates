import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';

class PremiumPlanCard extends StatelessWidget {
  final String priceText;            // e.g. "$19/month"
  final List<String> benefits;       // bullet points
  final VoidCallback onButtonPressed;

  const PremiumPlanCard({
    super.key,
    required this.priceText,
    required this.benefits,
    required this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      decoration: BoxDecoration(
        color: darkBackgroundPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: recntsColor.withOpacity(0.2))
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // price
          Text(
            priceText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.25), height: 1),
          const SizedBox(height: 24),

          // title
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Why Upgrade:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // bullets
          ...benefits.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Divider(color: Colors.white.withOpacity(0.25), height: 1),
          const SizedBox(height: 24),

          // button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF9B42F5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ).borderRadius,
                ),
                elevation: 0,
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
