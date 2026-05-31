import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/property.dart';
import '../../search_engine/application/search_controller.dart';
import '../../search_engine/infrastructure/property_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../favorites/providers/favorites_provider.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _pageController = PageController();
  int _currentIndex = 0;
  final Map<int, VideoPlayerController> _videoControllers = {};
  final Set<String> _viewedProperties = {}; // Track viewed properties
  String? _selectedPropertyType; // Filter by property type
  bool _showFilters = false;

  @override
  void dispose() {
    _pageController.dispose();
    // Dispose all video controllers
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    super.dispose();
  }

  void _onPageChanged(int index, List<Property> properties) {
    setState(() => _currentIndex = index);
    
    // Track view after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (_currentIndex == index && mounted) {
        final propertyId = properties[index].id;
        if (!_viewedProperties.contains(propertyId)) {
          _viewedProperties.add(propertyId);
          _trackView(propertyId);
        }
      }
    });

    // Preload next video
    if (index + 1 < properties.length) {
      _preloadVideo(index + 1, properties[index + 1]);
    }

    // Dispose videos that are far away (more than 2 positions)
    _cleanupDistantVideos(index);
  }

  void _preloadVideo(int index, Property property) {
    if (property.videoUrl == null || property.videoUrl!.isEmpty) return;
    if (_videoControllers.containsKey(index)) return;

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(property.videoUrl!));
      _videoControllers[index] = controller;
      controller.initialize();
    } catch (e) {
      // Video preload failed, will try again when card is active
    }
  }

  void _cleanupDistantVideos(int currentIndex) {
    final keysToRemove = <int>[];
    for (var index in _videoControllers.keys) {
      if ((index - currentIndex).abs() > 2) {
        keysToRemove.add(index);
      }
    }
    for (var key in keysToRemove) {
      _videoControllers[key]?.dispose();
      _videoControllers.remove(key);
    }
  }

  Future<void> _trackView(String propertyId) async {
    try {
      await ref.read(propertyRepositoryProvider).incrementViews(propertyId);
    } catch (e) {
      // Silent fail - view tracking shouldn't break UX
    }
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(exploreSearchControllerProvider);
    final isWide = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: Colors.black,
      body: propertiesAsync.when(
        loading: () => const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          SizedBox(height: 16),
          Text('Loading properties...', style: TextStyle(color: Colors.white, fontSize: 16)),
        ])),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('⚠️ Error loading properties', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => ref.invalidate(exploreSearchControllerProvider), child: const Text('Retry')),
        ])),
        data: (props) {
          if (props.isEmpty) return const Center(child: Text('No properties found', style: TextStyle(color: Colors.white)));

          // Filter by property type if selected
          final filteredProps = _selectedPropertyType == null
              ? props
              : props.where((p) => p.propertyType.toLowerCase() == _selectedPropertyType!.toLowerCase()).toList();

          if (filteredProps.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No properties found', style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() => _selectedPropertyType = null),
                    child: const Text('Clear Filter'),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              // ── VERTICAL FEED ──
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: filteredProps.length,
                onPageChanged: (i) => _onPageChanged(i, filteredProps),
                itemBuilder: (_, i) => _VideoCard(
                  property: filteredProps[i],
                  isActive: i == _currentIndex,
                  isWide: isWide,
                  videoController: _videoControllers[i],
                  onVideoControllerCreated: (controller) {
                    if (!_videoControllers.containsKey(i)) {
                      _videoControllers[i] = controller;
                    }
                  },
                ),
              ),

              // ── QUICK FILTERS (top-right) ──
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => setState(() => _showFilters = !_showFilters),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Icon(
                      _showFilters ? Icons.close : Icons.filter_list,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),

              // ── FILTER MENU ──
              if (_showFilters)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 70,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Property Type', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ...[
                          {'label': 'All', 'value': null},
                          {'label': 'Apartment', 'value': 'apartment'},
                          {'label': 'Studio', 'value': 'studio'},
                          {'label': 'Bedsitter', 'value': 'bedsitter'},
                          {'label': 'House', 'value': 'house'},
                        ].map((filter) => GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPropertyType = filter['value'] as String?;
                              _showFilters = false;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedPropertyType == filter['value']
                                  ? const Color(0xFF3B82F6)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              filter['label'] as String,
                              style: TextStyle(
                                color: _selectedPropertyType == filter['value']
                                    ? Colors.white
                                    : Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                ),

              // ── SWIPE HINT ──
              if (_currentIndex == 0)
                Positioned(
                  bottom: 100, left: 0, right: 0,
                  child: Column(children: const [
                    Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 28),
                    Text('Swipe to explore', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── TAB BUTTON ────────────────────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white60, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 15)),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isActive ? 24 : 0, height: 2,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1)),
        ),
      ]),
    );
  }
}

// ── VIDEO CARD ────────────────────────────────────────────────────────────────
class _VideoCard extends ConsumerStatefulWidget {
  final Property property;
  final bool isActive;
  final bool isWide;
  final VideoPlayerController? videoController;
  final Function(VideoPlayerController)? onVideoControllerCreated;
  
  const _VideoCard({
    required this.property, 
    required this.isActive, 
    required this.isWide,
    this.videoController,
    this.onVideoControllerCreated,
  });

  @override
  ConsumerState<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends ConsumerState<_VideoCard> {
  bool _showDetails = true;
  bool _isMuted = false;
  VideoPlayerController? _localVideoController;
  bool _isVideoInitialized = false;
  bool _showHeartAnimation = false;
  bool _isVideoLoading = false;
  String? _videoError;

  Property get p => widget.property;

  String get _landlordName => (p.landlordName?.isNotEmpty == true) ? p.landlordName! : 'Owner';
  String get _landlordAvatarUrl => 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_landlordName)}&background=3b82f6&color=fff&size=64';
  String get _imageUrl => p.firstImage?.isNotEmpty == true ? p.firstImage! : 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800';
  bool get _hasVideo => p.videoUrl != null && p.videoUrl!.isNotEmpty;

  VideoPlayerController? get _activeController => widget.videoController ?? _localVideoController;

  @override
  void initState() {
    super.initState();
    if (_hasVideo && widget.videoController == null) {
      _initializeVideo();
    } else if (widget.videoController != null) {
      _isVideoInitialized = widget.videoController!.value.isInitialized;
      if (_isVideoInitialized) {
        widget.videoController!.addListener(_videoListener);
      }
    }
  }

  void _videoListener() {
    if (mounted && _activeController != null) {
      final isInitialized = _activeController!.value.isInitialized;
      if (isInitialized != _isVideoInitialized) {
        setState(() => _isVideoInitialized = isInitialized);
      }
    }
  }

  @override
  void didUpdateWidget(_VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle video playback based on active state
    if (_hasVideo && _activeController != null && _isVideoInitialized) {
      if (widget.isActive && !_activeController!.value.isPlaying) {
        _activeController!.play();
      } else if (!widget.isActive && _activeController!.value.isPlaying) {
        _activeController!.pause();
      }
    }

    // Update listener if controller changed
    if (oldWidget.videoController != widget.videoController) {
      oldWidget.videoController?.removeListener(_videoListener);
      widget.videoController?.addListener(_videoListener);
      if (widget.videoController != null) {
        _isVideoInitialized = widget.videoController!.value.isInitialized;
      }
    }
  }

  void _initializeVideo() async {
    if (!mounted) return;
    
    setState(() {
      _isVideoLoading = true;
      _videoError = null;
    });

    try {
      _localVideoController = VideoPlayerController.networkUrl(Uri.parse(p.videoUrl!));
      await _localVideoController!.initialize();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });
        
        if (widget.isActive) {
          _localVideoController!.play();
          _localVideoController!.setLooping(true);
        }
        
        widget.onVideoControllerCreated?.call(_localVideoController!);
      }
    } catch (e) {
      // Video failed to load, will show image instead
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
          _isVideoLoading = false;
          _videoError = 'Video unavailable';
        });
      }
    }
  }

  void _toggleMute() {
    if (_activeController != null) {
      setState(() {
        _isMuted = !_isMuted;
        _activeController!.setVolume(_isMuted ? 0.0 : 1.0);
      });
    }
  }

  void _handleDoubleTap(BuildContext context) {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.push('/signin');
      return;
    }
    
    final isFav = ref.read(isFavoriteProvider(p.id));
    if (!isFav) {
      ref.read(favoritesNotifierProvider).toggleFavorite(p.id);
      
      // Show heart animation
      setState(() => _showHeartAnimation = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showHeartAnimation = false);
      });
    }
  }

  @override
  void dispose() {
    _activeController?.removeListener(_videoListener);
    // Only dispose local controller, parent manages shared controllers
    if (_localVideoController != null && widget.videoController == null) {
      _localVideoController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isFav = ref.watch(isFavoriteProvider(p.id));

    // Desktop: centered 9:16 container + actions on right
    // Mobile: full screen
    if (widget.isWide) {
      return Container(
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Video container — 9:16 aspect ratio
            AspectRatio(
              aspectRatio: 9 / 16,
              child: _CardContent(
                p: p,
                imageUrl: _imageUrl,
                landlordName: _landlordName,
                landlordAvatarUrl: _landlordAvatarUrl,
                showDetails: _showDetails,
                isMuted: _isMuted,
                isFav: isFav,
                user: user,
                ref: ref,
                hasVideo: _hasVideo,
                videoController: _activeController,
                isVideoInitialized: _isVideoInitialized,
                isVideoLoading: _isVideoLoading,
                videoError: _videoError,
                onTap: () => setState(() => _showDetails = !_showDetails),
                onFav: () {
                  if (user == null) { context.push('/signin'); return; }
                  ref.read(favoritesNotifierProvider).toggleFavorite(p.id);
                },
                onMute: _toggleMute,
                onShare: () => Share.share(
                  'Check out this property: ${p.title}\n\nView on OpenSpot: https://openspot.app/property/${p.id}',
                  subject: p.title,
                ),
                onContact: () => p.landlordPhone != null ? launchUrl(Uri.parse('tel:${p.landlordPhone}')) : context.go('/messages'),
                onDetails: () => context.push('/property/${p.id}'),
                onDoubleTap: () => _handleDoubleTap(context),
                showHeartAnimation: _showHeartAnimation,
                isDesktop: true,
              ),
            ),
            // Desktop action buttons — outside video on right
            const SizedBox(width: 8),
            _DesktopActions(
              isFav: isFav,
              isMuted: _isMuted,
              hasVideo: _hasVideo,
              likes: p.likes,
              views: p.views,
              onFav: () {
                if (user == null) { context.push('/signin'); return; }
                ref.read(favoritesNotifierProvider).toggleFavorite(p.id);
              },
              onMute: _toggleMute,
              onShare: () => Share.share(
                'Check out this property: ${p.title}\n\nView on OpenSpot: https://openspot.app/property/${p.id}',
                subject: p.title,
              ),
              onContact: () => p.landlordPhone != null ? launchUrl(Uri.parse('tel:${p.landlordPhone}')) : context.go('/messages'),
            ),
          ],
        ),
      );
    }

    // Mobile — full screen
    return _CardContent(
      p: p,
      imageUrl: _imageUrl,
      landlordName: _landlordName,
      landlordAvatarUrl: _landlordAvatarUrl,
      showDetails: _showDetails,
      isMuted: _isMuted,
      isFav: isFav,
      user: user,
      ref: ref,
      hasVideo: _hasVideo,
      videoController: _activeController,
      isVideoInitialized: _isVideoInitialized,
      isVideoLoading: _isVideoLoading,
      videoError: _videoError,
      onTap: () => setState(() => _showDetails = !_showDetails),
      onFav: () {
        if (user == null) { context.push('/signin'); return; }
        ref.read(favoritesNotifierProvider).toggleFavorite(p.id);
      },
      onMute: _toggleMute,
      onShare: () => Share.share(
        'Check out this property: ${p.title}\n\nView on OpenSpot: https://openspot.app/property/${p.id}',
        subject: p.title,
      ),
      onContact: () => p.landlordPhone != null ? launchUrl(Uri.parse('tel:${p.landlordPhone}')) : context.go('/messages'),
      onDetails: () => context.push('/property/${p.id}'),
      onDoubleTap: () => _handleDoubleTap(context),
      showHeartAnimation: _showHeartAnimation,
      isDesktop: false,
    );
  }
}

// ── CARD CONTENT ──────────────────────────────────────────────────────────────
class _CardContent extends StatelessWidget {
  final Property p;
  final String imageUrl, landlordName, landlordAvatarUrl;
  final bool showDetails, isMuted, isFav, isDesktop;
  final bool hasVideo, isVideoInitialized, showHeartAnimation, isVideoLoading;
  final String? videoError;
  final VideoPlayerController? videoController;
  final dynamic user;
  final WidgetRef ref;
  final VoidCallback onTap, onFav, onMute, onContact, onDetails, onShare, onDoubleTap;

  const _CardContent({
    required this.p, required this.imageUrl, required this.landlordName,
    required this.landlordAvatarUrl, required this.showDetails, required this.isMuted,
    required this.isFav, required this.isDesktop, required this.hasVideo,
    required this.isVideoInitialized, required this.videoController,
    required this.showHeartAnimation, required this.isVideoLoading,
    required this.videoError,
    required this.user, required this.ref, required this.onTap, required this.onFav,
    required this.onMute, required this.onContact, required this.onDetails,
    required this.onShare, required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onHorizontalDragEnd: (details) {
        // Swipe left/right to skip (optional enhancement)
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 500) {
            // Swiped right - could trigger "save" action
          } else if (details.primaryVelocity! < -500) {
            // Swiped left - could trigger "skip" action
          }
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background video or image
          if (hasVideo && isVideoInitialized && videoController != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: videoController!.value.size.width,
                height: videoController!.value.size.height,
                child: VideoPlayer(videoController!),
              ),
            )
          else if (hasVideo && isVideoLoading)
            // Video loading state
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: p.thumbnailUrl ?? imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFF1F2937)),
                  errorWidget: (_, __, ___) => Container(color: const Color(0xFF1F2937)),
                ),
                Container(
                  color: Colors.black38,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        SizedBox(height: 12),
                        Text('Loading video...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else if (hasVideo && videoError != null)
            // Video error state - fallback to image
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: p.thumbnailUrl ?? imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFF1F2937)),
                  errorWidget: (_, __, ___) => Container(color: const Color(0xFF1F2937), child: const Icon(Icons.home, color: Colors.white24, size: 60)),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(videoError!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            // Regular image
            CachedNetworkImage(
              imageUrl: p.thumbnailUrl ?? imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: const Color(0xFF1F2937)),
              errorWidget: (_, __, ___) => Container(color: const Color(0xFF1F2937), child: const Icon(Icons.home, color: Colors.white24, size: 60)),
            ),

          // Gradient — from-black/40 via-transparent to-black/60
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Colors.transparent, Color(0x99000000)],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // Video progress indicator (top)
          if (hasVideo && isVideoInitialized && videoController != null)
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: _VideoProgressBar(controller: videoController!),
            ),

          // Double-tap heart animation
          if (showHeartAnimation)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: 1.0 - value,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 120,
                      ),
                    ),
                  );
                },
              ),
            ),

          // Sponsored badge (top-left)
          if (p.featured)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'SPONSORED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          // Availability badge (top-left, below sponsored if exists)
          Positioned(
            top: MediaQuery.of(context).padding.top + (p.featured ? 50 : 16),
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: p.available 
                    ? const Color(0xFF10B981).withOpacity(0.9)
                    : const Color(0xFFEF4444).withOpacity(0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    p.available ? Icons.check_circle : Icons.cancel,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    p.available 
                        ? (p.availableFrom != null ? 'Available ${p.availableFrom}' : 'Available Now')
                        : 'Not Available',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom-left: landlord + property info
          if (showDetails)
            Positioned(
              left: 16, right: isDesktop ? 16 : 80, bottom: isDesktop ? 24 : 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Landlord row
                  Row(children: [
                    CircleAvatar(radius: 16, backgroundImage: NetworkImage(landlordAvatarUrl)),
                    const SizedBox(width: 8),
                    Text(landlordName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
                    if (p.landlordVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.check_circle, size: 14, color: Color(0xFF60A5FA)),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  // Property name
                  Text(p.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14, shadows: [Shadow(blurRadius: 4, color: Colors.black54)]), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  // Description (if available)
                  if (p.description != null && p.description!.isNotEmpty) ...[
                    Text(
                      p.description!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, shadows: [Shadow(blurRadius: 4, color: Colors.black54)]),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Location
                  Row(children: [
                    const Icon(Icons.location_on, size: 12, color: Colors.white70),
                    const SizedBox(width: 3),
                    Text(p.location, style: const TextStyle(color: Colors.white70, fontSize: 12, shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
                  ]),
                  const SizedBox(height: 6),
                  // View count
                  Row(children: [
                    const Icon(Icons.visibility, size: 12, color: Colors.white60),
                    const SizedBox(width: 4),
                    Text('${_formatCount(p.views)} views', style: const TextStyle(color: Colors.white60, fontSize: 11, shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
                  ]),
                ],
              ),
            ),

          // Mobile action buttons — right side, inside video
          if (!isDesktop)
            Positioned(
              right: 8, bottom: 80,
              child: Column(children: [
                if (hasVideo)
                  _ActionBtn(icon: isMuted ? Icons.volume_off : Icons.volume_up, label: isMuted ? 'Unmute' : 'Mute', onTap: onMute),
                if (hasVideo) const SizedBox(height: 16),
                _ActionBtn(icon: isFav ? Icons.favorite : Icons.favorite_border, label: '${_formatCount(p.likes)}', color: isFav ? Colors.red : Colors.white, onTap: onFav),
                const SizedBox(height: 16),
                _ActionBtn(icon: Icons.share_outlined, label: 'Share', onTap: onShare),
                const SizedBox(height: 16),
                _ActionBtn(icon: Icons.phone, label: 'Contact', color: Colors.white, bgColor: const Color(0xFF2563EB), onTap: onContact),
              ]),
            ),

          // View details button
          Positioned(
            bottom: 24, left: 16,
            child: GestureDetector(
              onTap: onDetails,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('View Details', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

// ── DESKTOP ACTION BUTTONS (outside video on right) ───────────────────────────
class _DesktopActions extends StatelessWidget {
  final bool isFav, isMuted, hasVideo;
  final int likes, views;
  final VoidCallback onFav, onMute, onShare, onContact;
  const _DesktopActions({required this.isFav, required this.isMuted, required this.hasVideo, required this.likes, required this.views, required this.onFav, required this.onMute, required this.onShare, required this.onContact});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasVideo) _ActionBtn(icon: isMuted ? Icons.volume_off : Icons.volume_up, label: isMuted ? 'Unmute' : 'Mute', onTap: onMute, size: 36),
        if (hasVideo) const SizedBox(height: 12),
        _ActionBtn(icon: isFav ? Icons.favorite : Icons.favorite_border, label: _formatCount(likes), color: isFav ? Colors.red : Colors.white, onTap: onFav, size: 36),
        const SizedBox(height: 12),
        _ActionBtn(icon: Icons.share_outlined, label: 'Share', onTap: onShare, size: 36),
        const SizedBox(height: 12),
        _ActionBtn(icon: Icons.phone, label: 'Contact', bgColor: const Color(0xFF2563EB), onTap: onContact, size: 36),
        const SizedBox(height: 20),
        // View count
        Column(children: [
          const Icon(Icons.visibility, color: Colors.white60, size: 20),
          const SizedBox(height: 4),
          Text(_formatCount(views), style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ]),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

// ── ACTION BUTTON ─────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? bgColor;
  final VoidCallback onTap;
  final double size;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
    this.bgColor,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: bgColor ?? Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: size * 0.5),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, shadows: [Shadow(blurRadius: 4, color: Colors.black87)])),
      ]),
    );
  }
}

// ── VIDEO PROGRESS BAR ────────────────────────────────────────────────────────
class _VideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoProgressBar({required this.controller});

  @override
  State<_VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<_VideoProgressBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateProgress);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateProgress);
    super.dispose();
  }

  void _updateProgress() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.controller.value.duration;
    final position = widget.controller.value.position;
    
    if (duration.inMilliseconds == 0) return const SizedBox.shrink();
    
    final progress = position.inMilliseconds / duration.inMilliseconds;

    return Container(
      height: 2,
      color: Colors.white24,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(color: Colors.white),
      ),
    );
  }
}
