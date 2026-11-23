import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Screen displayed when an unauthenticated visitor requests a non-existent
/// or invalid agent landing page URL (e.g. /agent/unknown-agent-999).
/// Presents a clean, helpful 404 state without leaking private database
/// records, agent credentials, or technical stack traces.
class AgentNotFoundScreen extends StatelessWidget {
  final String requestedSlug;
  final VoidCallback? onReturnHome;

  const AgentNotFoundScreen({
    super.key,
    required this.requestedSlug,
    this.onReturnHome,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'PROPMATCH AI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Property Consultant Portal',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24.0 : 40.0,
                  vertical: isMobile ? 32.0 : 48.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_off_outlined,
                        size: 38,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Agent Landing Page Not Found',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      requestedSlug.isNotEmpty
                          ? 'The requested property agent profile "@$requestedSlug" does not exist or may have been deactivated.'
                          : 'The requested property agent landing page URL is invalid.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please verify the link with your property consultant or return to the main PropMatch AI portal.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onReturnHome ??
                            () {
                              Navigator.of(context).pushReplacementNamed('/');
                            },
                        icon: const Icon(Icons.home_outlined, size: 18),
                        label: const Text(
                          'Return to PropMatch AI Home',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
