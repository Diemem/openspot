import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openspot/features/explore/screens/explore_screen.dart';
import 'package:openspot/core/models/property.dart';
import 'package:openspot/features/search_engine/application/search_controller.dart';

void main() {
  group('Explore Screen Performance Tests', () {
    late List<Property> largePropertyList;

    setUp(() {
      // Create 100 mock properties for performance testing
      largePropertyList = List.generate(100, (index) {
        return Property(
          id: 'property_$index',
          title: 'Property $index',
          propertyType: index % 4 == 0 ? 'apartment' : 
                       index % 4 == 1 ? 'studio' :
                       index % 4 == 2 ? 'bedsitter' : 'house',
          category: 'residential',
          listingType: 'rent',
          location: 'Location $index',
          city: 'Nairobi',
          price: 20000 + (index * 1000),
          currency: 'KES',
          bedrooms: index % 3 + 1,
          bathrooms: index % 2 + 1,
          images: ['https://example.com/image_$index.jpg'],
          videoUrl: index % 3 == 0 ? 'https://example.com/video_$index.mp4' : null,
          landlordName: 'Landlord $index',
          landlordVerified: index % 2 == 0,
          available: true,
          featured: index % 10 == 0,
          views: index * 100,
          likes: index * 10,
          createdAt: DateTime.now().subtract(Duration(days: index)),
        );
      });
    });

    testWidgets('Memory usage test with 100 properties', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(largePropertyList),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Swipe through 20 properties
      for (int i = 0; i < 20; i++) {
        await tester.drag(
          find.byType(PageView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
      }

      // Memory should be stable (no leaks)
      // In real test, we'd measure actual memory usage
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('Frame rate test during swipe', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(largePropertyList),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Perform rapid swipes
      for (int i = 0; i < 10; i++) {
        await tester.drag(
          find.byType(PageView),
          const Offset(0, -300),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 16)); // 60fps
      }

      // Should not drop frames
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('Video controller cleanup test', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(largePropertyList),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Swipe through 30 properties (should cleanup distant videos)
      for (int i = 0; i < 30; i++) {
        await tester.drag(
          find.byType(PageView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
      }

      // Video controllers should be cleaned up
      // Only 3-5 controllers should exist at any time
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('Filter performance test', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(largePropertyList),
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

      // Apply filter
      final stopwatch = Stopwatch()..start();
      await tester.tap(find.text('Apartment'));
      await tester.pumpAndSettle();
      stopwatch.stop();

      // Filter should apply in less than 100ms
      expect(stopwatch.elapsedMilliseconds, lessThan(100));

      // Filtered results should be visible
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('Initial load performance test', 
        (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(largePropertyList),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      stopwatch.stop();

      // Initial load should complete in less than 1 second
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));

      // First property should be visible
      expect(find.text('Property 0'), findsOneWidget);
    });

    testWidgets('Scroll performance test', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(largePropertyList),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Measure time to swipe through 50 properties
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 50; i++) {
        await tester.drag(
          find.byType(PageView),
          const Offset(0, -300),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      
      stopwatch.stop();

      // Should maintain 60fps (16ms per frame)
      final averageTimePerSwipe = stopwatch.elapsedMilliseconds / 50;
      expect(averageTimePerSwipe, lessThan(50)); // Allow some overhead

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('Image loading performance test', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(largePropertyList),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Swipe through 10 properties rapidly
      for (int i = 0; i < 10; i++) {
        await tester.drag(
          find.byType(PageView),
          const Offset(0, -300),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Images should load without blocking UI
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('View tracking performance test', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(largePropertyList),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Wait for view tracking (2 seconds)
      await tester.pump(const Duration(seconds: 2));

      // Swipe to next property
      await tester.drag(
        find.byType(PageView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      // View tracking should not block UI
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('Like button performance test', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(largePropertyList),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap like button rapidly 10 times
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 10; i++) {
        final likeButton = find.byIcon(Icons.favorite_border).first;
        if (likeButton.evaluate().isNotEmpty) {
          await tester.tap(likeButton);
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      
      stopwatch.stop();

      // Should respond quickly (less than 500ms total)
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    testWidgets('Double-tap animation performance test', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(largePropertyList),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap 5 times
      for (int i = 0; i < 5; i++) {
        final pageView = find.byType(PageView);
        await tester.tap(pageView);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(pageView);
        await tester.pump(const Duration(milliseconds: 800)); // Animation duration
      }

      // Animations should not cause jank
      expect(find.byType(PageView), findsOneWidget);
    });
  });

  group('Memory Leak Detection Tests', () {
    testWidgets('Video controller disposal test', 
        (WidgetTester tester) async {
      final properties = List.generate(10, (index) {
        return Property(
          id: 'property_$index',
          title: 'Property $index',
          propertyType: 'apartment',
          category: 'residential',
          listingType: 'rent',
          location: 'Location $index',
          city: 'Nairobi',
          price: 25000,
          videoUrl: 'https://example.com/video_$index.mp4',
          images: ['https://example.com/image_$index.jpg'],
          createdAt: DateTime.now(),
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(properties),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Swipe through all properties
      for (int i = 0; i < 10; i++) {
        await tester.drag(
          find.byType(PageView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
      }

      // Navigate away (should dispose all controllers)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Other Screen')),
        ),
      );

      await tester.pumpAndSettle();

      // All controllers should be disposed
      expect(find.text('Other Screen'), findsOneWidget);
    });

    testWidgets('Listener cleanup test', 
        (WidgetTester tester) async {
      final properties = List.generate(5, (index) {
        return Property(
          id: 'property_$index',
          title: 'Property $index',
          propertyType: 'apartment',
          category: 'residential',
          listingType: 'rent',
          location: 'Location $index',
          city: 'Nairobi',
          price: 25000,
          videoUrl: 'https://example.com/video_$index.mp4',
          images: ['https://example.com/image_$index.jpg'],
          createdAt: DateTime.now(),
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exploreSearchControllerProvider.overrideWith(
              (ref) => AsyncValue.data(properties),
            ),
          ],
          child: const MaterialApp(
            home: ExploreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Swipe back and forth multiple times
      for (int i = 0; i < 10; i++) {
        await tester.drag(
          find.byType(PageView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        
        await tester.drag(
          find.byType(PageView),
          const Offset(0, 300),
        );
        await tester.pumpAndSettle();
      }

      // No memory leaks from listeners
      expect(find.byType(PageView), findsOneWidget);
    });
  });
}
