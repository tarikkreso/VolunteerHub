import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(
        _identityController.text.trim(),
        _passwordController.text,
      );
      
      if (success && mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(text: _identityController.text.trim());

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset lozinke'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Unesite email naloga',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email je obavezan';
              }
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Unesite ispravan email format';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Otkaži'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Pošalji upute'),
          ),
        ],
      ),
    );

    if (submitted != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.forgotPassword(emailController.text.trim());
    if (!mounted) return;

    if (success) {
      final info = auth.infoMessage ?? 'Ako korisnik sa unesenim emailom postoji, poslali smo upute za reset lozinke.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(info)));
      await _showResetPasswordDialog(initialEmail: emailController.text.trim());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Slanje zahtjeva nije uspjelo.')),
      );
    }
  }

  Future<void> _showResetPasswordDialog({String? initialEmail}) async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(text: initialEmail ?? _identityController.text.trim());
    final tokenController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Unesite reset token'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Email je obavezan';
                      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!emailRegex.hasMatch(value.trim())) return 'Unesite ispravan email format';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: tokenController,
                    decoration: const InputDecoration(
                      labelText: 'Token',
                      hintText: 'Token iz email poruke',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Token je obavezan';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Nova lozinka',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setStateDialog(() => obscureNew = !obscureNew),
                        icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Nova lozinka je obavezna';
                      if (value.length < 6) return 'Lozinka mora imati najmanje 6 karaktera';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Potvrda lozinke',
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                      suffixIcon: IconButton(
                        onPressed: () => setStateDialog(() => obscureConfirm = !obscureConfirm),
                        icon: Icon(obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Potvrda lozinke je obavezna';
                      if (value != newPasswordController.text) return 'Lozinke se ne podudaraju';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Otkaži'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Resetuj lozinku'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(
      email: emailController.text.trim(),
      token: tokenController.text.trim(),
      newPassword: newPasswordController.text,
      confirmPassword: confirmPasswordController.text,
    );
    if (!mounted) return;

    if (success) {
      _passwordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.infoMessage ?? 'Lozinka je uspješno resetovana.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Reset lozinke nije uspio.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo and title
                  Icon(
                    Icons.volunteer_activism,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'VolunteerHub',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Povežite se sa zajednicom',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Email/username field
                  TextFormField(
                    controller: _identityController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Email ili korisničko ime',
                      hintText: 'npr. mobile ili ime@domena.com',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email ili korisničko ime je obavezno';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Lozinka',
                      hintText: 'Unesite lozinku',
                      prefixIcon: const Icon(Icons.lock_outlined),
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lozinka je obavezna';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  
                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text('Zaboravili ste lozinku?'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Error message
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      if (auth.error != null) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            auth.error!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  
                  // Login button
                  Consumer<AuthProvider>(
                    builder: (context, auth, child) {
                      return SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _login,
                          child: auth.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Prijavi se',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Nemate račun?'),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                        },
                        child: const Text('Registrujte se'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
