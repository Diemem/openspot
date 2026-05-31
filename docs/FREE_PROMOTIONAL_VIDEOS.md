# Free Promotional Videos System

## Overview
When landlords list a property on OpenSpot, they get **1-2 FREE promotional videos** that appear in the Explore feed for **7 days**. This is a powerful growth strategy that:

1. **Incentivizes listings** - Free promotion attracts more landlords
2. **Fills Explore feed** - Ensures constant fresh content
3. **Drives engagement** - More videos = more user time in app
4. **Builds trust** - Landlords see immediate value
5. **Creates network effects** - More properties → more users → more properties

---

## How It Works

### For Landlords

#### Step 1: List Property
```
Landlord creates new property listing
  ↓
Fills in basic info (title, price, location)
  ↓
Uploads photos (minimum 3)
  ↓
**NEW STEP**: Upload promotional videos (optional, max 2)
  ↓
Reviews and publishes
```

#### Step 2: Video Upload
```
Requirements:
- Max 60 seconds duration
- Max 100MB file size
- Vertical format (9:16) recommended
- Good lighting and clear audio

Tips shown:
- Show best features first
- Add text overlays with price
- Keep it short (30-45 seconds ideal)
- Film during daytime
```

#### Step 3: Auto-Approval
```
If landlord is verified:
  → Auto-approve immediately
  → Video goes live in Explore feed
  → Active for 7 days
  → Analytics tracking starts

If landlord is unverified:
  → Pending manual review (24-48 hours)
  → Admin approves/rejects
  → If approved, goes live for 7 days
```

#### Step 4: Promotion Period
```
Day 1-7: Video appears in Explore feed
  ↓
Users see video mixed with other content
  ↓
Analytics tracked (views, likes, contacts)
  ↓
Day 7: Video expires automatically
  ↓
Landlord can upgrade to paid sponsorship
```

### For Users

#### Explore Feed Mix
```
Property 1: Regular listing
Property 2: Regular listing
Property 3: FREE PROMO (landlord's video)
Property 4: Regular listing
Property 5: SPONSORED (paid)
Property 6: Regular listing
Property 7: FREE PROMO (landlord's video)
...
```

**No visual difference** between free promos and regular listings - all look organic.

---

## Database Schema

### Table: free_promotional_videos
```sql
CREATE TABLE free_promotional_videos (
  id UUID PRIMARY KEY,
  property_id UUID REFERENCES properties(id),
  landlord_id UUID REFERENCES auth.users(id),
  video_url TEXT NOT NULL,
  video_order INTEGER (1 or 2),
  status TEXT (pending, approved, rejected, expired),
  
  -- Promotion period
  starts_at TIMESTAMP,
  expires_at TIMESTAMP (starts_at + 7 days),
  
  -- Analytics
  impressions INTEGER,
  views INTEGER,
  likes INTEGER,
  shares INTEGER,
  contacts INTEGER,
  avg_watch_time INTEGER,
  
  created_at TIMESTAMP,
  approved_at TIMESTAMP,
  approved_by UUID
);
```

### Indexes
```sql
-- Active promotions (for Explore feed)
idx_free_promos_active ON (status, expires_at)
  WHERE status = 'approved' AND expires_at > NOW()

-- Landlord's videos
idx_free_promos_landlord ON (landlord_id, created_at DESC)

-- Property's videos
idx_free_promos_property ON (property_id)
```

---

## Implementation Details

### 1. Property Listing Flow

**File**: `lib/features/landlord/screens/add_property_screen.dart`

```dart
// Step 3: Free Promotional Videos
Widget _buildFreeVideosStep() {
  return Column(
    children: [
      // Promotional banner
      Container(
        child: Text('🎉 FREE Promotional Videos!'),
      ),
      
      // Video requirements
      _buildRequirements(),
      
      // Video upload (max 2)
      _buildVideoUpload(),
      
      // Pro tips
      _buildProTips(),
    ],
  );
}

// Upload video
Future<void> _pickVideo() async {
  if (_freeVideos.length >= 2) {
    showError('Maximum 2 videos allowed');
    return;
  }
  
  final video = await ImagePicker().pickVideo();
  
  // Validate size (max 100MB)
  if (fileSize > 100 * 1024 * 1024) {
    showError('Video must be less than 100MB');
    return;
  }
  
  setState(() => _freeVideos.add(video));
}

// Publish property with videos
Future<void> _publishProperty() async {
  // 1. Upload images to storage
  final imageUrls = await uploadImages(_images);
  
  // 2. Upload videos to storage
  final videoUrls = await uploadVideos(_freeVideos);
  
  // 3. Create property
  final propertyId = await createProperty({
    title: _titleController.text,
    price: _priceController.text,
    images: imageUrls,
    // ... other fields
  });
  
  // 4. Create free promotional videos
  for (int i = 0; i < videoUrls.length; i++) {
    await createFreePromo({
      property_id: propertyId,
      landlord_id: currentUser.id,
      video_url: videoUrls[i],
      video_order: i + 1,
    });
  }
  
  showSuccess('Property published with ${videoUrls.length} FREE promotional videos!');
}
```

### 2. Explore Feed Integration

**File**: `lib/features/explore/screens/explore_screen.dart`

```dart
// Fetch properties + free promos
Future<List<ExploreItem>> _fetchExploreContent() async {
  // Get regular properties
  final properties = await fetchProperties();
  
  // Get active free promos
  final freePromos = await supabase
    .rpc('get_active_free_promos', params: {'limit_count': 50});
  
  // Mix them together
  final exploreItems = <ExploreItem>[];
  
  int promoIndex = 0;
  for (int i = 0; i < properties.length; i++) {
    // Add regular property
    exploreItems.add(ExploreItem.property(properties[i]));
    
    // Every 3rd item, add a free promo
    if ((i + 1) % 3 == 0 && promoIndex < freePromos.length) {
      exploreItems.add(ExploreItem.freePromo(freePromos[promoIndex]));
      promoIndex++;
    }
  }
  
  return exploreItems;
}

// Track free promo view
void _trackFreePromoView(String promoId) {
  Future.delayed(Duration(seconds: 2), () {
    if (mounted && _currentPromoId == promoId) {
      supabase.rpc('track_free_promo_view', params: {'promo_id': promoId});
    }
  });
}
```

### 3. Auto-Approval Logic

**Database Trigger**:
```sql
CREATE TRIGGER trigger_auto_approve_free_promo
  BEFORE INSERT ON free_promotional_videos
  FOR EACH ROW
  EXECUTE FUNCTION auto_approve_free_promo();

CREATE FUNCTION auto_approve_free_promo()
RETURNS TRIGGER AS $$
BEGIN
  -- Auto-approve if landlord is verified
  IF EXISTS (
    SELECT 1 FROM properties p
    WHERE p.id = NEW.property_id AND p.landlord_verified = true
  ) THEN
    NEW.status := 'approved';
    NEW.starts_at := NOW();
    NEW.expires_at := NOW() + INTERVAL '7 days';
  ELSE
    NEW.status := 'pending';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### 4. Expiry Management

**Cron Job** (runs daily):
```sql
CREATE FUNCTION expire_old_promos()
RETURNS void AS $$
BEGIN
  UPDATE free_promotional_videos
  SET status = 'expired'
  WHERE status = 'approved'
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Schedule daily at midnight
SELECT cron.schedule(
  'expire-old-promos',
  '0 0 * * *',
  'SELECT expire_old_promos()'
);
```

### 5. Analytics Dashboard

**File**: `lib/features/landlord/screens/property_analytics_screen.dart`

```dart
// Show free promo performance
Widget _buildFreePromoAnalytics() {
  return Container(
    child: Column(
      children: [
        Text('FREE Promotional Video Performance'),
        
        // Metrics
        _MetricCard(
          label: 'Impressions',
          value: analytics.impressions,
          icon: Icons.visibility,
        ),
        _MetricCard(
          label: 'Views (2+ sec)',
          value: analytics.views,
          icon: Icons.play_circle,
        ),
        _MetricCard(
          label: 'Contacts',
          value: analytics.contacts,
          icon: Icons.phone,
        ),
        
        // Days remaining
        Text('${analytics.daysRemaining} days remaining'),
        
        // Upgrade prompt
        if (analytics.daysRemaining <= 2) {
          ElevatedButton(
            onPressed: () => upgradeToPaidSponsorship(),
            child: Text('Extend with Paid Sponsorship'),
          ),
        ],
      ],
    ),
  );
}
```

---

## Business Logic

### Limits & Rules

1. **Per Property**: Max 2 videos
2. **Duration**: 7 days from approval
3. **File Size**: Max 100MB per video
4. **Video Length**: Max 60 seconds
5. **Format**: Any (MP4, MOV, WebM)
6. **Approval**: Auto for verified, manual for unverified
7. **Expiry**: Automatic after 7 days

### Content Moderation

**Auto-Approve** (verified landlords):
- Landlord has verified badge
- Property has complete info
- Video meets technical requirements
- Goes live immediately

**Manual Review** (unverified landlords):
- Admin reviews within 24-48 hours
- Checks for:
  - Appropriate content
  - Accurate property representation
  - No misleading information
  - Quality standards
- Approves or rejects with reason

**Rejection Reasons**:
- Inappropriate content
- Misleading information
- Poor quality (too dark, shaky)
- Not related to property
- Violates terms of service

### Upgrade Path

After 7 days, landlord sees:
```
Your FREE promotion has expired!

Performance:
- 1,245 views
- 67 likes
- 23 contacts

Want more exposure?
[Upgrade to Sponsored] (KES 1,000/week)
- Priority placement
- Extended duration
- Advanced analytics
```

---

## Growth Strategy

### Phase 1: Launch (Month 1-3)
**Goal**: Fill Explore feed with content

- Promote free videos heavily
- Email all landlords
- In-app banners
- Social media campaign

**Target**: 500 free promos/month

### Phase 2: Optimize (Month 4-6)
**Goal**: Improve quality and conversion

- Analyze performance data
- Identify best practices
- Create video templates
- Offer editing tips

**Target**: 1,000 free promos/month

### Phase 3: Monetize (Month 7-12)
**Goal**: Convert to paid sponsorships

- Show upgrade prompts
- Offer discounts for renewals
- Create premium tiers
- Build landlord loyalty

**Target**: 20% conversion to paid

---

## Revenue Impact

### Direct Revenue
```
Free promos don't generate direct revenue
BUT they drive:
- More property listings
- More user engagement
- More paid sponsorships (upgrades)
```

### Indirect Revenue
```
Month 1:
- 500 free promos
- 50 upgrade to paid (10% conversion)
- 50 × KES 1,000 = KES 50,000

Month 6:
- 1,000 free promos
- 200 upgrade to paid (20% conversion)
- 200 × KES 1,000 = KES 200,000

Month 12:
- 2,000 free promos
- 600 upgrade to paid (30% conversion)
- 600 × KES 1,000 = KES 600,000
```

### User Acquisition
```
More content → More users → More landlords → More content
(Network effect flywheel)

Estimated:
- 1 free promo = 500-1000 views
- 1000 views = 10-20 new users
- 500 free promos = 5,000-10,000 new users/month
```

---

## Success Metrics

### Landlord Metrics
- % of listings with videos (target: 40%+)
- Average videos per listing (target: 1.5)
- Video approval rate (target: 90%+)
- Upgrade conversion rate (target: 20%+)

### User Metrics
- Explore feed engagement (target: 3+ min/session)
- Video completion rate (target: 40%+)
- Contact rate from videos (target: 2%+)
- Share rate (target: 1%+)

### Platform Metrics
- Active free promos (target: 500+)
- Daily new videos (target: 50+)
- Video quality score (target: 4.0+/5.0)
- Moderation queue time (target: <24 hours)

---

## Technical Considerations

### Storage Costs
```
Assumptions:
- Average video size: 50MB
- 500 videos/month
- 7-day retention

Storage needed:
500 videos × 50MB = 25GB/month
25GB × 12 months = 300GB/year

Cost (AWS S3):
300GB × $0.023/GB = $6.90/year

Bandwidth (if each video viewed 500 times):
500 videos × 500 views × 50MB = 12.5TB
12.5TB × $0.09/GB = $1,125/month

Solution: Use CDN (Cloudflare/Bunny)
12.5TB × $0.01/GB = $125/month (10x cheaper)
```

### Video Processing
```
Upload → Compress → Generate thumbnail → Store → Serve

Processing pipeline:
1. User uploads video (original quality)
2. Server compresses to 720p (FFmpeg)
3. Generate thumbnail (first frame)
4. Upload to CDN
5. Delete original
6. Return CDN URL

Cost per video:
- Processing: $0.01
- Storage: $0.001/month
- CDN: $0.01/1000 views

Total: ~$0.02 per video
```

---

## Admin Dashboard

### Pending Reviews
```
Video ID | Property | Landlord | Uploaded | Actions
---------|----------|----------|----------|--------
abc123   | 2BR Apt  | John Doe | 2h ago   | [Approve] [Reject]
def456   | Studio   | Jane S.  | 5h ago   | [Approve] [Reject]
```

### Active Promotions
```
Video ID | Property | Views | Likes | Expires | Actions
---------|----------|-------|-------|---------|--------
ghi789   | 1BR Apt  | 1,245 | 67    | 3 days  | [Extend] [Remove]
jkl012   | House    | 890   | 45    | 5 days  | [Extend] [Remove]
```

### Analytics
```
Total free promos: 1,234
Active: 456
Pending: 23
Expired: 755

Avg views per video: 850
Avg watch time: 35 seconds
Conversion to paid: 18%
```

---

## FAQ

**Q: Why give away free promotions?**
A: To incentivize listings and fill Explore feed with content. More content = more users = more revenue.

**Q: Won't this cannibalize paid sponsorships?**
A: No. Free promos are limited (7 days, 2 videos). Landlords who see results will upgrade to paid for extended exposure.

**Q: How do we prevent abuse?**
A: Limits (2 videos per property), moderation (manual review for unverified), and quality standards.

**Q: What if Explore feed is all free promos?**
A: We mix them with regular listings (1 free promo per 3 regular properties) and paid sponsorships.

**Q: How do we ensure video quality?**
A: Provide templates, tips, and examples. Reject low-quality videos during moderation.

---

## Next Steps

1. **Implement video upload** in property listing flow
2. **Create moderation dashboard** for admins
3. **Set up video processing pipeline** (compression, thumbnails)
4. **Integrate with Explore feed** (mix free promos with regular content)
5. **Build analytics dashboard** for landlords
6. **Create upgrade flow** (free → paid sponsorship)
7. **Launch marketing campaign** to promote free videos

---

**This is a game-changer for OpenSpot.** Free promotional videos will:
- Attract more landlords (free value)
- Fill Explore feed (more content)
- Drive user engagement (more time in app)
- Create upgrade path (free → paid)
- Build network effects (more properties → more users)

**Estimated Impact**: 2-3x increase in property listings within 6 months.
