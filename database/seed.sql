-- ============================================================
-- OpenSpot Seed Data
-- Run AFTER schema.sql
-- ============================================================

-- ============================================================
-- PROPERTIES (from mock data across all screens)
-- ============================================================
INSERT INTO properties (title, description, property_type, category, listing_type, location, neighborhood, city, latitude, longitude, price, deposit, bedrooms, bathrooms, area, parking_spaces, amenities, utilities_included, images, thumbnail_url, landlord_name, landlord_phone, landlord_verified, available, lease_duration, status, verified, featured) VALUES

('Modern 2BR Apartment in Westlands',
 'Spacious 2-bedroom apartment with stunning city views. Fully furnished with modern finishes, open-plan kitchen, and a private balcony. Located in the heart of Westlands with easy access to malls and restaurants.',
 'apartment','residential','rent','Westlands, Nairobi','Westlands','Nairobi',-1.2676,36.8108,
 45000,90000,2,2,1200,1,
 '["WiFi","Gym","Swimming Pool","24hr Security","Backup Generator","CCTV","Elevator","Rooftop Terrace"]','["Water","Garbage Collection"]',
 '["https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800","https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800","https://images.unsplash.com/photo-1484154218962-a197022b5858?w=800","https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800"]',
 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=400',
 'James Mwangi','+254 712 345 678',true,true,'yearly','active',true,true),

('Cozy Studio in Kilimani',
 'Well-maintained studio apartment perfect for a young professional. Comes with a kitchenette, en-suite bathroom, and ample natural light. Walking distance to Yaya Centre.',
 'studio','residential','rent','Kilimani, Nairobi','Kilimani','Nairobi',-1.2921,36.7873,
 22000,44000,0,1,450,0,
 '["WiFi","Security","CCTV","Laundry Room"]','["Water"]',
 '["https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800","https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800","https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800"]',
 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=400',
 'Grace Njeri','+254 722 456 789',true,true,'monthly','active',true,false),

('Luxury 3BR Penthouse in Lavington',
 'Stunning penthouse with panoramic views of Nairobi. Features a private rooftop terrace, chef''s kitchen, master en-suite with jacuzzi, and two covered parking spaces.',
 'apartment','residential','rent','Lavington, Nairobi','Lavington','Nairobi',-1.2833,36.7667,
 120000,240000,3,3,2800,2,
 '["WiFi","Gym","Swimming Pool","24hr Security","Backup Generator","CCTV","Elevator","Rooftop Terrace","Jacuzzi","Concierge"]','["Water","Garbage Collection","Internet"]',
 '["https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800","https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800","https://images.unsplash.com/photo-1600566753086-00f18fb6b3ea?w=800","https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800"]',
 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=400',
 'David Kamau','+254 733 567 890',true,true,'yearly','active',true,true),

('Bedsitter Near UoN',
 'Affordable bedsitter ideal for students. Close to University of Nairobi main campus. Shared kitchen and bathroom facilities. Safe and secure compound.',
 'bedsitter','residential','rent','Ngara, Nairobi','Ngara','Nairobi',-1.2833,36.8167,
 8500,17000,0,1,200,0,
 '["Security","Water Tank"]','["Water"]',
 '["https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=800","https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800"]',
 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=400',
 'Peter Otieno','+254 700 678 901',false,true,'monthly','active',false,false),

('4BR Family Home in Karen',
 'Beautiful family home in the leafy suburb of Karen. Spacious garden, servant quarters, double garage, and a large living area. Quiet neighborhood with excellent security.',
 'house','residential','rent','Karen, Nairobi','Karen','Nairobi',-1.3333,36.7167,
 180000,360000,4,3,4500,2,
 '["Garden","Swimming Pool","24hr Security","CCTV","Backup Generator","Servant Quarters","Borehole"]','["Water","Garbage Collection"]',
 '["https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800","https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800","https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800","https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800"]',
 'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=400',
 'Sarah Wanjiku','+254 711 789 012',true,true,'yearly','active',true,true),

('1BR Apartment in Kileleshwa',
 'Modern 1-bedroom apartment in a quiet estate. Recently renovated with new kitchen cabinets, tiles, and bathroom fittings. Ample parking and 24hr security.',
 'apartment','residential','rent','Kileleshwa, Nairobi','Kileleshwa','Nairobi',-1.2833,36.7833,
 32000,64000,1,1,700,1,
 '["WiFi","Security","CCTV","Backup Generator","Parking"]','["Water"]',
 '["https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800","https://images.unsplash.com/photo-1484154218962-a197022b5858?w=800","https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800"]',
 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400',
 'Ann Muthoni','+254 722 890 123',true,true,'yearly','active',true,false),

('Prime Office Space in CBD',
 'Modern open-plan office space on the 12th floor of a Grade A building in Nairobi CBD. Includes reception area, boardroom, and kitchenette. Fiber internet ready.',
 'office','commercial','rent','Nairobi CBD','CBD','Nairobi',-1.2833,36.8167,
 85000,170000,NULL,2,2500,3,
 '["WiFi","Elevator","24hr Security","CCTV","Backup Generator","Parking","Reception","Boardroom"]','["Water","Electricity","Internet"]',
 '["https://images.unsplash.com/photo-1497366216548-37526070297c?w=800","https://images.unsplash.com/photo-1497366754035-f200968a6e72?w=800","https://images.unsplash.com/photo-1524758631624-e2822e304c36?w=800"]',
 'https://images.unsplash.com/photo-1497366216548-37526070297c?w=400',
 'Corporate Properties Ltd','+254 733 901 234',true,true,'yearly','active',true,false),

('Retail Shop in Westgate Mall Area',
 'Prime retail space near Westgate Mall. High foot traffic area, ideal for fashion, electronics, or food business. Includes storage room and staff toilet.',
 'shop','commercial','rent','Westlands, Nairobi','Westlands','Nairobi',-1.2700,36.8120,
 55000,110000,NULL,1,800,0,
 '["24hr Security","CCTV","Backup Generator","Loading Bay"]','["Water","Garbage Collection"]',
 '["https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800","https://images.unsplash.com/photo-1555529669-e69e7aa0ba9a?w=800"]',
 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400',
 'Westlands Properties','+254 700 012 345',true,true,'yearly','active',false,false),

('Warehouse in Industrial Area',
 'Large warehouse facility in Nairobi Industrial Area. High ceiling clearance (8m), loading dock, 3-phase power, and office space. Ideal for manufacturing or logistics.',
 'warehouse','industrial','rent','Industrial Area, Nairobi','Industrial Area','Nairobi',-1.3000,36.8500,
 150000,300000,NULL,2,12000,10,
 '["Loading Dock","3-Phase Power","24hr Security","CCTV","Office Space","Borehole"]','["Water"]',
 '["https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=800","https://images.unsplash.com/photo-1553413077-190dd305871c?w=800"]',
 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=400',
 'Industrial Properties KE','+254 711 123 456',true,true,'yearly','active',true,false),

('1/4 Acre Plot in Ruiru',
 'Ready title deed. 1/4 acre plot in a fast-developing area of Ruiru. All utilities available. Ideal for residential development. 5 minutes from Thika Road.',
 'land','land','sale','Ruiru, Kiambu','Ruiru','Nairobi',-1.1500,36.9667,
 3500000,0,NULL,NULL,10890,0,
 '["Title Deed Ready","Road Access","Electricity Available","Water Available"]','[]',
 '["https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800","https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800"]',
 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=400',
 'Land Brokers KE','+254 722 234 567',true,true,'flexible','active',true,false),

('2BR Apartment in South B',
 'Affordable 2-bedroom apartment in South B estate. Tiled throughout, fitted kitchen, and a small balcony. Close to South B shopping centre and good public transport.',
 'apartment','residential','rent','South B, Nairobi','South B','Nairobi',-1.3167,36.8333,
 28000,56000,2,1,900,1,
 '["Security","Parking","Water Tank"]','["Water"]',
 '["https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800","https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800"]',
 'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=400',
 'Tom Kipchoge','+254 733 345 678',false,true,'monthly','active',false,false),

('Studio Apartment in Parklands',
 'Compact studio in Parklands. Ideal for a single professional. Comes with a fitted wardrobe, kitchenette, and en-suite. Walking distance to Aga Khan Hospital.',
 'studio','residential','rent','Parklands, Nairobi','Parklands','Nairobi',-1.2667,36.8167,
 18000,36000,0,1,380,0,
 '["WiFi","Security","CCTV","Laundry"]','["Water"]',
 '["https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800","https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800"]',
 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=400',
 'Amina Hassan','+254 700 456 789',false,true,'monthly','active',false,false),

('3BR Townhouse in Syokimau',
 'Modern 3-bedroom townhouse in a gated community. Master en-suite, fitted kitchen, DSQ, and 2 parking spaces. Easy access to SGR station.',
 'house','residential','rent','Syokimau, Machakos','Syokimau','Nairobi',-1.3667,36.9000,
 55000,110000,3,2,1800,2,
 '["24hr Security","CCTV","Backup Generator","Borehole","Garden","Parking"]','["Water"]',
 '["https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800","https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800"]',
 'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=400',
 'Mike Ochieng','+254 711 567 890',true,true,'yearly','active',true,false),

('Bedsitter in Roysambu',
 'Clean and affordable bedsitter near TRM Mall. Tiled, with fitted wardrobe and shared compound. Good public transport links.',
 'bedsitter','residential','rent','Roysambu, Nairobi','Roysambu','Nairobi',-1.2167,36.8833,
 7000,14000,0,1,180,0,
 '["Security","Water Tank"]','["Water"]',
 '["https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=800"]',
 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=400',
 'Grace Achieng','+254 722 678 901',false,true,'monthly','active',false,false);

-- ============================================================
-- MARKETPLACE ITEMS (from marketplace_screen.dart mock data)
-- Note: seller_id requires a real profile — using a placeholder
-- approach: insert with a system/demo seller profile first
-- ============================================================

-- Create a demo seller profile (will be replaced by real users)
-- This requires a matching auth.users entry — skip if running fresh
-- Instead, seed marketplace items without seller_id for now
-- and update seller_id after first real user signs up

-- ============================================================
-- VERIFY
-- ============================================================
SELECT
  (SELECT COUNT(*) FROM properties)        AS properties,
  (SELECT COUNT(*) FROM profiles)          AS profiles,
  (SELECT COUNT(*) FROM marketplace_items) AS marketplace_items,
  (SELECT COUNT(*) FROM roommate_profiles) AS roommate_profiles;
