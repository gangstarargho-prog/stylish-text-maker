import 'package:flutter/material.dart';
import 'engines.dart';

class CloudAccountScreen extends StatefulWidget {
  final AppController app;
  const CloudAccountScreen({super.key, required this.app});

  @override
  State<CloudAccountScreen> createState() => _CloudAccountScreenState();
}

class _CloudAccountScreenState extends State<CloudAccountScreen> {
  bool _isRegister = false;
  bool _obscure = true;
  bool _busy = false;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submitAuth() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (_isRegister && name.length < 2) {
      _showMsg('কমপক্ষে ২ অক্ষরের নাম দিন।');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _showMsg('সঠিক ইমেইল দিন।');
      return;
    }
    if (pass.length < 6) {
      _showMsg('পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে।');
      return;
    }

    setState(() => _busy = true);
    final err = _isRegister
        ? await widget.app.registerAccount(name, email, pass)
        : await widget.app.loginAccount(email, pass);

    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      _showMsg(err);
    } else {
      _passCtrl.clear();
      _showMsg(_isRegister
          ? 'অ্যাকাউন্ট তৈরি ও ক্লাউড সিঙ্ক চালু হয়েছে! ✅'
          : 'সফলভাবে লগইন ও ডেটা সিঙ্ক হয়েছে! ✅');
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _busy = true);
    final err = await widget.app.loginWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _showMsg(err);
    } else {
      _showMsg('Google দিয়ে সফলভাবে লগইন ও সিঙ্ক হয়েছে! ✅');
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final inputCtrl = TextEditingController();
    final isGoogle = widget.app.isGoogleUser;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('অ্যাকাউন্ট ডিলিট করবেন?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isGoogle
                  ? 'সতর্কতা: এতে আপনার অ্যাকাউন্ট ও ক্লাউড ডেটা স্থায়ীভাবে মুছে যাবে। নিশ্চিত করতে বক্সে DELETE লিখুন:'
                  : 'সতর্কতা: এতে আপনার অ্যাকাউন্ট ও ক্লাউড ডেটা স্থায়ীভাবে মুছে যাবে। নিশ্চিত করতে আপনার পাসওয়ার্ড দিন:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: inputCtrl,
              obscureText: !isGoogle,
              decoration: InputDecoration(
                labelText: isGoogle ? 'লিখুন: DELETE' : 'পাসওয়ার্ড',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('স্থায়ীভাবে ডিলিট'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      inputCtrl.dispose();
      return;
    }

    setState(() => _busy = true);
    final err = await widget.app.deleteAccount(
      password: isGoogle ? '' : inputCtrl.text,
      confirmText: isGoogle ? inputCtrl.text.trim() : '',
    );
    inputCtrl.dispose();
    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      _showMsg(err);
    } else {
      _showMsg('আপনার অ্যাকাউন্ট স্থায়ীভাবে ডিলিট হয়েছে।');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Sync & Account')),
      body: ListenableBuilder(
        listenable: widget.app,
        builder: (context, _) {
          if (widget.app.isLoggedIn) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            child: Text(
                              (widget.app.userName ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.app.userName ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.app.userEmail ?? '',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.cloud_done, size: 16, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.app.isGoogleUser
                                          ? 'Google Cloud Sync Active'
                                          : 'Cloud Sync Active',
                                      style: const TextStyle(color: Colors.green, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'লোকাল Favorites: ${widget.app.favorites.length}  •  History: ${widget.app.history.length}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    setState(() => _busy = true);
                                    final err = await widget.app.syncPush();
                                    if (!mounted) return;
                                    setState(() => _busy = false);
                                    _showMsg(err ?? 'সার্ভারে ব্যাকআপ সম্পন্ন হয়েছে! ☁️✅');
                                  },
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Backup Now (Upload to Server)'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    setState(() => _busy = true);
                                    final err = await widget.app.syncPull();
                                    if (!mounted) return;
                                    setState(() => _busy = false);
                                    _showMsg(err ?? 'সার্ভার থেকে ডেটা রিস্টোর হয়েছে! ☁️✅');
                                  },
                            icon: const Icon(Icons.cloud_download_outlined),
                            label: const Text('Restore from Cloud'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await widget.app.logoutAccount();
                            if (!mounted) return;
                            setState(() => _busy = false);
                            _showMsg('লগআউট সম্পন্ন হয়েছে।');
                          },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: _busy ? null : _confirmDeleteAccount,
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Delete Account Permanently'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                  elevation: 0,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      '☁️ লগইন সম্পূর্ণ ঐচ্ছিক। Google বা Email দিয়ে অ্যাকাউন্ট খুললে আপনার Favorites ও History ক্লাউড সার্ভারে সুরক্ষিত থাকবে।',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _busy ? null : _handleGoogleLogin,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('অথবা Email দিয়ে', style: TextStyle(fontSize: 12)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Login')),
                    ButtonSegment(value: true, label: Text('Create Account')),
                  ],
                  selected: {_isRegister},
                  onSelectionChanged: (s) => setState(() => _isRegister = s.first),
                ),
                const SizedBox(height: 16),
                if (_isRegister) ...[
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'আপনার নাম',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'ইমেইল (Email)',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'পাসওয়ার্ড (কমপক্ষে ৬ অক্ষর)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _busy ? null : _submitAuth,
                  icon: Icon(_isRegister ? Icons.person_add_alt : Icons.login),
                  label: Text(_isRegister ? 'Create Cloud Account' : 'Login & Sync'),
                ),
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class FeedbackScreen extends StatefulWidget {
  final AppController app;
  const FeedbackScreen({super.key, required this.app});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  late final TextEditingController _nameCtrl;
  final TextEditingController _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.app.userName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _msgCtrl.text.trim();
    if (msg.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('অনুগ্রহ করে অন্তত ৩ অক্ষরের মতামত লিখুন।')),
      );
      return;
    }
    setState(() => _sending = true);
    final err = await widget.app.sendFeedback(
      msg,
      guestName: _nameCtrl.text.trim().isEmpty ? 'Guest' : _nameCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      _msgCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('আপনার মতামত সফলভাবে পাঠানো হয়েছে! ধন্যবাদ ✅')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback & Suggestions')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'অ্যাপে নতুন কোনো ফিচার চাইলে বা কোনো সমস্যা পেলে আমাদের সরাসরি জানান:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'আপনার নাম (ঐচ্ছিক)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msgCtrl,
              maxLines: 6,
              minLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: 'আপনার মতামত বা নতুন ফিচারের আইডিয়া লিখুন...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send),
              label: Text(_sending ? 'পাঠানো হচ্ছে...' : 'Send Feedback'),
            ),
          ],
        ),
      ),
    );
  }
}
