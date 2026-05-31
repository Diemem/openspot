# Explore Screen - Promotional Feed

## Overview
The Explore screen is a TikTok-style vertical swipe feed designed for promotional content. It's where landlords and real estate agencies post video ads and featured properties to attract tenants.

## Purpose
- **NOT** a property discovery tool (that's the Map screen)
- **IS** a promotional/advertising platform
- Drives engagement and brand awareness
- Monetization opportunity through sponsored content

## Features

### ✅ Core Features (Implemented)

#### 1. Video Playback
- Auto-play when card is active
- Auto-pause when user swipes away
- Looping videos
- Mute/unmute controls (only for videos)
- Fallback to images if video fails

#### 2. Video Optimization
- **Preloading**: Next video loads in background while user watches current
- **Memory Management**: Videos 2+ positions away are automatically disposed
- **Loading States**: Shows thumbnail with loading spinner while video initializes
- **Error Handling**: Falls back to image with error message if video fails

#### 3. Engagement Features
- **Double-tap to like**: Instagram-style heart animation
- **Like button**: Traditional favorite toggle
- **Share button**: Deep link sharing with property details
- **Contact button**: Direct call or message landlord
- **View Details**: Navigate to full property page

#### 4. Analytics & Tracking
- **View Tracking**: Counts view after 2+ seconds of watching
- **Like Tracking**: Increments/decrements like count in database
- **Detailed Analytics**: `property_views` table tracks:
  - Property ID
  - User ID (if logged in)
  - Timestamp
  - Source (explore, home, map)
  - Session ID
  - Device type

#### 5. UI/UX Enhancements
- **Video Progress Bar**: Thin white bar at top (Instagram Stories style)
- **Sponsored Badge**: Gold "SPONSORED" tag for featured properties
- **Availability Badge**: Green "Available Now" or Red "Not Available"
- **Description Overlay**: Shows property description (max 3 lines)
- **View Count**: Formatted count (1.2K, 1.5M)
- **Landlord Info**: Avatar, name, verification badge

#### 6. Quick Filters
- Filter by property type (Apartment, Studio, Bedsitter, House)
- Floating filter button (top-right)
- Dropdown menu with property types
- Instant filtering without page reload

#### 7. Desktop Support
- 9:16 aspect ratio video container (centered)
- Action buttons on right side (outside video)
- Responsive layout for tablets and desktops

### 🔄 Performance Optimizations

#### Memory Management
```dart
// Automatic cleanup of distant videos
void _cleanupDistantVideos(int currentIndex) {
  for (var index in _videoControllers.keys) {
    if ((index - currentIndex).abs() > 2) {
      _videoControllers[index]?.dispose();
      _videoControllers.remove(index);
    }
  }
}
```

#### Video Preloading
```dart
// Preload next video while user watches current
void _preloadVideo(int index, Property property) {
  if (property.videoUrl == null) return;
  if (_videoControllers.containsKey(index)) return;
  
  final controller = VideoPlayerController.networkUrl(Uri.parse(property.videoUrl!));
  _videoControllers[index] = controller;
  controller.initialize();
}
```

#### View Tracking (Debounced)
```dart
// Only track view after 2 seconds
Future.delayed(const Duration(seconds: 2), () {
  if (_currentIndex == index && mounted) {
    final propertyId = properties[index].id;
    if (!_viewedProperties.contains(propertyId)) {
      _viewedProperties.add(propertyId);
      _trackView(propertyId);
    }
  }
});
```

## Database Schema

### Properties Table (Engagement Fields)
```sql
CREATE TABLE properties (
  ...
  views INTEGER DEFAULT 0,
  likes INTEGER DEFAULT 0,
  featured BOOLEAN DEFAULT false,
  video_url TEXT,
  ...
);
```

### Property Views Table (Analytics)
```sql
CREATE TABLE property_views (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID NOT NULL REFERENCES properties(id),
  user_id UUID REFERENCES auth.users(id),
  viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  source TEXT DEFAULT 'explore',
  session_id TEXT,
  device_type TEXT
);
```

### Database Functions
```sql
-- Increment view count
CREATE FUNCTION increment_property_views(property_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE properties SET views = views + 1 WHERE id = property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Increment like count
CREATE FUNCTION increment_property_likes(property_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE properties SET likes = likes + 1 WHERE id = property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Decrement like count
CREATE FUNCTION decrement_property_likes(property_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE properties SET likes = GREATEST(likes - 1, 0) WHERE id = property_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Monetization Opportunities

### 1. Sponsored Content
- Landlords pay KES 500-2000 to feature property for 7 days
- Appears with "SPONSORED" badge
- Priority placement (shown first)
- **Revenue**: 100 sponsors × KES 1000 = KES 100K/month

### 2. Promoted Videos
- Real estate agencies pay for video ads
- Full-screen promotional content
- Every 5th property is a promoted video
- **Revenue**: KES 50-200 per 1000 views

### 3. Analytics Dashboard (Premium)
- Show landlords their property performance
- Views, likes, contact clicks, conversion rates
- Charge KES 200/month for premium analytics
- **Revenue**: 500 landlords × KES 200 = KES 100K/month

## Cost Considerations

### Video Bandwidth (Critical)
**Problem**: Videos are 10-50MB each
**Impact**: 
- 100K users × 20 videos viewed = 2M video plays
- 2M × 20MB = 40TB bandwidth
- AWS: ~$3,600/month

**Solution**:
- Use video CDN (Cloudflare Stream, Bunny.net)
- Compress videos server-side (max 720p)
- Adaptive bitrate (lower quality on slow connections)
- **Cost**: $500-1000/month at scale (vs $3600)

### Video Storage
**Problem**: Landlords upload 4K videos (500MB+)
**Solution**:
- Limit uploads to 100MB, 60 seconds max
- Auto-compress to 720p
- Delete videos after 30 days (promotional content expires)
- **Saves**: Thousands in storage costs

## Content Moderation

### Manual Review (Pre-Launch)
- All videos reviewed before going live
- Check for inappropriate content
- Verify property legitimacy
- **Cost**: KES 50-100 per video review

### Automated Moderation (Post-Launch)
- AWS Rekognition for explicit content detection
- Automatic flagging of suspicious content
- User report system
- **Cost**: KES 10-20 per video

## User Flow

```
1. User opens Explore screen
   ↓
2. First property auto-plays (if video)
   ↓
3. User watches for 2+ seconds → View tracked
   ↓
4. User double-taps → Like tracked, heart animation
   ↓
5. User swipes up → Next property
   ↓
6. Next video preloaded → Instant playback
   ↓
7. User taps "Contact" → Call or message landlord
   ↓
8. User taps "View Details" → Full property page
```

## Technical Architecture

### State Management
```dart
// Separate provider for Explore screen
final exploreSearchControllerProvider = 
  StateNotifierProvider<SearchController, AsyncValue<List<Property>>>((ref) {
    return SearchController(ref, exploreSearchContextProvider);
  });
```

### Video Controller Management
```dart
// Centralized controller map in parent state
final Map<int, VideoPlayerController> _videoControllers = {};

// Shared across cards for efficient memory usage
_VideoCard(
  videoController: _videoControllers[index],
  onVideoControllerCreated: (controller) {
    _videoControllers[index] = controller;
  },
)
```

### Analytics Integration
```dart
// Property Repository
Future<void> incrementViews(String propertyId) async {
  await SupabaseService.client.rpc('increment_property_views', 
    params: {'property_id': propertyId}
  );
}

// Favorites Provider
Future<void> toggle(String userId, String propertyId) async {
  if (isFav) {
    await _service.removeFavorite(userId, propertyId);
    await ref.read(propertyRepositoryProvider).decrementLikes(propertyId);
  } else {
    await _service.addFavorite(userId, propertyId);
    await ref.read(propertyRepositoryProvider).incrementLikes(propertyId);
  }
}
```

## Future Enhancements

### Phase 5: Personalization (Post-PMF)
- [ ] Following system (follow landlords/agencies)
- [ ] For You algorithm (personalized feed based on views)
- [ ] Recommended properties based on user behavior
- [ ] Machine learning for better recommendations

### Phase 6: Advanced Features
- [ ] Swipe right to save (Tinder-style)
- [ ] Swipe left to skip/hide
- [ ] Video chapters (for property tours)
- [ ] 360° virtual tours
- [ ] Live streaming (landlord Q&A sessions)

### Phase 7: Landlord Tools
- [ ] Analytics dashboard
- [ ] A/B testing for thumbnails
- [ ] Scheduled posts
- [ ] Boost/promote buttons
- [ ] Response rate tracking

## Testing Checklist

### Functional Testing
- [ ] Video plays automatically when card is active
- [ ] Video pauses when user swipes away
- [ ] Mute/unmute works correctly
- [ ] Double-tap to like shows heart animation
- [ ] Share button opens share dialog
- [ ] Contact button calls/messages landlord
- [ ] View Details navigates to property page
- [ ] Filters work correctly
- [ ] Loading states show properly
- [ ] Error states show fallback image

### Performance Testing
- [ ] Memory usage stays under 200MB
- [ ] Video preloading works smoothly
- [ ] Distant videos are disposed properly
- [ ] No frame drops during swipe
- [ ] App doesn't crash with 100+ properties

### Analytics Testing
- [ ] Views tracked after 2 seconds
- [ ] Likes increment in database
- [ ] Unlikes decrement in database
- [ ] No duplicate view tracking
- [ ] Analytics table populated correctly

### Edge Cases
- [ ] No internet connection
- [ ] Slow network (2G)
- [ ] Video URL is invalid
- [ ] Video fails to load
- [ ] User not logged in (like button)
- [ ] Empty property list
- [ ] All properties filtered out

## Deployment Checklist

### Pre-Launch
- [ ] Run database migration (`add_engagement_tracking.sql`)
- [ ] Test video CDN integration
- [ ] Set up content moderation workflow
- [ ] Configure video upload limits (100MB, 60s)
- [ ] Test analytics dashboard
- [ ] Set up monitoring/alerts

### Launch
- [ ] Enable sponsored content feature
- [ ] Onboard first 10 landlords
- [ ] Monitor video bandwidth costs
- [ ] Track engagement metrics
- [ ] Collect user feedback

### Post-Launch
- [ ] Optimize video compression
- [ ] Implement adaptive bitrate
- [ ] Add more filters
- [ ] Build landlord analytics dashboard
- [ ] Scale CDN based on usage

## Support & Maintenance

### Monitoring
- Video playback errors
- View tracking failures
- Like/unlike failures
- Memory usage spikes
- Bandwidth costs

### Alerts
- Video CDN downtime
- Database function errors
- High memory usage (>300MB)
- Bandwidth exceeds budget
- Content moderation queue backlog

## Contact
For questions or issues, contact the development team.
