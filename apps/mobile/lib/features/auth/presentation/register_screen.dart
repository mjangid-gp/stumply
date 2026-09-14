import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_error_message.dart';
import '../../../core/utils/password_validator.dart';
import '../../../shared/widgets/crick_ui.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _otpSent = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).sendRegistrationOtp(
        email: _emailController.text.trim(),
        displayName: _nameController.text.trim(),
      );
      if (mounted) {
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code sent to your email')),
        );
      }
    } catch (e) {
      setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerWithOtp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_otpSent) {
      setState(() => _error = 'Please verify your email with the OTP first.');
      return;
    }
    if (_otpController.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).registerWithEmailOtp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
        otp: _otpController.text.trim(),
      );
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerDirect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully')),
        );
        context.go('/');
      }
    } catch (e) {
      setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join the cricket community',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your account now, or verify with an email OTP when available.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: PasswordValidator.formError,
              ),
              const SizedBox(height: 12),
              CrickCard(
                padding: const EdgeInsets.all(14),
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password must include:',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...PasswordValidator.requirements.map(
                      (rule) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(rule, style: Theme.of(context).textTheme.bodySmall)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 20),
                TextFormField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: 'Email verification code',
                    prefixIcon: Icon(Icons.pin_outlined),
                    hintText: '6-digit OTP',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: (v) {
                    if (!_otpSent) return null;
                    if (v == null || v.length != 6) return 'Enter the 6-digit OTP';
                    return null;
                  },
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _loading ? null : _registerDirect,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create Account'),
              ),
              const SizedBox(height: 12),
              if (!_otpSent)
                OutlinedButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: const Text('Send Email OTP (optional)'),
                )
              else ...[
                OutlinedButton(
                  onPressed: _loading ? null : _registerWithOtp,
                  child: const Text('Verify OTP & Create Account'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: const Text('Resend OTP'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
