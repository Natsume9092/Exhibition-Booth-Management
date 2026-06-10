import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  // Demo credentials
  final _demos = [
    ('admin@expo.com', 'Admin', UserRole.admin),
    ('organizer@techexpo.com', 'Organizer', UserRole.organizer),
    ('exhibitor@company.com', 'Exhibitor', UserRole.exhibitor),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 16),
          const Icon(Icons.event_seat, size: 72, color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          const Text('Welcome Back', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Sign in to manage your exhibitions', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),

          // Demo quick logins
          Card(
            color: Color(0xFF1364BF),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('User Access Level:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: _demos.map((d) => ActionChip(
                  label: Text(d.$2, style: const TextStyle(fontSize: 12)),
                  onPressed: () { _emailCtrl.text = d.$1; _passCtrl.text = 'demo123'; },
                )).toList()),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password', prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.error, color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 8),
                    Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Sign In'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.push('/register'),
                child: const Text("Don't have an account? Register"),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final error = await ref.read(authStateProvider.notifier).login(
      _emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      setState(() => _error = error);
    } else {
      final user = ref.read(authStateProvider);
      switch (user?.role) {
        case UserRole.exhibitor: context.go('/exhibitor'); break;
        case UserRole.organizer: context.go('/organizer'); break;
        case UserRole.admin: context.go('/admin'); break;
        default: context.go('/');
      }
    }
  }
}
