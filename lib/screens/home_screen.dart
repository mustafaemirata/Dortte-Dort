import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_screen.dart';
import 'profile_screen.dart';

const _dark = Color(0xFF050D1A);
const _navy = Color(0xFF0A1628);
const _cyan = Color(0xFF00B4D8);
const _blue = Color(0xFF0077B6);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _codeCtrl = TextEditingController();
  bool _loading   = false;
  String _username = '';
  String _photoUrl = '';

  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat(reverse: true);
    _loadUserData();
  }

  @override
  void dispose() { _bgCtrl.dispose(); _codeCtrl.dispose(); super.dispose(); }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted && doc.exists) {
      final d = doc.data()!;
      setState(() {
        _username = d['username'] ?? '';
        _photoUrl = d['photoUrl'] ?? '';
      });
    }
  }

  String _genCode() => (Random().nextInt(90000) + 10000).toString();

  Future<void> _createRoom() async {
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser!;
    final code = _genCode();
    await FirebaseFirestore.instance.collection('rooms').doc(code).set({
      'status': 'waiting',
      'player1': user.uid,
      'player1_name': _username.isNotEmpty ? _username : 'Oyuncu 1',
      'player1_photo': _photoUrl,
      'player2': null, 'player2_name': null, 'player2_photo': null,
      'p1_secret': null, 'p2_secret': null,
      'p1_guesses': [], 'p2_guesses': [],
      'turn': user.uid, 'winner': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    setState(() => _loading = false);
    if (mounted) Navigator.push(context, _fade(GameScreen(roomCode: code)));
  }

  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 5) { _snack('Geçerli bir 5 haneli kod girin.'); return; }
    setState(() => _loading = true);
    final ref = FirebaseFirestore.instance.collection('rooms').doc(code);
    final doc = await ref.get();
    if (!doc.exists) { setState(() => _loading = false); _snack('Oda bulunamadı.'); return; }
    final data = doc.data()!;
    final uid  = FirebaseAuth.instance.currentUser!.uid;
    if (data['player1'] == uid || data['player2'] == uid) {
      setState(() => _loading = false);
      if (mounted) Navigator.push(context, _fade(GameScreen(roomCode: code)));
      return;
    }
    if (data['player2'] == null) {
      await ref.update({
        'player2': uid,
        'player2_name': _username.isNotEmpty ? _username : 'Oyuncu 2',
        'player2_photo': _photoUrl,
        'status': 'playing',
      });
      setState(() => _loading = false);
      if (mounted) Navigator.push(context, _fade(GameScreen(roomCode: code)));
    } else {
      setState(() => _loading = false);
      _snack('Oda dolu.');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: const Color(0xFFE53935),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));

  Route _fade(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    transitionDuration: const Duration(milliseconds: 350),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) {
          final t = _bgCtrl.value;
          return Container(
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                Color.lerp(_dark, const Color(0xFF060F1F), t)!,
                Color.lerp(_navy, const Color(0xFF0C1E35), t)!,
                Color.lerp(const Color(0xFF071526), _dark, t)!,
              ],
            )),
            child: Stack(children: [
              Positioned(top: -100, right: -80, child: _Orb(_cyan, 280, .11 + t * .04)),
              Positioned(bottom: -80, left: -60, child: _Orb(_blue, 220, .09 + t * .04)),
              SafeArea(child: _loading
                ? const Center(child: CircularProgressIndicator(color: _cyan))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(children: [
                      Row(children: [
                        GestureDetector(
                          onTap: () => Navigator.push(context, _fade(const ProfileScreen())).then((_) => _loadUserData()),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(colors: [_cyan, _blue]),
                                  boxShadow: [BoxShadow(color: _cyan.withOpacity(.4), blurRadius: 12, offset: const Offset(0, 4))],
                                  border: Border.all(color: Colors.white.withOpacity(.15), width: 2),
                                ),
                                child: _photoUrl.isNotEmpty
                                  ? ClipOval(child: Image.network(_photoUrl, fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.person_rounded, color: Colors.white, size: 28)))
                                  : const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                              ),
                              Container(
                                width: 18, height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF22C55E),
                                  border: Border.all(color: _dark, width: 2),
                                ),
                                child: const Icon(Icons.edit, color: Colors.white, size: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_username.isNotEmpty ? 'Merhaba, $_username' : 'Merhaba!',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                          Text('Profilini düzenlemek için dokun',
                            style: TextStyle(color: Colors.white.withOpacity(.4), fontSize: 11)),
                        ])),
                        _IconBtn(icon: Icons.logout_rounded, onTap: () => FirebaseAuth.instance.signOut()),
                      ]),
                      const Spacer(),

                      Align(alignment: Alignment.centerLeft, child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hadi\nOynayalım.',
                            style: TextStyle(
                              fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white,
                              height: 1.1,
                              shadows: [Shadow(color: _cyan.withOpacity(.3), blurRadius: 20)],
                            )),
                          const SizedBox(height: 8),
                          Text('4 haneli sayını tut, rakibini bul.',
                            style: TextStyle(color: Colors.white.withOpacity(.4), fontSize: 15)),
                        ],
                      )),
                      const SizedBox(height: 32),

                      _Card(
                        gradient: const LinearGradient(colors: [_cyan, _blue],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                        glow: _cyan,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          const Text('Oda Oluştur',
                            style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('Yeni oda aç, kodu arkadaşına paylaş.',
                            style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 13)),
                          const SizedBox(height: 16),
                          _FlatBtn(label: 'Oluştur', light: true, onTap: _createRoom),
                        ]),
                      ),
                      const SizedBox(height: 14),

                      _Card(
                        gradient: LinearGradient(colors: [
                          Colors.white.withOpacity(.06),
                          Colors.white.withOpacity(.03),
                        ]),
                        glow: _blue,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Odaya Katıl',
                            style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _codeCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 5, textAlign: TextAlign.center,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(color: Colors.white, fontSize: 24,
                                fontWeight: FontWeight.w800, letterSpacing: 10),
                            decoration: InputDecoration(
                              hintText: '· · · · ·',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(.2),
                                  fontSize: 20, letterSpacing: 6),
                              counterText: '',
                              filled: true, fillColor: Colors.white.withOpacity(.06),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(.12))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _cyan, width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity,
                            child: _FlatBtn(label: 'Katıl', light: false, onTap: _joinRoom)),
                        ]),
                      ),
                      const Spacer(),
                    ]),
                  )),
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

class _Card extends StatelessWidget {
  final Widget child; final LinearGradient gradient; final Color glow;
  const _Card({required this.child, required this.gradient, required this.glow});
  @override Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: gradient,
      border: Border.all(color: Colors.white.withOpacity(.1)),
      boxShadow: [BoxShadow(color: glow.withOpacity(.18), blurRadius: 24, offset: const Offset(0, 10))],
    ),
    child: child,
  );
}

class _FlatBtn extends StatefulWidget {
  final String label; final bool light; final VoidCallback onTap;
  const _FlatBtn({required this.label, required this.light, required this.onTap});
  @override State<_FlatBtn> createState() => _FlatBtnState();
}
class _FlatBtnState extends State<_FlatBtn> {
  bool _p = false;
  @override Widget build(BuildContext ctx) => GestureDetector(
    onTapDown: (_) => setState(() => _p = true),
    onTapUp: (_) { setState(() => _p = false); widget.onTap(); },
    onTapCancel: () => setState(() => _p = false),
    child: AnimatedScale(scale: _p ? .96 : 1, duration: const Duration(milliseconds: 90),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: widget.light ? Colors.white : _cyan.withOpacity(.15),
          border: widget.light ? null : Border.all(color: _cyan.withOpacity(.4)),
        ),
        child: Center(child: Text(widget.label, style: TextStyle(
          color: widget.light ? _blue : _cyan,
          fontWeight: FontWeight.w700, fontSize: 15))),
      ),
    ),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(.07),
        border: Border.all(color: Colors.white.withOpacity(.1)),
      ),
      child: Icon(icon, color: Colors.white.withOpacity(.6), size: 20),
    ),
  );
}
