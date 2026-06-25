import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';
import 'package:farmly/core/providers.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();
  bool _showOtp = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _devOtp; // Shows OTP in dev mode
  int _resendCountdown = 0;
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  late AnimationController _bgAnimController;

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    _bgAnimController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 30);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCountdown--);
      return _resendCountdown > 0;
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final locale = ref.read(localeProvider);
    final result = await authService.sendOtp(phone);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      setState(() {
        _showOtp = true;
        _devOtp = result['dev_otp']?.toString();
      });
      _startResendTimer();
      // Focus the first OTP box
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
    } else {
      final msgKey = locale.languageCode == 'mr'
          ? 'message_mr'
          : locale.languageCode == 'hi'
              ? 'message_hi'
              : 'message';
      setState(() {
        _errorMessage = result[msgKey] ?? result['message'] ?? 'Error sending OTP';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 4) {
      setState(() => _errorMessage = 'Please enter the 4-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final locale = ref.read(localeProvider);
    final result = await authService.verifyOtp(phone, otp);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ref.invalidate(userProfileProvider);
      ref.invalidate(scanHistoryApiProvider);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } else {
      final msgKey = locale.languageCode == 'mr'
          ? 'message_mr'
          : locale.languageCode == 'hi'
              ? 'message_hi'
              : 'message';
      setState(() {
        _errorMessage = result[msgKey] ?? result['message'] ?? 'Invalid OTP';
      });
      // Shake animation: clear OTP fields
      for (var c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes[0].requestFocus();
    }
  }

  Future<void> _googleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[GoogleLogin] Starting authenticate()...');
      final GoogleSignInAccount? account = await GoogleSignIn.instance.authenticate();
      
      if (account == null) {
        // User canceled
        debugPrint('[GoogleLogin] User canceled sign-in');
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('[GoogleLogin] Signed in as: ${account.email}');
      final email = account.email;
      final name = account.displayName ?? 'Farmer';

      final authService = ref.read(authServiceProvider);
      final result = await authService.googleLogin(email, name: name);

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        debugPrint('[GoogleLogin] Backend login successful');
        ref.invalidate(userProfileProvider);
        ref.invalidate(scanHistoryApiProvider);
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        debugPrint('[GoogleLogin] Backend returned error: ${result['message']}');
        setState(() {
          _errorMessage = result['message'] ?? 'Google Login failed';
        });
      }
    } catch (e, stack) {
      debugPrint('[GoogleLogin] Error: $e');
      debugPrint('[GoogleLogin] Stack: $stack');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Google Sign In Error: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _bgAnimController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(
                        -1 + _bgAnimController.value, -1 + _bgAnimController.value),
                    end: Alignment(
                        1 - _bgAnimController.value * 0.5, 1 - _bgAnimController.value * 0.5),
                    colors: const [
                      Color(0xFFE8F5E9),
                      Color(0xFFC8E6C9),
                      Color(0xFFA5D6A7),
                      Color(0xFF81C784),
                    ],
                  ),
                ),
              );
            },
          ),
          // Decorative leaves
          Positioned(
            top: -30,
            right: -20,
            child: Icon(Icons.eco, size: 180, color: AppColors.primary.withValues(alpha: 0.08)),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(
                begin: 0,
                end: 15,
                duration: 4.seconds,
                curve: Curves.easeInOut,
              ),
          Positioned(
            bottom: 100,
            left: -40,
            child: Transform.rotate(
              angle: 0.5,
              child: Icon(Icons.grass, size: 160, color: AppColors.primary.withValues(alpha: 0.06)),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).moveX(
                begin: 0,
                end: 10,
                duration: 5.seconds,
                curve: Curves.easeInOut,
              ),
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(height: size.height * 0.06),
                  // Logo
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.eco, color: Colors.white, size: 48),
                  ).animate().scale(duration: 700.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 20),
                  Text(
                    'Farmly',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('welcome_back'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                  const SizedBox(height: 36),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: AppColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: AppColors.onErrorContainer, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ).animate().shake(duration: 400.ms).fadeIn(duration: 300.ms),

                  // Dev OTP hint
                  if (_devOtp != null && _showOtp)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryFixed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bug_report, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Dev OTP: $_devOtp',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 300.ms),

                  // Login form container
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.onSurface.withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (!_showOtp) ...[
                          // Phone input
                          TextField(
                            controller: _phoneController,
                            focusNode: _phoneFocus,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.translate('phone_number'),
                              prefixText: '+91 ',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Icon(Icons.phone_android, color: AppColors.primary),
                              ),
                            ),
                          ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.2),
                          const SizedBox(height: 24),
                          // Send OTP button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendOtp,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(l10n.translate('send_otp')),
                            ),
                          ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideY(begin: 0.2),
                        ] else ...[
                          // OTP header
                          Text(
                            l10n.translate('enter_otp'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '+91 ${_phoneController.text}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 20),
                          // OTP boxes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(4, (index) {
                              return SizedBox(
                                width: 60,
                                height: 60,
                                child: TextField(
                                  controller: _otpControllers[index],
                                  focusNode: _otpFocusNodes[index],
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 1,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    counterText: '',
                                    contentPadding: EdgeInsets.zero,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: AppColors.outlineVariant),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    if (value.length == 1 && index < 3) {
                                      _otpFocusNodes[index + 1].requestFocus();
                                    }
                                    if (value.isEmpty && index > 0) {
                                      _otpFocusNodes[index - 1].requestFocus();
                                    }
                                    // Auto-verify when all 4 digits entered
                                    if (index == 3 && value.isNotEmpty) {
                                      final fullOtp = _otpControllers.map((c) => c.text).join();
                                      if (fullOtp.length == 4) {
                                        _verifyOtp();
                                      }
                                    }
                                  },
                                ),
                              );
                            }),
                          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
                          const SizedBox(height: 24),
                          // Verify button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyOtp,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(l10n.translate('verify')),
                            ),
                          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                          const SizedBox(height: 16),
                          // Resend / Change number
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () => setState(() {
                                  _showOtp = false;
                                  _errorMessage = null;
                                  _devOtp = null;
                                  for (var c in _otpControllers) {
                                    c.clear();
                                  }
                                }),
                                child: Text(l10n.translate('resend_otp').split(' ').first),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _resendCountdown > 0 ? null : _sendOtp,
                                child: Text(
                                  _resendCountdown > 0
                                      ? '${l10n.translate("resend_otp")} (${_resendCountdown}s)'
                                      : l10n.translate('resend_otp'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.1),
                  const SizedBox(height: 24),
                  
                  // OR Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.outlineVariant)),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
                  const SizedBox(height: 24),

                  // Continue with Google Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.onSurface.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: _isLoading ? null : _googleLogin,
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.g_mobiledata, size: 36, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Continue with Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 600.ms).slideY(begin: 0.2),



                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
