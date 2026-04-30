import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _dark  = Color(0xFF050D1A);
const _navy  = Color(0xFF0A1628);
const _cyan  = Color(0xFF00B4D8);
const _blue  = Color(0xFF0077B6);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool _isLogin    = true;
  bool _loading    = false;
  bool _obscure    = true;

  late final AnimationController _bgCtrl;
  late final AnimationController _cardCtrl;
  late final Animation<double>   _cardFade;
  late final Animation<Offset>   _cardSlide;

  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat(reverse: true);
    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _cardFade  = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, .07), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut));
    _cardCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose(); _cardCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose(); _usernameCtrl.dispose();
    super.dispose();
  }

  void _switchMode() {
    _cardCtrl.reset();
    setState(() => _isLogin = !_isLogin);
    _cardCtrl.forward();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
        final username = _usernameCtrl.text.trim();
        await Future.wait([
          FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
            'username': username, 'email': _emailCtrl.text.trim(),
            'wins': 0, 'losses': 0, 'totalGames': 0,
            'createdAt': FieldValue.serverTimestamp(),
          }),
          cred.user!.updateDisplayName(username),
        ]);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _snack(_mapError(e.code));
    } catch (_) {
      if (mounted) _snack('Bir hata oluştu.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapError(String code) => switch (code) {
    'user-not-found'       => 'Kullanıcı bulunamadı.',
    'wrong-password'       => 'Şifre yanlış.',
    'email-already-in-use' => 'Bu e-posta zaten kullanılıyor.',
    'weak-password'        => 'Şifre çok zayıf (min. 6 karakter).',
    'invalid-email'        => 'Geçersiz e-posta adresi.',
    _                      => 'Hata: $code',
  };

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: const Color(0xFFE53935),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) {
          final t = _bgCtrl.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  Color.lerp(_dark, const Color(0xFF060F1F), t)!,
                  Color.lerp(_navy, const Color(0xFF0C1E35), t)!,
                  Color.lerp(const Color(0xFF071526), _dark, t)!,
                ],
              ),
            ),
            child: Stack(children: [
              Positioned(top: -120, right: -80,
                child: _Orb(_cyan, 280, .12 + t * .05)),
              Positioned(bottom: -100, left: -60,
                child: _Orb(_blue, 240, .10 + t * .04)),
              Positioned(top: MediaQuery.of(context).size.height * .55, left: 20,
                child: _Orb(_cyan, 120, .06 + t * .03)),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                    child: FadeTransition(
                      opacity: _cardFade,
                      child: SlideTransition(
                        position: _cardSlide,
                        child: Column(children: [
                          const SizedBox(height: 24),
                          const Text('Dörtte Dört',
                            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
                                color: Colors.white, letterSpacing: .5)),
                          const SizedBox(height: 4),
                          Text(_isLogin ? 'Hesabına giriş yap' : 'Yeni hesap oluştur',
                            style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(.45))),
                          const SizedBox(height: 32),

                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Colors.white.withOpacity(.05),
                              border: Border.all(color: Colors.white.withOpacity(.1), width: 1),
                              boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(.3),
                                blurRadius: 40, offset: const Offset(0, 20),
                              )],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.05),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(children: [
                                    _Tab('Giriş',    _isLogin,  () { if (!_isLogin) _switchMode(); }),
                                    _Tab('Kayıt Ol', !_isLogin, () { if (_isLogin)  _switchMode(); }),
                                  ]),
                                ),
                                const SizedBox(height: 26),

                                AnimatedSize(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeInOut,
                                  child: _isLogin ? const SizedBox.shrink() : Column(children: [
                                    _Input(ctrl: _usernameCtrl, label: 'Kullanıcı Adı',
                                      icon: Icons.person_outline_rounded,
                                      validator: (v) => (v == null || v.trim().length < 3) ? 'En az 3 karakter' : null),
                                    const SizedBox(height: 14),
                                  ]),
                                ),

                                _Input(ctrl: _emailCtrl, label: 'E-posta',
                                  icon: Icons.mail_outline_rounded,
                                  keyboard: TextInputType.emailAddress,
                                  validator: (v) => (v == null || !v.contains('@')) ? 'Geçerli e-posta girin' : null),
                                const SizedBox(height: 14),
                                _Input(ctrl: _passCtrl, label: 'Şifre',
                                  icon: Icons.lock_outline_rounded,
                                  obscure: _obscure,
                                  suffix: IconButton(
                                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: Colors.white.withOpacity(.4), size: 20),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                  validator: (v) => (v == null || v.length < 6) ? 'En az 6 karakter' : null),
                                const SizedBox(height: 28),

                                _loading
                                  ? const Center(child: CircularProgressIndicator(color: _cyan))
                                  : _PrimaryBtn(
                                      label: _isLogin ? 'Giriş Yap' : 'Hesap Oluştur',
                                      onTap: _submit),
                              ]),
                            ),
                          ),

                          const SizedBox(height: 18),
                          GestureDetector(
                            onTap: _switchMode,
                            child: RichText(text: TextSpan(
                              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(.45)),
                              children: [
                                TextSpan(text: _isLogin ? 'Hesabın yok mu? ' : 'Zaten hesabın var mı? '),
                                TextSpan(text: _isLogin ? 'Kayıt Ol' : 'Giriş Yap',
                                  style: const TextStyle(color: _cyan, fontWeight: FontWeight.w700)),
                              ],
                            )),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}


class _Orb extends StatelessWidget {
  final Color c; final double size, op;
  const _Orb(this.c, this.size, this.op);
  @override Widget build(BuildContext ctx) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
      color: c.withOpacity(op),
      boxShadow: [BoxShadow(color: c.withOpacity(op * .6), blurRadius: size * .8)]),
  );
}

class _Tab extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _Tab(this.label, this.active, this.onTap);
  @override Widget build(BuildContext ctx) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: active ? const LinearGradient(colors: [_cyan, _blue]) : null,
        boxShadow: active ? [BoxShadow(color: _cyan.withOpacity(.3), blurRadius: 12, offset: const Offset(0, 4))] : [],
      ),
      child: Center(child: Text(label, style: TextStyle(
        color: active ? Colors.white : Colors.white.withOpacity(.4),
        fontWeight: active ? FontWeight.w700 : FontWeight.w500, fontSize: 14))),
    ),
  ));
}

class _Input extends StatelessWidget {
  final TextEditingController ctrl;
  final String label; final IconData icon;
  final TextInputType? keyboard; final bool obscure;
  final Widget? suffix; final String? Function(String?)? validator;
  const _Input({required this.ctrl, required this.label, required this.icon,
    this.keyboard, this.obscure = false, this.suffix, this.validator});
  @override Widget build(BuildContext ctx) => TextFormField(
    controller: ctrl, keyboardType: keyboard, obscureText: obscure,
    validator: validator,
    style: const TextStyle(color: Colors.white, fontSize: 15),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 14),
      prefixIcon: Icon(icon, color: _cyan, size: 20),
      suffixIcon: suffix,
      filled: true, fillColor: Colors.white.withOpacity(.06),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _cyan, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF5350))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1.5)),
      errorStyle: const TextStyle(color: Color(0xFFEF9A9A)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
  );
}

class _PrimaryBtn extends StatefulWidget {
  final String label; final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap});
  @override State<_PrimaryBtn> createState() => _PrimaryBtnState();
}
class _PrimaryBtnState extends State<_PrimaryBtn> {
  bool _p = false;
  @override Widget build(BuildContext ctx) => GestureDetector(
    onTapDown: (_) => setState(() => _p = true),
    onTapUp: (_) { setState(() => _p = false); widget.onTap(); },
    onTapCancel: () => setState(() => _p = false),
    child: AnimatedScale(scale: _p ? .96 : 1, duration: const Duration(milliseconds: 100),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [_cyan, _blue],
            begin: Alignment.centerLeft, end: Alignment.centerRight),
          boxShadow: [BoxShadow(color: _cyan.withOpacity(.4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Center(child: Text(widget.label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
              fontSize: 16, letterSpacing: .4))),
      ),
    ),
  );
}
