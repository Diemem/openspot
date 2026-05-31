import 'package:flutter/material.dart';

class TrustSection extends StatelessWidget {
  const TrustSection({super.key});

  static const _badges = [
    _Badge('🔒', 'Secure Payments', 'Bank-level encryption'),
    _Badge('✓', 'Verified Listings', 'AI-powered verification'),
    _Badge('🛡️', 'Fraud Protection', '100% scam-free guarantee'),
    _Badge('⚡', 'Instant Booking', 'Book in under 2 minutes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          const Text(
            'Why thousands trust OpenSpot',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "We're committed to making property search safe,\ntransparent, and hassle-free",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _BadgeTile(badge: _badges[0])),
                  const SizedBox(width: 16),
                  Expanded(child: _BadgeTile(badge: _badges[1])),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _BadgeTile(badge: _badges[2])),
                  const SizedBox(width: 16),
                  Expanded(child: _BadgeTile(badge: _badges[3])),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final _Badge badge;
  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(badge.icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  badge.desc,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge {
  final String icon;
  final String title;
  final String desc;
  const _Badge(this.icon, this.title, this.desc);
}
