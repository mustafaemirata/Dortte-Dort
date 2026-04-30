import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _cyan   = Color(0xFF00B4D8);
const _blue   = Color(0xFF0077B6);
const _dark   = Color(0xFF050D1A);
const _navy   = Color(0xFF0A1628);

class GameScreen extends StatefulWidget {
  final String roomCode;
  const GameScreen({super.key, required this.roomCode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  List<bool> _evaluate(String secret, String guess) {
    return List.generate(4, (i) => secret[i] == guess[i]);
  }

  Future<void> _submitSecret(bool isP1) async {
    final s = _inputCtrl.text.trim();
    if (s.length != 4) { _snack('Sayı tam 4 haneli olmalı'); return; }
    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode)
        .update({isP1 ? 'p1_secret' : 'p2_secret': s});
    _inputCtrl.clear();
  }

  Future<void> _submitGuess(Map<String, dynamic> data, String uid, bool isP1) async {
    final guess = _inputCtrl.text.trim();
    if (guess.length != 4) { _snack('Tahmin tam 4 haneli olmalı'); return; }
    final opSecret = isP1 ? data['p2_secret'] : data['p1_secret'];
    final matches = _evaluate(opSecret, guess);
    final allCorrect = matches.every((m) => m);
    final field = isP1 ? 'p1_guesses' : 'p2_guesses';
    final list = List.from(data[field] ?? [])..add({'guess': guess, 'matches': matches});
    final updates = <String, dynamic>{
      field: list,
      'turn': isP1 ? data['player2'] : data['player1'],
    };
    if (allCorrect) {
      updates['winner'] = uid;
      updates['status'] = 'finished';
      final loserUid = isP1 ? data['player2'] : data['player1'];
      final usersRef = FirebaseFirestore.instance.collection('users');
      usersRef.doc(uid).update({
        'wins': FieldValue.increment(1),
        'totalGames': FieldValue.increment(1),
      });
      usersRef.doc(loserUid).update({
        'losses': FieldValue.increment(1),
        'totalGames': FieldValue.increment(1),
      });
    }
    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode).update(updates);
    _inputCtrl.clear();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            backgroundColor: _dark,
            body: const Center(child: CircularProgressIndicator(color: _cyan)),
          );
        }
        final data = snap.data!.data() as Map<String, dynamic>?;
        if (data == null) {
          return const SizedBox.shrink();
        }

        final isP1 = data['player1'] == uid;
        final p1Name = data['player1_name'] ?? 'Oyuncu 1';
        final p2Name = data['player2_name'] ?? 'Oyuncu 2';
        final p1Photo = data['player1_photo'] as String? ?? '';
        final p2Photo = data['player2_photo'] as String? ?? '';
        final myName = isP1 ? p1Name : p2Name;
        final opName = isP1 ? p2Name : p1Name;
        final myPhoto = isP1 ? p1Photo : p2Photo;
        final opPhoto = isP1 ? p2Photo : p1Photo;

        final p1Secret = data['p1_secret'];
        final p2Secret = data['p2_secret'];
        final mySecret = isP1 ? p1Secret : p2Secret;
        final winner = data['winner'];
        final isMyTurn = data['turn'] == uid;
        final hasPlayer2 = data['player2'] != null;

        Widget body;
        if (!hasPlayer2 && isP1) {
          body = _WaitingView(code: widget.roomCode, myName: myName, myPhoto: myPhoto);
        } else if (mySecret == null) {
          body = _SecretInputView(
            ctrl: _inputCtrl, 
            onSubmit: () => _submitSecret(isP1),
            myName: myName,
            myPhoto: myPhoto,
          );
        } else if (p1Secret == null || p2Secret == null) {
          body = _InfoView(
            msg: 'Rakibin sayısını girmesi\nbekleniyor...', 
            icon: Icons.hourglass_empty_rounded,
            myName: opName,
            myPhoto: opPhoto,
          );
        } else if (winner != null) {
          body = _ResultView(
            won: winner == uid,
            opSecret: isP1 ? p2Secret : p1Secret,
            roomCode: widget.roomCode,
            onBack: () => Navigator.pop(context),
          );
        } else {
          body = _GamePlayView(
            data: data,
            uid: uid,
            isP1: isP1,
            isMyTurn: isMyTurn,
            myName: myName,
            opName: opName,
            myPhoto: myPhoto,
            opPhoto: opPhoto,
            ctrl: _inputCtrl,
            onGuess: () => _submitGuess(data, uid, isP1),
          );
        }

        return AnimatedBuilder(
          animation: _bgCtrl,
          builder: (ctx, _) {
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
                child: Stack(children: [
                  Positioned(top: -80, right: -80, child: _Orb(color: _cyan, size: 240, op: 0.15 + t * 0.05)),
                  Positioned(bottom: -60, left: -60, child: _Orb(color: _blue, size: 200, op: 0.12 + t * 0.04)),
                  SafeArea(
                    child: Column(children: [
                                            _GameAppBar(
                        code: widget.roomCode,
                        p1Name: p1Name, p2Name: p2Name,
                        p1Photo: p1Photo, p2Photo: p2Photo,
                        mySecret: mySecret,
                      ),
                      Expanded(child: body),
                    ]),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

class _GameAppBar extends StatelessWidget {
  final String code, p1Name, p2Name;
  final String p1Photo, p2Photo;
  final String? mySecret;
  const _GameAppBar({required this.code, required this.p1Name, required this.p2Name,
    required this.p1Photo, required this.p2Photo, this.mySecret});

  Widget _avatar(String url, String name) => _PlayerAvatar(url: url, name: name, size: 32);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withOpacity(0.08),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white.withOpacity(0.7), size: 14),
          ),
        ),
        const SizedBox(width: 10),
        _avatar(p1Photo, p1Name),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(p1Name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                overflow: TextOverflow.ellipsis)),
            Text('  vs  ', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
            Flexible(child: Text(p2Name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                overflow: TextOverflow.ellipsis)),
          ]),
          Text('Oda: $code', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10)),
        ])),
        const SizedBox(width: 6),
        _avatar(p2Photo, p2Name),
        if (mySecret != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withOpacity(0.07),
              border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.25)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Sayınız', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 8)),
              Text(mySecret!, style: const TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _WaitingView extends StatelessWidget {
  final String code, myName, myPhoto;
  const _WaitingView({required this.code, required this.myName, required this.myPhoto});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      _PlayerAvatar(url: myPhoto, name: myName, size: 80),
      const SizedBox(height: 16),
      Text('Hoş geldin, $myName', style: const TextStyle(color: Colors.white70, fontSize: 16)),
      const SizedBox(height: 24),
      const CircularProgressIndicator(color: _cyan, strokeWidth: 2),
      const SizedBox(height: 20),
      const Text('Rakip bekleniyor...', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 24),
      Text('Oda Kodu:', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: code));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod kopyalandı!')));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [_cyan, _blue]),
            boxShadow: [BoxShadow(color: _cyan.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Text(code, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 8)),
        ),
      ),
      const SizedBox(height: 8),
      Text('Kopyalamak için dokun', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
    ]));
  }
}

class _SecretInputView extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSubmit;
  final String myName, myPhoto;
  const _SecretInputView({required this.ctrl, required this.onSubmit, required this.myName, required this.myPhoto});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _PlayerAvatar(url: myPhoto, name: myName, size: 64),
        const SizedBox(height: 20),
        const Icon(Icons.lock_outline_rounded, color: _cyan, size: 40),
        const SizedBox(height: 16),
        const Text('Gizli Sayını Gir', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Rakibinin tahmin etmeye çalışacağı\n4 haneli sayıyı belirle.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
        const SizedBox(height: 32),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 12),
          decoration: InputDecoration(
            counterText: '',
            hintText: '····',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 32, letterSpacing: 12),
            filled: true,
            fillColor: Colors.white.withOpacity(0.07),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _cyan, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: _GradBtn(label: 'Sayıyı Kilitle', onTap: onSubmit),
        ),
      ]),
    );
  }
}

class _InfoView extends StatelessWidget {
  final String msg, myName, myPhoto;
  final IconData icon;
  const _InfoView({required this.msg, required this.icon, required this.myName, required this.myPhoto});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      _PlayerAvatar(url: myPhoto, name: myName, size: 64),
      const SizedBox(height: 16),
      Icon(icon, color: Colors.white54, size: 56),
      const SizedBox(height: 20),
      Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
    ]));
  }
}

class _ResultView extends StatelessWidget {
  final bool won;
  final String opSecret;
  final String roomCode;
  final VoidCallback onBack;
  const _ResultView({required this.won, required this.opSecret, required this.roomCode, required this.onBack});

  Future<void> _deleteAndBack(BuildContext context) async {
    onBack(); // Go back first
    await FirebaseFirestore.instance.collection('rooms').doc(roomCode).delete(); // Then delete
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
          color: won ? const Color(0xFFFBBF24) : Colors.redAccent, size: 72),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (b) => LinearGradient(
            colors: won ? [const Color(0xFFFBBF24), const Color(0xFFF59E0B)] : [Colors.redAccent, const Color(0xFFFF6B6B)],
          ).createShader(b),
          child: Text(won ? 'KAZANDIN!' : 'KAYBETTİN!',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withOpacity(0.07),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(children: [
            Text('Rakibin sayısı', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
            const SizedBox(height: 8),
            Text(opSecret, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 14)),
          ]),
        ),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, child: _GradBtn(label: 'Ana Menüye Dön', onTap: () => _deleteAndBack(context))),
      ]),
    ));
  }
}

class _GamePlayView extends StatelessWidget {
  final Map<String, dynamic> data;
  final String uid, myName, opName, myPhoto, opPhoto;
  final bool isP1, isMyTurn;
  final TextEditingController ctrl;
  final VoidCallback onGuess;
  const _GamePlayView({
    required this.data, required this.uid, required this.isP1,
    required this.isMyTurn, required this.myName, required this.opName,
    required this.myPhoto, required this.opPhoto,
    required this.ctrl, required this.onGuess,
  });

  @override
  Widget build(BuildContext context) {
    final myGuesses = (isP1 ? data['p1_guesses'] : data['p2_guesses']) as List? ?? [];
    final opGuesses = (isP1 ? data['p2_guesses'] : data['p1_guesses']) as List? ?? [];
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isMyTurn ? _cyan.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          border: Border.all(color: isMyTurn ? _cyan.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isMyTurn ? Icons.sports_esports : Icons.hourglass_empty_rounded,
              color: isMyTurn ? const Color(0xFFA78BFA) : Colors.white38, size: 18),
          const SizedBox(width: 8),
          Text(isMyTurn ? 'Sıra Sende!' : 'Rakibin sırası...',
              style: TextStyle(
                color: isMyTurn ? const Color(0xFFA78BFA) : Colors.white38,
                fontWeight: FontWeight.w700, fontSize: 15,
              )),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(child: _GuessList(title: myName, photo: myPhoto, guesses: myGuesses, accent: _cyan)),
            const SizedBox(width: 8),
            Expanded(child: _GuessList(title: opName, photo: opPhoto, guesses: opGuesses, accent: _blue)),
          ]),
        ),
      ),
      if (isMyTurn)
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 6),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '····',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), letterSpacing: 6),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cyan, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onGuess,
              child: Container(
                height: 52, width: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(colors: [_cyan, _blue]),
                  boxShadow: [BoxShadow(color: _cyan.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: const Center(child: Text('Gir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
              ),
            ),
          ]),
        )
      else
        const SizedBox(height: 80),
    ]);
  }
}

class _GuessList extends StatelessWidget {
  final String title, photo;
  final List guesses;
  final Color accent;
  const _GuessList({required this.title, required this.photo, required this.guesses, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: accent.withOpacity(0.1),
          border: Border.all(color: accent.withOpacity(0.2)),
        ),
        child: Row(children: [
          _PlayerAvatar(url: photo, name: title, size: 24),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(color: accent.withOpacity(0.9), fontWeight: FontWeight.w700, fontSize: 12),
              overflow: TextOverflow.ellipsis)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: guesses.length,
          itemBuilder: (_, i) {
            final g = guesses[i];
            final guess = g['guess'] as String;
            final matches = List<bool>.from(g['matches'] ?? [false, false, false, false]);
            final allCorrect = matches.every((m) => m);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.06),
                border: Border.all(color: allCorrect ? const Color(0xFF22C55E).withOpacity(0.5) : Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (j) {
                  final correct = matches[j];
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(guess[j],
                      style: TextStyle(
                        color: correct ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                        fontSize: 20, fontWeight: FontWeight.w900,
                      )),
                    const SizedBox(height: 2),
                    Icon(
                      correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: correct ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                      size: 16,
                    ),
                  ]);
                }),
              ),
            );
          },
        ),
      ),
    ]);
  }
}


class _PlayerAvatar extends StatelessWidget {
  final String url, name;
  final double size;
  const _PlayerAvatar({required this.url, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [_cyan, _blue]),
        boxShadow: [BoxShadow(color: _cyan.withOpacity(0.2), blurRadius: size/4)],
      ),
      child: url.isNotEmpty
        ? ClipOval(child: Image.network(
            url, fit: BoxFit.cover, width: size, height: size,
            errorBuilder: (context, error, stackTrace) => Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.45))),
          ))
        : Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.45))),
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size, op;
  const _Orb({required this.color, required this.size, required this.op});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(op),
      boxShadow: [BoxShadow(color: color.withOpacity(op * 0.6), blurRadius: size * 0.8)],
    ),
  );
}

class _GradBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _GradBtn({required this.label, required this.onTap});

  @override
  State<_GradBtn> createState() => _GradBtnState();
}

class _GradBtnState extends State<_GradBtn> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) { setState(() => _p = false); widget.onTap(); },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedScale(
        scale: _p ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(colors: [_cyan, _blue]),
            boxShadow: [BoxShadow(color: _cyan.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Center(child: Text(widget.label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
        ),
      ),
    );
  }
}
