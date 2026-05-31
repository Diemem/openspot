import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/property.dart';
import '../../auth/providers/auth_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../history/providers/history_provider.dart';
import '../providers/property_provider.dart';

class PropertyDetailScreen extends ConsumerWidget {
  final String id;
  const PropertyDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyAsync = ref.watch(propertyDetailProvider(id));
    final user = ref.watch(currentUserProvider);

    // Track property view when screen loads
    ref.listen(propertyDetailProvider(id), (previous, next) {
      if (next.hasValue && previous?.hasValue != true) {
        // Property loaded for first time, track the view
        trackPropertyView(id, user?.id);
      }
    });

    return propertyAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (property) {
        if (property == null) return const Scaffold(body: Center(child: Text('Property not found')));
        
        // Track property view
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _trackPropertyView(property.id);
        });
        
        return _PropertyDetailView(property: property);
      },
    );
  }

  Future<void> _trackPropertyView(String propertyId) async {
    try {
      await Supabase.instance.client.rpc('increment_property_views', params: {
        'property_id': propertyId,
      });
    } catch (e) {
      // Silently fail - view tracking shouldn't break the UI
      debugPrint('Failed to track view: $e');
    }
  }
}

class _PropertyDetailView extends ConsumerStatefulWidget {
  final Property property;
  const _PropertyDetailView({required this.property});

  @override
  ConsumerState<_PropertyDetailView> createState() => _PropertyDetailViewState();
}

class _PropertyDetailViewState extends ConsumerState<_PropertyDetailView> {
  bool _showAllMedia = false;
  bool _showLightbox = false;
  int _lightboxIndex = 0;

  Property get p => widget.property;

  List<String> get _allMedia => [
    ...p.images,
    if (p.videoUrl != null) p.videoUrl!,
  ];

  void _openLightbox(int index) => setState(() { _lightboxIndex = index; _showLightbox = true; });

  Future<void> _call() async {
    if (p.landlordPhone == null) return;
    
    // Track contact
    try {
      await Supabase.instance.client.from('property_views').insert({
        'property_id': p.id,
        'source': 'detail_call',
        'session_id': 'mobile_call',
      });
    } catch (e) {
      debugPrint('Failed to track contact: $e');
    }
    
    await launchUrl(Uri.parse('tel:${p.landlordPhone}'));
  }

  Future<void> _whatsapp() async {
    if (p.landlordPhone == null) return;
    
    // Track contact
    try {
      await Supabase.instance.client.from('property_views').insert({
        'property_id': p.id,
        'source': 'detail_whatsapp',
        'session_id': 'mobile_whatsapp',
      });
    } catch (e) {
      debugPrint('Failed to track contact: $e');
    }
    
    final cleaned = p.landlordPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    await launchUrl(Uri.parse('https://wa.me/$cleaned'), mode: LaunchMode.externalApplication);
  }

  Future<void> _navigate() async {
    if (p.latitude == null || p.longitude == null) return;
    await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isFav = ref.watch(isFavoriteProvider(p.id));
    final isWide = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── STICKY HEADER ──
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 1,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF374151)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (user == null) { context.push('/signin'); return; }
                      ref.read(favoritesNotifierProvider).toggleFavorite(p.id);
                    },
                    icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 16, color: isFav ? Colors.red : null),
                    label: Text(isFav ? 'Saved' : 'Save'),
                    style: TextButton.styleFrom(foregroundColor: isFav ? Colors.red : const Color(0xFF374151)),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // ── MEDIA GALLERY ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    children: [
                      // First 4 images — 2-column grid
                      if (_allMedia.isNotEmpty)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 16 / 9,
                          ),
                          itemCount: _allMedia.take(4).length,
                          itemBuilder: (_, i) => _MediaTile(url: _allMedia[i], onTap: () => _openLightbox(i)),
                        ),
                      const SizedBox(height: 8),
                      // Show all toggle
                      if (_allMedia.length > 4)
                        GestureDetector(
                          onTap: () => setState(() => _showAllMedia = !_showAllMedia),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(_showAllMedia ? Icons.keyboard_arrow_up : Icons.photo_library_outlined, size: 18, color: const Color(0xFF374151)),
                              const SizedBox(width: 8),
                              Text(
                                _showAllMedia ? 'Show less' : 'Show all ${_allMedia.length} photos',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                              ),
                            ]),
                          ),
                        ),
                      // Expanded gallery
                      if (_showAllMedia && _allMedia.length > 4) ...[
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            childAspectRatio: 1,
                          ),
                          itemCount: _allMedia.length - 4,
                          itemBuilder: (_, i) => _MediaTile(url: _allMedia[i + 4], onTap: () => _openLightbox(i + 4)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── CONTENT ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: isWide
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 2, child: _LeftColumn(p: p)),
                          const SizedBox(width: 32),
                          SizedBox(width: 320, child: _BookingCard(p: p, onCall: _call, onWhatsApp: _whatsapp, onNavigate: _navigate)),
                        ])
                      : _LeftColumn(p: p),
                ),
              ),

              // Bottom padding for mobile bar
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),

          // ── LIGHTBOX ──
          if (_showLightbox)
            _Lightbox(
              media: _allMedia,
              initialIndex: _lightboxIndex,
              onClose: () => setState(() => _showLightbox = false),
            ),
        ],
      ),

      // ── MOBILE BOTTOM BAR ──
      bottomNavigationBar: MediaQuery.of(context).size.width < 1024
          ? _MobileBottomBar(onCall: _call, onWhatsApp: _whatsapp, onNavigate: _navigate, hasPhone: p.landlordPhone != null, hasCoords: p.latitude != null)
          : null,
    );
  }
}

// ── LEFT COLUMN ───────────────────────────────────────────────────────────────
class _LeftColumn extends StatelessWidget {
  final Property p;
  const _LeftColumn({required this.p});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(p.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        const SizedBox(height: 10),

        // Location + rating row
        Wrap(spacing: 16, runSpacing: 6, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Text(p.location, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ]),
          const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star, size: 16, color: Color(0xFFF59E0B)),
            SizedBox(width: 4),
            Text('4.8', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
            Text(' (reviews)', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ]),
        ]),
        const SizedBox(height: 12),

        // Mobile price
        if (MediaQuery.of(context).size.width < 1024)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Text(p.formattedPrice, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const Text(' / month', style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
            ]),
          ),

        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 20),

        // Description
        const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
        const SizedBox(height: 8),
        if (p.description != null)
          Text(p.description!, style: const TextStyle(color: Color(0xFF374151), fontSize: 14, height: 1.7)),

        const SizedBox(height: 24),

        // Property details grid
        const Text('Property Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (p.bedrooms != null && p.bedrooms! > 0) _DetailChip(icon: Icons.bed_outlined, label: '${p.bedrooms} Bedrooms'),
            if (p.bathrooms != null && p.bathrooms! > 0) _DetailChip(icon: Icons.bathtub_outlined, label: '${p.bathrooms} Bathrooms'),
            if (p.area != null) _DetailChip(icon: Icons.square_foot, label: '${p.area!.toStringAsFixed(0)} sqft'),
            if (p.floorNumber != null) _DetailChip(icon: Icons.apartment_outlined, label: 'Floor ${p.floorNumber}'),
            if (p.parkingSpaces != null && p.parkingSpaces! > 0) _DetailChip(icon: Icons.local_parking_outlined, label: '${p.parkingSpaces} Parking'),
            if (p.leaseDuration != null) _DetailChip(icon: Icons.calendar_today_outlined, label: p.leaseDuration!),
            _DetailChip(icon: p.verified ? Icons.verified : Icons.pending_outlined, label: p.verified ? 'Verified' : 'Unverified', color: p.verified ? const Color(0xFF16A34A) : null),
            if (p.landlordVerified) _DetailChip(icon: Icons.person_pin_outlined, label: 'Verified Landlord', color: const Color(0xFF2563EB)),
          ],
        ),

        const SizedBox(height: 24),

        // Amenities
        if (p.amenities.isNotEmpty) ...[
          const Text('Amenities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: p.amenities.map((a) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Text(_fmt(a), style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
              ]),
            )).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Utilities included
        if (p.utilitiesIncluded.isNotEmpty) ...[
          const Text('Utilities Included', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: p.utilitiesIncluded.map((u) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFBFDBFE))),
              child: Text(_fmt(u), style: const TextStyle(fontSize: 12, color: Color(0xFF1D4ED8))),
            )).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Landlord info
        if (p.landlordName != null) ...[
          const Divider(),
          const SizedBox(height: 16),
          const Text('Listed by', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          const SizedBox(height: 12),
          Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF4F46E5),
              child: Text(p.landlordName!.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(p.landlordName!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF111827))),
                if (p.landlordVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, size: 16, color: Color(0xFF2563EB)),
                ],
              ]),
              if (p.landlordEmail != null)
                Text(p.landlordEmail!, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ])),
          ]),
        ],

        const SizedBox(height: 24),

        // Desktop contact buttons
        if (MediaQuery.of(context).size.width >= 1024) ...[
          const Divider(),
          const SizedBox(height: 16),
          _ContactButtons(p: p),
        ],
      ],
    );
  }

  String _fmt(String s) => s.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

// ── DETAIL CHIP ───────────────────────────────────────────────────────────────
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _DetailChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF4F46E5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c)),
      ]),
    );
  }
}

// ── BOOKING CARD (desktop right column) ──────────────────────────────────────
class _BookingCard extends StatelessWidget {
  final Property p;
  final VoidCallback onCall, onWhatsApp, onNavigate;
  const _BookingCard({required this.p, required this.onCall, required this.onWhatsApp, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(p.formattedPrice, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const Text(' / month', style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          ]),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          _ContactButtons(p: p),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          // Summary
          _SummaryRow('Location', p.location),
          const SizedBox(height: 8),
          _SummaryRow('Type', p.propertyType.replaceAll('_', ' ')),
          if (p.deposit != null) ...[
            const SizedBox(height: 8),
            _SummaryRow('Deposit', 'KSh ${p.deposit!.toStringAsFixed(0)}'),
          ],
          if (p.availableFrom != null) ...[
            const SizedBox(height: 8),
            _SummaryRow('Available', p.availableFrom!),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
      Flexible(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827)), textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }
}

// ── CONTACT BUTTONS ───────────────────────────────────────────────────────────
class _ContactButtons extends StatelessWidget {
  final Property p;
  const _ContactButtons({required this.p});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (p.landlordPhone != null)
        _Btn(label: 'Call ${p.landlordPhone}', icon: Icons.phone, color: const Color(0xFF16A34A), onTap: () => launchUrl(Uri.parse('tel:${p.landlordPhone}'))),
      if (p.landlordPhone != null) const SizedBox(height: 10),
      if (p.landlordPhone != null)
        _Btn(label: 'WhatsApp', icon: Icons.message, color: const Color(0xFF15803D), onTap: () {
          final c = p.landlordPhone!.replaceAll(RegExp(r'[^0-9]'), '');
          launchUrl(Uri.parse('https://wa.me/$c'), mode: LaunchMode.externalApplication);
        }),
      if (p.latitude != null) ...[
        const SizedBox(height: 10),
        _Btn(label: 'Navigate to Property', icon: Icons.navigation, color: const Color(0xFF2563EB), onTap: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}'), mode: LaunchMode.externalApplication)),
      ],
    ]);
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    );
  }
}

// ── MOBILE BOTTOM BAR ─────────────────────────────────────────────────────────
class _MobileBottomBar extends StatelessWidget {
  final VoidCallback onCall, onWhatsApp, onNavigate;
  final bool hasPhone, hasCoords;
  const _MobileBottomBar({required this.onCall, required this.onWhatsApp, required this.onNavigate, required this.hasPhone, required this.hasCoords});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
      child: Row(children: [
        if (hasPhone) Expanded(child: _Btn(label: 'Call', icon: Icons.phone, color: const Color(0xFF16A34A), onTap: onCall)),
        if (hasPhone) const SizedBox(width: 8),
        if (hasPhone) Expanded(child: _Btn(label: 'WhatsApp', icon: Icons.message, color: const Color(0xFF15803D), onTap: onWhatsApp)),
        if (hasCoords) const SizedBox(width: 8),
        if (hasCoords) Expanded(child: _Btn(label: 'Navigate', icon: Icons.navigation, color: const Color(0xFF2563EB), onTap: onNavigate)),
      ]),
    );
  }
}

// ── MEDIA TILE ────────────────────────────────────────────────────────────────
class _MediaTile extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  const _MediaTile({required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: const Color(0xFFE5E7EB)),
          errorWidget: (_, __, ___) => Container(color: const Color(0xFFE5E7EB), child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF9CA3AF))),
        ),
      ),
    );
  }
}

// ── LIGHTBOX ──────────────────────────────────────────────────────────────────
class _Lightbox extends StatefulWidget {
  final List<String> media;
  final int initialIndex;
  final VoidCallback onClose;
  const _Lightbox({required this.media, required this.initialIndex, required this.onClose});

  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late int _index;
  late PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onClose,
        child: Container(
          color: Colors.black.withOpacity(0.95),
          child: Stack(
            children: [
              PageView.builder(
                controller: _ctrl,
                itemCount: widget.media.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () {},
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.media[i],
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
              ),
              // Close
              Positioned(top: 40, right: 16, child: GestureDetector(onTap: widget.onClose, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 22)))),
              // Counter
              Positioned(top: 48, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text('${_index + 1} / ${widget.media.length}', style: const TextStyle(color: Colors.white, fontSize: 13))))),
              // Arrows
              if (widget.media.length > 1) ...[
                Positioned(left: 12, top: 0, bottom: 0, child: Center(child: GestureDetector(onTap: () { if (_index > 0) _ctrl.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut); }, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.chevron_left, color: Colors.white, size: 28))))),
                Positioned(right: 12, top: 0, bottom: 0, child: Center(child: GestureDetector(onTap: () { if (_index < widget.media.length - 1) _ctrl.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut); }, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.chevron_right, color: Colors.white, size: 28))))),
              ],
              // Thumbnail strip
              Positioned(
                bottom: 20, left: 0, right: 0,
                child: SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.media.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _ctrl.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut),
                      child: Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: i == _index ? Colors.white : Colors.transparent, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(imageUrl: widget.media[i], fit: BoxFit.cover),
                        ),
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
}
