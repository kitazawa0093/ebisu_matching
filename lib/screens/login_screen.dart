import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'booking_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // ✅ 新規登録時に使う
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  String? _selectedGender; // 男性, 女性, その他, 回答しない

  bool _isLogin = true; // true:ログイン false:新規登録
  bool _isLoading = false;

  static const List<String> _genderOptions = ['男性', '女性'];

  bool _validateInput() {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メールとパスワードを入力してください')),
      );
      return false;
    }

    // ✅ 新規登録のときだけチェック
    if (!_isLogin) {
      if (_nameController.text.trim().isEmpty ||
          _contactController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('名前と連絡先を入力してください')),
        );
        return false;
      }
      if (_selectedGender == null || _selectedGender!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('性別を選択してください')),
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _submit() async {
    if (!_validateInput()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final contact = _contactController.text.trim();
    final gender = _selectedGender;

    try {
      if (_isLogin) {
        // =========================
        // ✅ ログイン
        // =========================
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credential.user;
        if (user != null) {
          await user.reload();
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null && !currentUser.emailVerified) {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'メールアドレスが未認証です。登録メールのリンクから認証してください。',
                ),
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: '再送',
                  onPressed: () => _resendVerificationEmail(email, password),
                ),
              ),
            );
            return;
          }
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BookingScreen()),
        );
      } else {
        // =========================
        // ✅ 新規登録(Auth)
        // =========================
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = credential.user;
        if (user == null) {
          throw Exception('ユーザー作成に失敗しました');
        }

        // =========================
        // ✅ Firestore に名前・連絡先・性別を保存
        // users/{uid}
        // =========================
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'name': name,
          'contact': contact,
          'gender': gender ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // =========================
        // ✅ 確認メール送信（認証完了までログイン不可にする）
        // =========================
        await user.sendEmailVerification();

        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '確認メールを送信しました。メール内のリンクから認証するとログインできます。',
            ),
            duration: Duration(seconds: 6),
          ),
        );
        setState(() => _isLogin = true);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'エラーが発生しました';

      if (e.code == 'user-not-found') {
        message = 'ユーザーが見つかりません';
      } else if (e.code == 'wrong-password') {
        message = 'パスワードが違います';
      } else if (e.code == 'email-already-in-use') {
        message = 'このメールアドレスはすでに登録されています';
      } else if (e.code == 'invalid-email') {
        message = 'メールアドレスの形式が正しくありません';
      } else if (e.code == 'weak-password') {
        message = 'パスワードが短すぎます（6文字以上推奨）';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 未認証時に確認メールを再送する（ログイン → 再送 → サインアウト）
  Future<void> _resendVerificationEmail(String email, String password) async {
    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('再送に失敗しました。')),
        );
        return;
      }
      await user.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('確認メールを再送しました。メールをご確認ください。'),
          duration: Duration(seconds: 5),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('再送に失敗しました: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('再送に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'ログイン' : '新規登録')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ 新規登録時のみ表示
            if (!_isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名前',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: '連絡先（電話番号など）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('性別', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                hint: const Text('選択してください'),
                items: _genderOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedGender = v),
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'パスワード',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isLogin ? 'ログイン' : '登録'),
              ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _isLogin = !_isLogin;
                      });
                    },
              child: Text(_isLogin
                  ? 'アカウントをお持ちでない方はこちら（新規登録）'
                  : 'すでにアカウントをお持ちの方はこちら（ログイン）'),
            ),
          ],
        ),
      ),
    );
  }
}
