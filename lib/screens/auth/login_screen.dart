import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'agent@propmatch.ai');
  final _passwordController = TextEditingController(text: 'demo1234');
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    // Simulate login delay
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() => _isLoading = false);
      widget.onLoginSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 800;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: isWide
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBrandPanel(context),
                    const SizedBox(width: AppTheme.spacingXxl),
                    _buildLoginForm(context),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBrandHeader(context),
                    const SizedBox(height: AppTheme.spacingXl),
                    _buildLoginForm(context),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBrandPanel(BuildContext context) {
    return SizedBox(
      width: 380,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.accent, AppTheme.accentLight],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: const Icon(
                  Icons.real_estate_agent,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text(
            'AI-Powered Property Lead Discovery & Buyer Matching',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'Discover potential buyers, generate marketing strategies, '
            'and match buyers with properties — all powered by AI.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          _buildFeatureItem(Icons.people, 'AI Audience Discovery'),
          _buildFeatureItem(Icons.compare_arrows, 'Smart Buyer Matching'),
          _buildFeatureItem(Icons.auto_awesome, 'Marketing Content Generation'),
          _buildFeatureItem(Icons.leaderboard, 'Lead Management'),
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
        const SizedBox(height: AppTheme.spacingSm),
        Text(
          AppConstants.appTagline,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.secondary),
          const SizedBox(width: AppTheme.spacingMd),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return SizedBox(
      width: 400,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sign In',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'Welcome back! Sign in to your agent dashboard.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTheme.spacingLg),

              // Demo notice
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: AppTheme.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.info, size: 18),
                    const SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                      child: Text(
                        'Demo mode — pre-filled credentials for testing.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.info,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),

              // Email
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),

              // Login button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
