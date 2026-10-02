import 'package:PiliPlus/services/douyin/douyin_cookie_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';

class DouyinLoginPage extends StatefulWidget {
  const DouyinLoginPage({super.key});
  @override State<DouyinLoginPage> createState() => _DouyinLoginPageState();
}

class _DouyinLoginPageState extends State<DouyinLoginPage> {
  final _ctrl = TextEditingController(); bool _loading = false; String? _error, _userName;

  @override void initState() { super.initState(); _check(); }

  Future<void> _check() async {
    await DouyinCookieService.init();
    if (DouyinCookieService.isLoggedIn) setState(() => _userName = DouyinCookieService.userInfo?['nickname'] as String? ?? '已登录');
  }

  Future<void> _login() async {
    final c = _ctrl.text.trim(); if (c.isEmpty) { setState(() => _error = '请输入 Cookie'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await DouyinCookieService.saveCookie(c);
      await DouyinCookieService.saveUserInfo({'nickname': '抖音用户', 'uid': 'unknown'});
      setState(() { _userName = '抖音用户'; _loading = false; }); Get.back(result: true);
    } catch (e) { setState(() { _error = '登录失败: $e'; _loading = false; }); }
  }

  @override Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(appBar: AppBar(title: const Text('抖音登录')), body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_userName != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        const Icon(Icons.check_circle, color: Colors.green), const SizedBox(width: 12),
        Expanded(child: Text('已登录: $_userName', style: t.textTheme.titleMedium)),
        TextButton(onPressed: () async { await DouyinCookieService.logout(); setState(() { _userName = null; _ctrl.clear(); }); }, child: const Text('退出')),
      ]))),
      const SizedBox(height: 16),
      Text('Cookie 登录', style: t.textTheme.titleLarge), const SizedBox(height: 8),
      Text('在电脑浏览器登录 douyin.com → F12 → Network → 任意请求 → Headers → 复制 Cookie', style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 16),
      TextField(controller: _ctrl, maxLines: 6, decoration: InputDecoration(border: const OutlineInputBorder(), hintText: '粘贴 Cookie...', errorText: _error)),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: _loading ? null : _login, child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('登录'))),
    ])));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
}
