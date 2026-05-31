import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

enum _AuthMode { signIn, signUp, forgotPassword, checkEmail }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _AuthMode _mode = _AuthMode.signIn;
  bool _obscure = true;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _error = null; _loading = true; });

    final notifier = ref.read(authNotifierProvider.notifier);

    try {
      if (_mode == _AuthMode.signIn) {
        await notifier.signIn(_emailCtrl.text.trim(), _passwordCtrl.text.trim());
        if (!mounted) return;
        context.go('/');
      } else if (_mode == _AuthMode.signUp) {
        await notifier.signUp(_emailCtrl.text.trim(), _passwordCtrl.text.trim(), _nameCtrl.text.trim());
        if (!mounted) return;
        setState(() => _mode = _AuthMode.checkEmail);
      } else if (_mode == _AuthMode.forgotPassword) {
        await notifier.resetPassword(_emailCtrl.text.trim());
        if (!mounted) return;
        setState(() => _mode = _AuthMode.checkEmail);
      }
    } catch (e) {
      setState(() => _error = _formatError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() { _error = null; _loading = true; });
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      // Redirect handled by Supabase OAuth flow
    } catch (e) {
      setState(() => _error = _formatError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatError(String e) {
    if (e.contains('Invalid login credentials')) return 'Invalid email or password.';
    if (e.contains('Email not confirmed')) return 'Please verify your email first.';
    if (e.contains('already registered') || e.contains('already been registered')) return 'Account already exists. Sign in instead.';
    if (e.contains('Password should be')) return 'Password must be at least 6 characters.';
    if (e.contains('Unable to validate email')) return 'Please enter a valid email address.';
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Logo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 40),
              ),

              const SizedBox(height: 24),

              // ── CHECK EMAIL STATE ──────────────────────────────────────────
              if (_mode == _AuthMode.checkEmail) ...[
                const Icon(Icons.mark_email_read_outlined, size: 64, color: Color(0xFF10B981)),
                const SizedBox(height: 16),
                const Text('Check your email', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                Text(
                  'We sent a link to ${_emailCtrl.text.trim()}.\nClick it to continue.',
                  style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () => setState(() { _mode = _AuthMode.signIn; _error = null; }),
                  child: const Text('Back to Sign In', style: TextStyle(color: AppTheme.primary)),
                ),
              ]

              // ── MAIN FORM ──────────────────────────────────────────────────
              else ...[
                Text(
                  _mode == _AuthMode.signIn ? 'Welcome Back'
                    : _mode == _AuthMode.signUp ? 'Create Account'
                    : 'Reset Password',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  _mode == _AuthMode.signIn ? 'Sign in to access your account'
                    : _mode == _AuthMode.signUp ? 'Join OpenSpot to get started'
                    : 'Enter your email to receive a reset link',
                  style: const TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Google button (not on forgot password)
                if (_mode != _AuthMode.forgotPassword) ...[
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _googleSignIn,
                    icon: const Icon(Icons.g_mobiledata, size: 24),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Or continue with email', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 20),
                ],

                // Form
                Form(
                  key: _formKey,
                  child: Column(children: [
                    if (_mode == _AuthMode.signUp) ...[
                      TextFormField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter your email';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    if (_mode != _AuthMode.forgotPassword) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                      ),
                    ],
                  ]),
                ),

                // Forgot password link (sign in only)
                if (_mode == _AuthMode.signIn) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() { _mode = _AuthMode.forgotPassword; _error = null; }),
                      child: const Text('Forgot password?', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                    ),
                  ),
                ],

                // Error
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppTheme.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13))),
                    ]),
                  ),
                ],

                const SizedBox(height: 24),

                // Submit button
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_mode == _AuthMode.signIn ? 'Sign In'
                          : _mode == _AuthMode.signUp ? 'Create Account'
                          : 'Send Reset Link'),
                ),

                const SizedBox(height: 16),

                // Mode switcher
                if (_mode == _AuthMode.signIn)
                  TextButton(
                    onPressed: () => setState(() { _mode = _AuthMode.signUp; _error = null; }),
                    child: const Text("Don't have an account? Sign up", style: TextStyle(color: AppTheme.primary)),
                  )
                else if (_mode == _AuthMode.signUp)
                  TextButton(
                    onPressed: () => setState(() { _mode = _AuthMode.signIn; _error = null; }),
                    child: const Text('Already have an account? Sign in', style: TextStyle(color: AppTheme.primary)),
                  )
                else
                  TextButton(
                    onPressed: () => setState(() { _mode = _AuthMode.signIn; _error = null; }),
                    child: const Text('Back to Sign In', style: TextStyle(color: AppTheme.primary)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
