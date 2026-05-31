// Quick test script to check if properties are in Supabase
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  print('✅ Connected to Supabase');
  print('URL: ${dotenv.env['SUPABASE_URL']}');
  
  // Fetch properties
  try {
    final response = await Supabase.instance.client
        .from('properties')
        .select()
        .eq('status', 'active')
        .limit(5);
    
    print('\n📦 Found ${response.length} properties:');
    for (var prop in response) {
      print('  - ${prop['title']} (${prop['property_type']}) - KSh ${prop['price']}');
    }
    
    if (response.isEmpty) {
      print('\n❌ NO PROPERTIES FOUND IN DATABASE!');
      print('   Please run the seed.sql file in your Supabase SQL editor');
    }
  } catch (e) {
    print('\n❌ Error fetching properties: $e');
  }
}
