/// Bangumi 登录页面 - 使用 OAuth 2.0 流程
import 'dart:convert';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BangumiLoginPage extends StatefulWidget {
  const BangumiLoginPage({super.key});
  @override
  State<BangumiLoginPage> createState() => _BangumiLoginPageState();
}

class _BangumiLoginPageState extends State<BangumiLoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  // Bangumi OAuth 配置
  static const _clientId = 'your_client_id'; // TODO: 从配置中读取
  static const _clientSecret = 'your_client_secret'; // TODO: 从配置中读取
  static const _redirectUri = 'pilinara://bangumi/callback';

  Future<void> _loginWithPassword() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      if (username.isEmpty || password.isEmpty) {
        setState(() => _error = '请输入用户名和密码');
        return;
      }

      // TODO: 实现真正的密码登录
      // 目前先使用用户名作为简单认证
      Pref.bangumiUsername = username;
      
      if (mounted) {
        Get.back(result: true);
      }
    } catch (e) {
      setState(() => _error = '登录失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithOAuth() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // TODO: 实现 OAuth 流程
      // 1. 生成 state 参数
      // 2. 构建授权 URL
      // 3. 使用 WebView 或外部浏览器登录
      // 4. 接收回调并交换 token
      
      final state = Utils.generateRandomString(32);
      final authUrl = Uri.https('bangumi.tv', '/oauth/authorize', {
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'response_type': 'code',
        'state': state,
      });

      // TODO: 打开 OAuth 页面
      print('[Bangumi] Auth URL: $authUrl');
      
      setState(() => _error = 'OAuth 登录功能待实现');
    } catch (e) {
      setState(() => _error = 'OAuth 登录失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录 Bangumi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '登录 Bangumi 以同步追番进度\n支持用户名密码登录和 OAuth 认证',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _loginWithPassword,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('密码登录'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _isLoading ? null : _loginWithOAuth,
              child: const Text('OAuth 登录'),
            ),
          ],
        ),
      ),
    );
  }
}
