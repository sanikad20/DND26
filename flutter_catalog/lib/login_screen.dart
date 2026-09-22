import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading       = false;
  bool obscurePassword = true;

  void _navigateHome(User user) {
    String name = user.displayName?.trim() ?? '';
    if (name.isEmpty) {
      name = user.email!.split('@').first;
      name = name.replaceAll(RegExp(r'[0-9]'), '');
      name = name.split(RegExp(r'[._\-]')).first;
    }
    name = name.split(' ').first;
    if (name.isNotEmpty) {
      name = name[0].toUpperCase() + name.substring(1).toLowerCase();
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(name: name)),
    );
  }

  Future<void> loginUser() async {
    final email    = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      if (!mounted) return;
      _navigateHome(credential.user!);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? 'Login failed')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetCtrl = TextEditingController(text: emailController.text.trim());
    await showDialog(
      context: context,
      builder: (ctx) {
        bool sending = false;
        final theme = Theme.of(ctx);
        final isDark = ThemeController.instance.isDarkMode;
        final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightPrimaryNavy;
        final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Reset Password',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your registered email. We\'ll send a password reset link.',
                  style: TextStyle(color: secondaryTextColor, fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: resetCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: secondaryTextColor),
                ),
              ),
              ElevatedButton(
                onPressed: sending
                    ? null
                    : () async {
                        final email = resetCtrl.text.trim();
                        if (email.isEmpty) return;
                        setDialogState(() => sending = true);
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await FirebaseAuth.instance
                              .sendPasswordResetEmail(email: email);
                          if (!mounted) return;
                          nav.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Reset email sent! Check your inbox.'),
                            ),
                          );
                        } on FirebaseAuthException catch (e) {
                          setDialogState(() => sending = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text(e.message ?? 'Could not send email')),
                          );
                        }
                      },
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Send Link'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ThemeController.instance.isDarkMode;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightPrimaryNavy;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final mutedTextColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 85,
                        height: 85,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to your Veer Mitra account',
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined, color: mutedTextColor),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline, color: mutedTextColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: mutedTextColor,
                          ),
                          onPressed: () =>
                              setState(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppColors.saffronAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : loginUser,
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: Text(
                        "Don't have an account? Register",
                        style: TextStyle(
                          color: primaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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