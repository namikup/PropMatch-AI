import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/app_state_provider.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sign In Form Controllers & State
  final _loginEmailController = TextEditingController(text: 'agent@propmatch.ai');
  final _loginPasswordController = TextEditingController(text: 'demo1234');
  bool _isLoginLoading = false;
  bool _obscureLoginPassword = true;
  String? _loginErrorMessage;

  // Register Form Controllers & State
  final _registerFormKey = GlobalKey<FormState>();
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regAgencyController = TextEditingController();
  final _regRenController = TextEditingController();
  String _regRegion = 'Penang & Northern Region';
  bool _isRegisterLoading = false;
  bool _obscureRegPassword = true;
  bool _obscureRegConfirmPassword = true;
  String? _registerErrorMessage;

  static const List<String> _malaysianRegions = [
    'Penang & Northern Region',
    'Klang Valley / Selangor',
    'Johor & Southern Region',
    'East Coast (Pahang/Terengganu/Kelantan)',
    'Sabah & Sarawak',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    _regPhoneController.dispose();
    _regAgencyController.dispose();
    _regRenController.dispose();
    super.dispose();
  }

  String _formatAuthError(dynamic error) {
    final str = error.toString();
    if (str.contains('user-not-found')) {
      return 'No registered account found with this email. Please check or register a new account.';
    } else if (str.contains('wrong-password') || str.contains('invalid-credential')) {
      return 'Invalid email or password. Please verify your credentials and try again.';
    } else if (str.contains('email-already-in-use')) {
      return 'An account with this email address already exists. Please sign in instead.';
    } else if (str.contains('weak-password')) {
      return 'Password is too weak. Please use at least 6 characters.';
    } else if (str.contains('invalid-email')) {
      return 'The email address format is invalid.';
    } else if (str.contains('network-request-failed')) {
      return 'Network connection issue. Please check your internet connectivity.';
    }
    return str.replaceAll(RegExp(r'\[.*?\]'), '').trim();
  }

  Future<void> _handleLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _loginErrorMessage = 'Please enter both your email and password.');
      return;
    }

    setState(() {
      _isLoginLoading = true;
      _loginErrorMessage = null;
    });

    try {
      final appState = context.read<AppStateProvider>();
      final user = await appState.authRepository.signInWithEmail(email, password);

      if (user != null) {
        if (mounted) {
          widget.onLoginSuccess();
        }
      } else {
        if (mounted) {
          setState(() {
            _loginErrorMessage = 'Authentication failed. Please verify your credentials.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loginErrorMessage = _formatAuthError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoginLoading = false);
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isRegisterLoading = true;
      _registerErrorMessage = null;
    });

    try {
      final appState = context.read<AppStateProvider>();
      final user = await appState.authRepository.registerWithEmail(
        email: _regEmailController.text.trim(),
        password: _regPasswordController.text,
        fullName: _regNameController.text.trim(),
        renNumber: _regRenController.text.trim(),
        agencyName: _regAgencyController.text.trim(),
        phone: _regPhoneController.text.trim(),
        region: _regRegion,
      );

      if (user != null) {
        if (mounted) {
          widget.onLoginSuccess();
        }
      } else {
        if (mounted) {
          setState(() {
            _registerErrorMessage = 'Registration could not be completed. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _registerErrorMessage = _formatAuthError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isRegisterLoading = false);
      }
    }
  }

  void _fillDemoCredentials() {
    setState(() {
      _loginEmailController.text = 'agent@propmatch.ai';
      _loginPasswordController.text = 'demo1234';
      _loginErrorMessage = null;
    });
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final resetEmailController = TextEditingController(text: _loginEmailController.text.trim());
    bool isSending = false;
    String? dialogError;
    String? dialogSuccess;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
              title: const Row(
                children: [
                  Icon(Icons.lock_reset, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter your registered agent email address. We will send a secure password reset link to your inbox.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    if (dialogError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingSm),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                        ),
                        child: Text(dialogError!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                    ],
                    if (dialogSuccess != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingSm),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                        ),
                        child: Text(dialogSuccess!, style: const TextStyle(color: AppTheme.success, fontSize: 12)),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                    ],
                    TextField(
                      controller: resetEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Registered Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          final email = resetEmailController.text.trim();
                          if (email.isEmpty) {
                            setDialogState(() => dialogError = 'Please enter your email address.');
                            return;
                          }
                          setDialogState(() {
                            isSending = true;
                            dialogError = null;
                            dialogSuccess = null;
                          });
                          try {
                            final appState = context.read<AppStateProvider>();
                            await appState.authRepository.sendPasswordResetEmail(email);
                            setDialogState(() {
                              isSending = false;
                              dialogSuccess = 'Password reset email sent! Check your inbox.';
                            });
                          } catch (e) {
                            setDialogState(() {
                              isSending = false;
                              dialogError = _formatAuthError(e);
                            });
                          }
                        },
                  child: isSending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send Reset Link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLg,
            vertical: AppTheme.spacingXl,
          ),
          child: isWide
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBrandPanel(context),
                    const SizedBox(width: AppTheme.spacingXxl),
                    _buildAuthCard(context),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBrandHeader(context),
                    const SizedBox(height: AppTheme.spacingXl),
                    _buildAuthCard(context),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBrandPanel(BuildContext context) {
    return SizedBox(
      width: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.accent, AppTheme.accentLight],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.real_estate_agent,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    Text(
                      'Malaysia Property Agent SaaS',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXl),
          Text(
            'High-Intent Property Lead Discovery & Smart Buyer Matching',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'Target qualified Malaysian home buyers, discover micro-audiences, '
            'and calculate weighted compatibility for new launches across Penang, Selangor & Johor.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
          ),
          const SizedBox(height: AppTheme.spacingXl),
          _buildFeatureItem(Icons.psychology, 'AI Micro-Audience Discovery & Personas'),
          _buildFeatureItem(Icons.compare_arrows, '5-Factor Weighted Compatibility Matching'),
          _buildFeatureItem(Icons.campaign, 'Trilingual Marketing Generation (EN, BM, CN)'),
          _buildFeatureItem(Icons.verified_user, 'PDPA & Board of Valuers (LPPEH) Compliant'),
          const SizedBox(height: AppTheme.spacingXl),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_done, color: AppTheme.success, size: 22),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    'Connected to Google Cloud Firestore (property-71665)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.accent, AppTheme.accentLight],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: const Icon(
            Icons.real_estate_agent,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppTheme.spacingXs),
        Text(
          AppConstants.appTagline,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primary),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard(BuildContext context) {
    return SizedBox(
      width: 460,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.login, size: 18),
                      text: 'Sign In',
                    ),
                    Tab(
                      icon: Icon(Icons.person_add, size: 18),
                      text: 'Register Agent',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              // Tab Views
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return _tabController.index == 0
                      ? _buildSignInTab(context)
                      : _buildRegisterTab(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Agent Sign In',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Access your Malaysian property listings, buyers and AI matching.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: AppTheme.spacingLg),

        // Demo Sandbox Box
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: AppTheme.warning.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.science_outlined, color: AppTheme.warning, size: 18),
                  const SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      'Demo Sandbox Available',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.warning,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: _fillDemoCredentials,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Use Demo Account', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Explore sample Penang projects and 100 test buyers without registration.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingLg),

        // Error message banner
        if (_loginErrorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    _loginErrorMessage!,
                    style: const TextStyle(color: AppTheme.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
        ],

        // Email
        TextField(
          controller: _loginEmailController,
          decoration: const InputDecoration(
            labelText: 'Agent Email',
            hintText: 'e.g. agent@realty.com.my',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppTheme.spacingMd),

        // Password
        TextField(
          controller: _loginPasswordController,
          obscureText: _obscureLoginPassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureLoginPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() => _obscureLoginPassword = !_obscureLoginPassword);
              },
            ),
          ),
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: 6),

        // Forgot Password link
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _showForgotPasswordDialog(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Forgot Password?', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),

        // Sign In button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoginLoading ? null : _handleLogin,
            child: _isLoginLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Sign In to SaaS Platform'),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterTab(BuildContext context) {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Register Agent Account',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create your cloud workspace with Firebase Authentication & Firestore.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Error message banner
          if (_registerErrorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                  const SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      _registerErrorMessage!,
                      style: const TextStyle(color: AppTheme.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
          ],

          // Full Name
          TextFormField(
            controller: _regNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              hintText: 'e.g. Alex Tan Wei Meng',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // Email
          TextFormField(
            controller: _regEmailController,
            decoration: const InputDecoration(
              labelText: 'Email Address *',
              hintText: 'e.g. alex.tan@iqiglobal.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!regex.hasMatch(v.trim())) return 'Please enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // Password & Confirm Password Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _regPasswordController,
                  obscureText: _obscureRegPassword,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureRegPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureRegPassword = !_obscureRegPassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: TextFormField(
                  controller: _regConfirmPasswordController,
                  obscureText: _obscureRegConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureRegConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() =>
                          _obscureRegConfirmPassword = !_obscureRegConfirmPassword),
                    ),
                  ),
                  validator: (v) {
                    if (v != _regPasswordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // Phone & REN Number Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _regPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    hintText: '+6012-3456789',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Phone is required' : null,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: TextFormField(
                  controller: _regRenController,
                  decoration: const InputDecoration(
                    labelText: 'REN Number *',
                    hintText: 'e.g. REN 45892',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'REN is required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // Agency Name
          TextFormField(
            controller: _regAgencyController,
            decoration: const InputDecoration(
              labelText: 'Agency Name *',
              hintText: 'e.g. IQI Global / PropNex Malaysia',
              prefixIcon: Icon(Icons.business_outlined),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Agency name is required' : null,
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // Operating Region Dropdown
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _regRegion,
            decoration: const InputDecoration(
              labelText: 'Primary Operating Region',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: _malaysianRegions
                .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _regRegion = val);
            },
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Register Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isRegisterLoading ? null : _handleRegister,
              child: _isRegisterLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Agent Account'),
            ),
          ),
        ],
      ),
    );
  }
}
