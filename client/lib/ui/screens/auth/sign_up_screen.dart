/// Sign-up screen for Melodia.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/errors.dart';
import '../../../session/session_controller.dart';
import '../../../theme/tokens.dart';

/// Screen that lets a new user create a Melodia account.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, this.onNavigateToSignIn});

  /// Called when the user taps the "Sign in" link.
  final VoidCallback? onNavigateToSignIn;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _inviteCodeCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;

  String? _genericError;
  Map<String, String> _fieldErrors = {};
  int? _retryAfterSeconds;

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _inviteCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _clearErrors();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      await ref.read(sessionProvider.notifier).signUp(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
            displayName: _displayNameCtrl.text.trim().isEmpty
                ? null
                : _displayNameCtrl.text.trim(),
            inviteCode: _inviteCodeCtrl.text.trim().isEmpty
                ? null
                : _inviteCodeCtrl.text.trim(),
          );
      // Navigation handled upstream by the router reacting to session state.
    } on ConflictError {
      setState(() => _genericError = 'An account with that email already exists.');
    } on ValidationError catch (e) {
      setState(() => _fieldErrors = e.fields);
    } on RateLimitError catch (e) {
      setState(() => _retryAfterSeconds = e.retryAfterSeconds);
    } on ApiError catch (e) {
      setState(() => _genericError = e.message);
    } catch (e) {
      setState(() => _genericError = 'Connection failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _clearErrors() {
    setState(() {
      _genericError = null;
      _fieldErrors = {};
      _retryAfterSeconds = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: MelodiaTokens.spacingPage,
              vertical: MelodiaTokens.spacingXxxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Title ───────────────────────────────────────────
                    Text(
                      'Create Account',
                      style: MelodiaTokens.largeTitle
                          .copyWith(color: tokens.text),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: MelodiaTokens.spacingXxl),

                    // ── Display name (optional) ──────────────────────────
                    _MelodiaTextField(
                      controller: _displayNameCtrl,
                      label: 'Display Name (optional)',
                      keyboardType: TextInputType.name,
                      autofillHints: const [AutofillHints.name],
                      errorText: _fieldErrors['body.display_name'],
                      tokens: tokens,
                    ),
                    const SizedBox(height: MelodiaTokens.spacingMd),

                    // ── Email ────────────────────────────────────────────
                    _MelodiaTextField(
                      controller: _emailCtrl,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      errorText: _fieldErrors['body.email'],
                      tokens: tokens,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Email is required' : null,
                    ),
                    const SizedBox(height: MelodiaTokens.spacingMd),

                    // ── Password ─────────────────────────────────────────
                    _MelodiaTextField(
                      controller: _passwordCtrl,
                      label: 'Password (min 10 characters)',
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      errorText: _fieldErrors['body.password'],
                      tokens: tokens,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        if (v.length < 10) {
                          return 'Password must be at least 10 characters';
                        }
                        return null;
                      },
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: tokens.textSecondary,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: MelodiaTokens.spacingMd),

                    // ── Invite code (optional) ────────────────────────────
                    _MelodiaTextField(
                      controller: _inviteCodeCtrl,
                      label: 'Invite Code (optional)',
                      errorText: _fieldErrors['body.invite_code'],
                      tokens: tokens,
                    ),
                    const SizedBox(height: MelodiaTokens.spacingLg),

                    // ── Inline error banner ──────────────────────────────
                    if (_genericError != null)
                      _ErrorBanner(message: _genericError!, tokens: tokens),
                    if (_retryAfterSeconds != null)
                      _ErrorBanner(
                        message:
                            'Too many attempts, try again in $_retryAfterSeconds seconds.',
                        tokens: tokens,
                      ),
                    if (_genericError != null || _retryAfterSeconds != null)
                      const SizedBox(height: MelodiaTokens.spacingMd),

                    // ── Create Account button ────────────────────────────
                    _PrimaryButton(
                      label: 'Create Account',
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _submit,
                      tokens: tokens,
                    ),
                    const SizedBox(height: MelodiaTokens.spacingXl),

                    // ── Navigate to sign-in ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: MelodiaTokens.callout
                              .copyWith(color: tokens.textSecondary),
                        ),
                        GestureDetector(
                          onTap: widget.onNavigateToSignIn,
                          child: Text(
                            'Sign In',
                            style: MelodiaTokens.callout
                                .copyWith(color: tokens.accent),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared internal widgets (mirror of sign_in_screen.dart — intentionally
// kept local to avoid a shared widgets package until the design stabilises)
// ---------------------------------------------------------------------------

class _MelodiaTextField extends StatelessWidget {
  const _MelodiaTextField({
    required this.controller,
    required this.label,
    required this.tokens,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.errorText,
    this.suffix,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final MelodiaTokens tokens;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final Widget? suffix;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      style: MelodiaTokens.body.copyWith(color: tokens.text),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: MelodiaTokens.callout.copyWith(color: tokens.textSecondary),
        errorText: errorText,
        suffixIcon: suffix,
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
          borderSide: BorderSide(color: tokens.separator),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
          borderSide: BorderSide(color: tokens.separator),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
          borderSide: BorderSide(color: tokens.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
          borderSide: BorderSide(color: tokens.destructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
          borderSide: BorderSide(color: tokens.destructive, width: 2),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.tokens});

  final String message;
  final MelodiaTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MelodiaTokens.spacingMd),
      decoration: BoxDecoration(
        color: tokens.destructive.withAlpha(30),
        borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
        border: Border.all(color: tokens.destructive.withAlpha(80)),
      ),
      child: Text(
        message,
        style: MelodiaTokens.footnote.copyWith(color: tokens.destructive),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.tokens,
    this.onPressed,
  });

  final String label;
  final bool isLoading;
  final MelodiaTokens tokens;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: MelodiaTokens.spacingXl,
                height: MelodiaTokens.spacingXl,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.text,
                ),
              )
            : Text(
                label,
                style: MelodiaTokens.headline.copyWith(color: tokens.text),
              ),
      ),
    );
  }
}
