import 'package:flutter/material.dart';
import '../../../core/models/property.dart';
import '../../../core/widgets/property_card.dart';

class HorizontalPropertyList extends StatelessWidget {
  final List<Property> properties;

  const HorizontalPropertyList({super.key, required this.properties});

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 240, // Reduced to match new card design
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: properties.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PropertyCard(property: properties[index], width: 240),
          );
        },
      ),
    );
  }
}
