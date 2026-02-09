import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _api.register({
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registracija uspješna! Prijavite se.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back to login
      }
    } catch (e) {
      setState(() {
        final eStr = e.toString();
        if (eStr.contains('već postoji')) {
          _error = 'Korisnik sa ovim emailom već postoji';
        } else {
          _error = 'Greška pri registraciji. Pokušajte ponovo.';
        }
      });
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registracija')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.person_add, size: 64, color: Theme.of(context).primaryColor),
                const SizedBox(height: 8),
                Text('Kreirajte račun', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Pridružite se volonterskoj zajednici', style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
                const SizedBox(height: 32),

                // Name
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      decoration: const InputDecoration(labelText: 'Ime *', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Unesite ime' : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      decoration: const InputDecoration(labelText: 'Prezime *', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Unesite prezime' : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email *', hintText: 'ime@domena.com', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Unesite email adresu';
                    if (!RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$').hasMatch(v.trim())) return 'Unesite validnu email adresu (npr. ime@domena.com)';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Telefon', hintText: '+387 6x xxx xxx', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: 'Lozinka *',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                    ),
                  ),
                  obscureText: _obscure1,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Unesite lozinku';
                    if (v.length < 6) return 'Lozinka mora imati najmanje 6 znakova';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm password
                TextFormField(
                  controller: _confirmPassCtrl,
                  decoration: InputDecoration(
                    labelText: 'Potvrdite lozinku *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                  ),
                  obscureText: _obscure2,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Potvrdite lozinku';
                    if (v != _passwordCtrl.text) return 'Lozinke se ne podudaraju';
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Error
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 16),

                // Register button
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _loading ? null : _register,
                    icon: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.person_add),
                    label: Text(_loading ? 'Registracija...' : 'Registruj se', style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),

                // Login link
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Već imate račun?'),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Prijavite se')),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
