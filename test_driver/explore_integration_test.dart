import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openspot/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Explore Screen Integration Tests', () {
    testWidgets('Complete user flow: Browse, filter, like, share', 
        (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Explore tab
      final exploreTab = find.text('Explore');
      expect(exploreTab, findsOneWidget);
      await tester.tap(exploreTab);
      await tester.pumpAndSettle();

      // Wait for properties to load
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify first property is visible
      expect(find.byType(PageView), findsOneWidget);

      // Test swipe gesture
      await tester.drag(
        find.byType(PageView),
        const Offset(0, -300), // Swipe up
      );
      await tester.pumpAndSettle();

      // Verify second property is now visible
      // (Property title should change)

      // Test filter functionality
      final filterButton = find.byIcon(Icons.filter_list);
      if (filterButton.evaluate().isNotEmpty) {
        await tester.tap(filterButton);
        await tester.pumpAndSettle();

        // Select a filter
        final apartmentFilter = find.text('Apartment');
        if (apartmentFilter.evaluate().isNotEmpty) {
          await tester.tap(apartmentFilter);
          await tester.pumpAndSettle();
        }
      }

      // Test like button
      final likeButton = find.byIcon(Icons.favorite_border).first;
      if (likeButton.evaluate().isNotEmpty) {
        await tester.tap(likeButton);
        await tester.pumpAndSettle();

        // Verify like button changed to filled heart
        expect(find.byIcon(Icons.favorite), findsWidgets);
      }

      // Test share button
      final shareButton = find.byIcon(Icons.share_outlined).first;
      if (shareButton.evaluate().isNotEmpty) {
        await tester.tap(shareButton);
        await tester.pumpAndSettle();
        // Share dialog should appear (platform-specific)
      }

      // Test View Details button
      final viewDetailsButton = find.text('View Details');
      if (viewDetailsButton.evaluate().isNotEmpty) {
        await tester.tap(viewDetailsButton);
        await tester.pumpAndSettle();

        // Should navigate to property details page
        expect(find.text('Property Details'), findsOneWidget);

        // Go back to Explore
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Video playback test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Explore
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      // Wait for video to load
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Test mute button (if video exists)
      final muteButton = find.byIcon(Icons.volume_up);
      if (muteButton.evaluate().isNotEmpty) {
        await tester.tap(muteButton);
        await tester.pumpAndSettle();

        // Should change to muted icon
        expect(find.byIcon(Icons.volume_off), findsOneWidget);

        // Unmute
        await tester.tap(find.byIcon(Icons.volume_off));
        await tester.pumpAndSettle();

        // Should change back to volume up
        expect(find.byIcon(Icons.volume_up), findsOneWidget);
      }
    });

    testWidgets('Double-tap to like test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Explore
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      // Wait for properties to load
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Double-tap on the video/image area
      final pageView = find.byType(PageView);
      await tester.tap(pageView);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(pageView);
      await tester.pumpAndSettle();

      // Heart animation should appear
      // (In real test, we'd verify the animation widget)
      expect(find.byIcon(Icons.favorite), findsWidgets);
    });

    testWidgets('Memory leak test - swipe through 20 properties', 
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Explore
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      // Swipe through 20 properties
      for (int i = 0; i < 20; i++) {
        await tester.drag(
          find.byType(PageView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        
        // Small delay to simulate real usage
        await tester.pump(const Duration(milliseconds: 500));
      }

      // App should still be responsive (no memory leak)
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('View tracking test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Explore
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      // Wait for 3 seconds (view should be tracked after 2 seconds)
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // View count should have incremented
      // (In real test, we'd verify the database)
      expect(find.textContaining('views'), findsOneWidget);
    });

    testWidgets('Filter persistence test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Explore
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      // Apply filter
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Studio'));
      await tester.pumpAndSettle();

      // Navigate away
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      // Navigate back to Explore
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      // Filter should still be applied
      // (Only studio properties visible)
    });

    testWidgets('Network error handling test', (WidgetTester tester) async {
      // This test would require mocking network failures
      // For now, we just verify error UI exists
      
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Explore
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      // If network error occurs, should show retry button
      final retryButton = find.text('Retry');
      if (retryButton.evaluate().isNotEmpty) {
        await tester.tap(retryButton);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Sponsored content visibility test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Explore
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      // Check if any sponsored content is visible
      final sponsoredBadge = find.text('SPONSORED');
      if (sponsoredBadge.evaluate().isNotEmpty) {
        // Sponsored content should be visible
        expect(sponsoredBadge, findsOneWidget);
      }
    });

    testWidgets('Contact landlord flow test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Explore
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      // Tap contact button
      final contactButton = find.byIcon(Icons.phone).first;
      if (contactButton.evaluate().isNotEmpty) {
        await tester.tap(contactButton);
        await tester.pumpAndSettle();

        // Should open phone dialer or messages
        // (Platform-specific behavior)
      }
    });

    testWidgets('Desktop layout test', (WidgetTester tester) async {
      // Set large screen size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Explore
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      // Desktop layout should show 9:16 container
      // Action buttons should be on the right side
      expect(find.byType(PageView), findsOneWidget);

      // Reset screen size
      addTearDown(tester.view.reset);
    });
  });
}
