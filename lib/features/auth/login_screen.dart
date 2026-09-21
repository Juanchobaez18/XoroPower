import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text;
    final pass = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showErrorDialog('Por favor ingresa un correo electrónico válido');
      return;
    }
    if (pass.isEmpty || pass.length < 6) {
      _showErrorDialog('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.login(email, pass);
      
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Error de inicio de sesión", style: TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.white.withOpacity(0.8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(backgroundColor: const Color(0xFF0055FF)),
            child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // XoroBlack
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section
            SizedBox(
              height: 260,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/usuario.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, const Color(0xFF000000)],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 35,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    offset: Offset(4, 4),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              children: [
                                TextSpan(text: 'XORO', style: TextStyle(color: Color(0xFF0055FF))), // ElectricBlue
                                TextSpan(text: 'PO', style: TextStyle(color: Colors.white)),
                                TextSpan(text: 'WER', style: TextStyle(color: Color(0xFFFF0033))), // BrightRed
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'BIENVENIDO DE VUELTA',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // Form Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      label: 'CORREO ELECTRÓNICO',
                      placeholder: 'tu@correo.com',
                      icon: Icons.mail_outline,
                      controller: _emailController,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: 'CONTRASEÑA',
                      placeholder: 'Contraseña',
                      icon: Icons.lock_outline,
                      controller: _passwordController,
                      isPassword: true,
                      obscureText: !_passwordVisible,
                      onToggleVisibility: () {
                        setState(() => _passwordVisible = !_passwordVisible);
                      },
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0055FF), // ElectricBlue
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'ENTRAR A LA APP',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                              ],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('¿Aún no tienes cuenta? ', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15)),
                GestureDetector(
                  onTap: () => context.push('/register'),
                  child: const Text('Regístrate aquí', style: TextStyle(color: Color(0xFF0055FF), fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String placeholder,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
            prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4)),
            suffixIcon: isPassword ? IconButton(
              icon: Icon(obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white.withOpacity(0.3)),
              onPressed: onToggleVisibility,
            ) : null,
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0055FF)),
            ),
          ),
        ),
      ],
    );
  }
}
