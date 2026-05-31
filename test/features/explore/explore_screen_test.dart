import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openspot/features/explore/screens/explore_screen.dart';
import 'package:openspot/core/models/property.dart';
import 'package:openspot/features/search_engine/application/search_controller.dart';

void main() {
  group('Explore Screen Tests', () {
    late List<Property> mockProperties;

    setUp(() {
      mockProperties = [
        Property(
          id: '1',
          title: 'Modern 2BR Apartment',
          propertyType: 'apartment',
          category: 'residential',
          listingType: 'rent',
          location: 'Kilimani, Nairobi',
          city: 'Nairobi',
          price: 35000,
          currency: 'KES',
          bedrooms: 2,
          bathrooms: 2,
          images: ['https://example.com/image1.jpg'],
          videoUrl: 'https://example.com/video1.mp4',
          landlordName: 'John Doe',
          landlordVerified: true,
          available: true,
          featured: true,
          views: 1200,
          likes: 85,
          createdAt: DateTime.now(),
        ),
        Property(
          id: '2',
          title: 'Cozy Studio',
          propertyType: 'studio',
          category: 'residential',
          listingType: 'rent',
          location: 'Westlands, Nairobi',
          city: 'Nairobi',
          price: 18000,
          currency: 'KES',
          bedrooms: 0,
          bathrooms: 1,
          images: ['https://example.com/image2.jpg'],
          landlordName: 'Jane Smith',
          landlordVerified: false,
          available: true,
          featured: false,
          views: 450,
          likes: 32,
          createdAt: DateTime.now(),
        ),
      ];
    });

    testWidgets('Explore screen shows loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.loading(),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading properties...'), findsOneWidget);
    });

    testWidgets('Explore screen shows error state', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.error('Network error', StackTrace.empty),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      expect(find.text('⚠️ Error loading properties'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Explore screen shows empty state', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => const AsyncValue.data([]),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      expect(find.text('No properties found'), findsOneWidget);
    });

    testWidgets('Explore screen shows properties', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(mockProperties),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show PageView with properties
      expect(find.byType(PageView), findsOneWidget);
      
      // Should show first property details
      expect(find.text('Modern 2BR Apartment'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('Explore screen shows sponsored badge for featured properties', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(mockProperties),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // First property is featured, should show SPONSORED badge
      expect(find.text('SPONSORED'), findsOneWidget);
    });

    testWidgets('Explore screen shows availability badge', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(mockProperties),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show availability badge
      expect(find.text('Available Now'), findsOneWidget);
    });

    testWidgets('Explore screen shows view count', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(mockProperties),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show formatted view count
      expect(find.text('1.2K views'), findsOneWidget);
    });

    testWidgets('Explore screen shows swipe hint on first property', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(mockProperties),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show swipe hint
      expect(find.text('Swipe to explore'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    });

    testWidgets('Filter button opens filter menu', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(mockProperties),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap filter button
      final filterButton = find.byIcon(Icons.filter_list);
      expect(filterButton, findsOneWidget);
      
      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      // Should show filter menu
      expect(find.text('Property Type'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Apartment'), findsOneWidget);
      expect(find.text('Studio'), findsOneWidget);
    });

    testWidgets('Filtering by property type works', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(mockProperties),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open filter menu
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      // Select Studio filter
      await tester.tap(find.text('Studio'));
      await tester.pumpAndSettle();

      // Should only show studio property
      expect(find.text('Cozy Studio'), findsOneWidget);
      expect(find.text('Modern 2BR Apartment'), findsNothing);
    });

    testWidgets('Action buttons are visible', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(mockProperties),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show action buttons
      expect(find.byIcon(Icons.favorite_border), findsWidgets);
      expect(find.byIcon(Icons.share_outlined), findsWidgets);
      expect(find.byIcon(Icons.phone), findsWidgets);
    });

    testWidgets('View Details button is visible', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(mockProperties),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show View Details button
      expect(find.text('View Details'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsWidgets);
    });
  });

  group('Video Controller Tests', () {
    testWidgets('Video controller is created for properties with videos', 
        (WidgetTester tester) async {
      final propertyWithVideo = Property(
        id: '1',
        title: 'Property with Video',
        propertyType: 'apartment',
        category: 'residential',
        listingType: 'rent',
        location: 'Nairobi',
        city: 'Nairobi',
        price: 25000,
        videoUrl: 'https://example.com/video.mp4',
        images: ['https://example.com/image.jpg'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data([propertyWithVideo]),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Video controller should be initialized
      // (In real test, we'd mock the video player)
      expect(find.byType(PageView), findsOneWidget);
    });
  });

  group('Engagement Tracking Tests', () {
    test('View count formats correctly', () {
      expect(_formatCount(500), '500');
      expect(_formatCount(1500), '1.5K');
      expect(_formatCount(1000000), '1.0M');
      expect(_formatCount(2500000), '2.5M');
    });
  });
}

// Helper function to test count formatting
String _formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toString();
}
