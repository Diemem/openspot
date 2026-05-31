import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String propertyId;
  final String packageType;
  
  const PaymentScreen({
    super.key,
    required this.propertyId,
    required this.packageType,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _selectedMethod = 'mpesa';
  final _phoneController = TextEditingController();
  bool _isProcessing = false;

  final Map<String, Map<String, dynamic>> _packages = {
    'featured_7_days': {
      'name': 'Featured Listing - 7 Days',
      'price': 500,
      'description': 'Your property appears at the top of search results for 7 days',
      'features': ['Top placement in search', 'Featured badge', 'Priority in map view'],
    },
    'featured_30_days': {
      'name': 'Featured Listing - 30 Days',
      'price': 1500,
      'description': 'Your property appears at the top of search results for 30 days',
      'features': ['Top placement in search', 'Featured badge', 'Priority in map view', '25% discount'],
    },
    'promotional_video': {
      'name': 'Promotional Video Boost',
      'price': 300,
      'description': 'Boost your promotional video for 7 days in the Explore feed',
      'features': ['Higher visibility in Explore', 'Video promotion badge', 'Increased engagement'],
    },
  };

  @override
  Widget build(BuildContext context) {
    final package = _packages[widget.packageType];
    if (package == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: const Center(child: Text('Invalid package type')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Package Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    package['description'],
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...package['features'].map<Widget>((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, 
                            color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(feature, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  )).toList(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'KES ${package['price']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Payment Methods
            const Text(
              'Select Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // M-Pesa Option
            _PaymentMethodTile(
              title: 'M-Pesa',
              subtitle: 'Pay with your M-Pesa mobile money',
              icon: Icons.phone_android,
              value: 'mpesa',
              selected: _selectedMethod == 'mpesa',
              onTap: () => setState(() => _selectedMethod = 'mpesa'),
            ),

            // Card Option (placeholder)
            _PaymentMethodTile(
              title: 'Credit/Debit Card',
              subtitle: 'Pay with Visa, Mastercard (Coming Soon)',
              icon: Icons.credit_card,
              value: 'card',
              selected: _selectedMethod == 'card',
              onTap: () => setState(() => _selectedMethod = 'card'),
              enabled: false,
            ),

            const SizedBox(height: 24),

            // M-Pesa Phone Number Input
            if (_selectedMethod == 'mpesa') ...[
              const Text(
                'M-Pesa Phone Number',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  hintText: '254712345678',
                  prefixText: '+',
                  helperText: 'Enter your M-Pesa registered phone number',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 32),
            ],

            // Pay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primary,
                ),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Processing...'),
                        ],
                      )
                    : Text(
                        'Pay KES ${package['price']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Security Notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Colors.green, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your payment is secured with 256-bit SSL encryption',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_selectedMethod == 'mpesa' && _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your M-Pesa phone number')),
      );
      return;
    }

    if (_selectedMethod == 'card') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card payments coming soon!')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      // In production, integrate with:
      // - M-Pesa Daraja API for M-Pesa payments
      // - Stripe/Flutterwave for card payments
      
      // For now, simulate successful payment
      final package = _packages[widget.packageType]!;
      
      // Record the payment in database
      await Supabase.instance.client.from('payments').insert({
        'property_id': widget.propertyId,
        'package_type': widget.packageType,
        'amount': package['price'],
        'payment_method': _selectedMethod,
        'phone_number': _selectedMethod == 'mpesa' ? _phoneController.text : null,
        'status': 'completed',
        'transaction_id': 'TXN${DateTime.now().millisecondsSinceEpoch}',
      });

      // Update property with featured status if applicable
      if (widget.packageType.startsWith('featured_')) {
        final days = widget.packageType == 'featured_7_days' ? 7 : 30;
        await Supabase.instance.client
            .from('properties')
            .update({
              'featured': true,
              'featured_until': DateTime.now().add(Duration(days: days)).toIso8601String(),
            })
            .eq('id', widget.propertyId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Your property has been promoted.'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  const _PaymentMethodTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: enabled ? Colors.white : Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled 
                  ? (selected ? AppTheme.primary : Colors.grey.shade600)
                  : Colors.grey.shade400,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: enabled ? Colors.black : Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? AppTheme.textSecondary : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: selected ? value : '',
              onChanged: enabled ? (_) => onTap() : null,
              activeColor: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}