import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

const _dark = Color(0xFF050D1A);
const _navy = Color(0xFF0A1628);
const _cyan = Color(0xFF00B4D8);
const _blue = Color(0xFF0077B6);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  late final AnimationController _bgCtrl;
  bool _loading = false;
  String _photoUrl = '';
  int _wins = 0, _losses = 0, _total = 0;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 10))
      ..repeat(reverse: true);
    _loadProfile();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted && doc.exists) {
      final d = doc.data()!;
      setState(() {
        _nameCtrl.text = d['username'] ?? '';
        _photoUrl = d['photoUrl'] ?? '';
        _wins = d['wins'] ?? 0;
        _losses = d['losses'] ?? 0;
        _total = d['totalGames'] ?? 0;
      });
    }
  }

  Future<void> _updateName() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 3) {
      _snack('İsim en az 3 karakter olmalı');
      return;
    }
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'username': name});
    await FirebaseAuth.instance.currentUser!.updateDisplayName(name);
    setState(() => _loading = false);
    _snack('İsim güncellendi!', success: true);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
          source: ImageSource.gallery, maxWidth: 512, imageQuality: 75);
    } on Exception catch (e) {
      _snack('Hata: Galeriye erişilemedi. İzinleri kontrol edin.');
      debugPrint('Pick error: $e');
      return;
    } catch (e) {
      _snack('Beklenmedik bir hata oluştu.');
      return;
    }
    
    if (picked == null) return;

    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref =
          FirebaseStorage.instance.ref().child('profile_photos/$uid.jpg');

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(picked.path));
      }

      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'photoUrl': url});
      await FirebaseAuth.instance.currentUser!.updatePhotoURL(url);
      setState(() => _photoUrl = url);
      _snack('Fotoğraf güncellendi!', success: true);
    } catch (e) {
      _snack('Fotoğraf yüklenemedi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF22C55E) : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(_dark, const Color(0xFF060F1F), t)!,
                  Color.lerp(_navy, const Color(0xFF0C1E35), t)!,
                  Color.lerp(const Color(0xFF071526), _dark, t)!,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                    top: -100,
                    right: -80,
                    child: _Orb(_cyan, 260, .12 + t * .04)),
                Positioned(
                    bottom: -80,
                    left: -60,
                    child: _Orb(_blue, 200, .10 + t * .04)),
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white.withOpacity(.07),
                                  border: Border.all(
                                      color:
                                          Colors.white.withOpacity(.1)),
                                ),
                                child: Icon(Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white.withOpacity(.7),
                                    size: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Profil',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20)),
                          ],
                        ),
                        const SizedBox(height: 32),

                        GestureDetector(
                          onTap: _pickPhoto,
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                      colors: [_cyan, _blue]),
                                  boxShadow: [
                                    BoxShadow(
                                        color: _cyan.withOpacity(.3),
                                        blurRadius: 24)
                                  ],
                                ),
                                child: _photoUrl.isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(_photoUrl,
                                            fit: BoxFit.cover,
                                            width: 100,
                                            height: 100,
                                            errorBuilder: (ctx, err, st) => const Icon(Icons.person_rounded, color: Colors.white, size: 48)))
                                    : const Icon(Icons.person_rounded,
                                        color: Colors.white, size: 48),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _cyan,
                                    border: Border.all(
                                        color: _dark, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Fotoğrafı değiştirmek için dokun',
                          style: TextStyle(
                              color: Colors.white.withOpacity(.35),
                              fontSize: 12),
                        ),
                        const SizedBox(height: 28),

                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kullanıcı Adı',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withOpacity(.5),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _nameCtrl,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                      Icons.person_outline_rounded,
                                      color: _cyan,
                                      size: 20),
                                  filled: true,
                                  fillColor:
                                      Colors.white.withOpacity(.06),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.white
                                            .withOpacity(.1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: _cyan, width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: _loading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                            color: _cyan))
                                    : _Btn(
                                        label: 'Kaydet',
                                        onTap: _updateName),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('İstatistikler',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withOpacity(.5),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _StatBox(
                                      label: 'Toplam',
                                      value: '$_total',
                                      color: _cyan),
                                  const SizedBox(width: 10),
                                  _StatBox(
                                      label: 'Kazanma',
                                      value: '$_wins',
                                      color: const Color(0xFF22C55E)),
                                  const SizedBox(width: 10),
                                  _StatBox(
                                      label: 'Kaybetme',
                                      value: '$_losses',
                                      color: const Color(0xFFEF4444)),
                                ],
                              ),
                              if (_total > 0) ...[
                                const SizedBox(height: 16),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Kazanma Oranı',
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(.5),
                                                fontSize: 12)),
                                        Text(
                                            '${(_wins / _total * 100).toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                                color: _cyan,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        color: Colors.white
                                            .withOpacity(.08),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: _wins / _total,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            gradient:
                                                const LinearGradient(
                                                    colors: [_cyan, _blue]),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


class _Orb extends StatelessWidget {
  final Color c;
  final double size, op;
  const _Orb(this.c, this.size, this.op);
  @override
  Widget build(BuildContext ctx) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.withOpacity(op),
          boxShadow: [
            BoxShadow(
                color: c.withOpacity(op * .6), blurRadius: size * .8)
          ],
        ),
      );
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(.05),
          border: Border.all(color: Colors.white.withOpacity(.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.2),
                blurRadius: 24,
                offset: const Offset(0, 10))
          ],
        ),
        child: child,
      );
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext ctx) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: color.withOpacity(.1),
            border: Border.all(color: color.withOpacity(.25)),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 26,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      color: color.withOpacity(.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

class _Btn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.onTap});
  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _p = false;
  @override
  Widget build(BuildContext ctx) => GestureDetector(
        onTapDown: (_) => setState(() => _p = true),
        onTapUp: (_) {
          setState(() => _p = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _p = false),
        child: AnimatedScale(
          scale: _p ? .96 : 1,
          duration: const Duration(milliseconds: 100),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(colors: [_cyan, _blue]),
              boxShadow: [
                BoxShadow(
                    color: _cyan.withOpacity(.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Center(
                child: Text(widget.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15))),
          ),
        ),
      );
}
