import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});
  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _token = TextEditingController(); // pour confirmation optionnelle
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _submitSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            email: _email.text.trim(),
            username: _username.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inscription ok. Vérifie ton email (token).'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Échec inscription : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitConfirm() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .confirmEmail(token: _token.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Email confirmé !')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Échec confirmation : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _password.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ExLibris · Inscription')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email requis';
                      if (!v.contains('@')) return 'Email invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: 'Nom utilisateur',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    obscureText: _obscure,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submitSignup,
                      child: Text(_loading ? 'Création…' : 'Créer mon compte'),
                    ),
                  ),

                  const Divider(height: 40),

                  TextFormField(
                    controller: _token,
                    decoration: const InputDecoration(
                      labelText: 'Token de confirmation (option)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _loading ? null : _submitConfirm,
                      child: const Text('Confirmer mon email'),
                    ),
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
