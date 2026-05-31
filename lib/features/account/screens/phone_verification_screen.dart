import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class PhoneVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  
  const PhoneVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  ConsumerState<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState
    extends ConsumerState<PhoneVerificationScreen> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  String? _verificationCode; // For development only
  int _resendCountdown = 0;
  int _resendAttempts = 0; // ✅ FIX 10: Track resend attempts
  Timer? _timer; // ✅ FIX 1: Proper timer management

  @override
  void initState() {
    super.initState();
    _sendVerificationCode();
  }

  Future<void> _sendVerificationCode() async {
    // ✅ FIX 10: Spam protection
    if (_resendAttempts >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Too many attempts. Please try again later.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isResending = true);
    
    try {
      final result = await Supabase.instance.client
          .rpc('send_phone_verification', params: {
        'user_phone': widget.phoneNumber,
      });
      
      // ✅ FIX 4: Guard dev code with kDebugMode
      if (kDebugMode && result != null) {
        setState(() => _verificationCode = result.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification code sent! (Dev: $result)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Start countdown and increment attempts
      _startResendCountdown();
      _resendAttempts++;
    } catch (e) {
      if (mounted) {
        // ✅ FIX 8: Better error handling
        final message = e.toString().toLowerCase();
        String userMessage = 'Something went wrong';
        
        if (message.contains('network')) {
          userMessage = 'Check your internet connection';
        } else if (message.contains('timeout')) {
          userMessage = 'Request timed out. Please try again.';
        } else if (message.contains('rate limit')) {
          userMessage = 'Too many requests. Please wait a moment.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  // ✅ FIX 1: Safe timer implementation
  void _startResendCountdown() {
    _timer?.cancel(); // Cancel any existing timer
    
    setState(() => _resendCountdown = 60);
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_resendCountdown == 0) {
        timer.cancel();
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 6-digit code')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // ✅ FIX 2: Include phone number for security
      final result = await Supabase.instance.client
          .rpc('verify_phone_code', params: {
        'input_code': _codeController.text,
        'user_phone': widget.phoneNumber, // Security: tie code to phone
      });

      if (result == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Phone verified successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // ✅ FIX 9: Better navigation logic
          context.go('/account');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid or expired code. Please try again.'),
            ),
          );
          // Clear the input for retry
          _codeController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        // ✅ FIX 8: Enhanced error handling
        final message = e.toString().toLowerCase();
        String userMessage = 'Something went wrong';
        
        if (message.contains('network')) {
          userMessage = 'Check your internet connection';
        } else if (message.contains('timeout')) {
          userMessage = 'Request timed out. Please try again.';
        } else if (message.contains('expired')) {
          userMessage = 'Code expired. Please request a new one.';
        } else if (message.contains('invalid')) {
          userMessage = 'Invalid code. Please check and try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Phone Number'),
      ),
      // ✅ FIX 5: Keyboard-safe scrolling
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.phone_android,
                  size: 80,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 24),
                
                const Text(
                  'Verification Code Sent',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                Text(
                  'We sent a 6-digit code to ${widget.phoneNumber}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // ✅ FIX 4: Development helper with proper guard
                if (kDebugMode && _verificationCode != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.developer_mode, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'DEV: Your code is $_verificationCode',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Code Input
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Verification Code',
                    hintText: '123456',
                    prefixIcon: Icon(Icons.security),
                  ),
                  keyboardType: TextInputType.number,
                  // ✅ FIX 7: Strong input control
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLength: 6,
                  enabled: !_isVerifying, // Disable during verification
                  onChanged: (value) {
                    // ✅ FIX 3: Prevent double requests
                    if (value.length == 6 && !_isVerifying) {
                      _verifyCode();
                    }
                  },
                ),
                const SizedBox(height: 24),
                
                // Verify Button
                ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify Code'),
                ),
                
                const SizedBox(height: 16),
                
                // Resend Button with spam protection
                TextButton(
                  onPressed: (_resendCountdown > 0 || _isResending || _resendAttempts >= 3) 
                      ? null 
                      : _sendVerificationCode,
                  child: _isResending
                      ? const Text('Sending...')
                      : _resendAttempts >= 3
                          ? const Text('Too many attempts')
                          : _resendCountdown > 0
                              ? Text('Resend code in ${_resendCountdown}s')
                              : const Text('Resend Code'),
                ),
                
                const SizedBox(height: 200), // Extra space for keyboard
                
                // Skip Button (for development only)
                if (kDebugMode)
                  TextButton(
                    onPressed: _isVerifying ? null : () => context.go('/account'),
                    child: const Text('Skip for now'),
                  ),
              ],
            ),
          ),

          // ✅ FIX 6: Loading overlay for better UX
          if (_isVerifying)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Verifying code...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // ✅ FIX 1: Proper cleanup
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }
}