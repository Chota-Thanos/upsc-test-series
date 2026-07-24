import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import '../theme/app_theme.dart';

class PremiumLockOverlay extends StatelessWidget {
  final String title;
  final String description;
  final String planName;
  final String ctaText;

  const PremiumLockOverlay({
    super.key,
    required this.title,
    required this.description,
    this.planName = "Premium",
    this.ctaText = "View Pricing Plans",
  });

  Future<void> _launchPricing() async {
    final url = Uri.parse("${ApiConstants.webAppUrl}/pricing");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.indigo.shade50),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.shade50.withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Colors.indigo,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),

            // Plan Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                border: Border.all(color: Colors.indigo.shade100),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Colors.indigo,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${planName.toUpperCase()} FEATURE",
                    style: AppTypography.eyebrowSmall.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              title,
              style: AppTypography.title.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              description,
              style: AppTypography.body.copyWith(fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: _launchPricing,
                child: Text(
                  ctaText,
                  style: AppTypography.button.copyWith(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
