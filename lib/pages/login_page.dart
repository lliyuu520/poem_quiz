import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/account_service.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';

/// 登录 / 注册页。两个模式共用一份表单，右上角切换。
///
/// 账户是纯可选功能：返回不登录照样离线使用。服务端对登录/注册限流
/// 2r/m，提交期间按钮禁用，错误直接展示服务端文案。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.account});

  final AccountService account;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _registering = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    try {
      if (_registering) {
        await widget.account.register(username: username, password: password);
        // 注册成功服务端不返回 token，自动登录一次（限流下由用户主动连点两次，
        // 第二次可能 429，给出明确提示）。
        await widget.account.login(username: username, password: password);
      } else {
        await widget.account.login(username: username, password: password);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_registering ? '注册成功，已登录' : '登录成功')),
      );
      Navigator.of(context).pop(true);
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateUsername(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入用户名';
    if (!RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(text)) {
      return '3~20 位字母、数字或下划线';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return '请输入密码';
    if (value.length < 8) return '密码至少 8 位';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: AdaptiveBuilder(
            builder: (context, size) => ContentFrame(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            icon: const Icon(
                              Icons.arrow_back,
                              size: 20,
                              color: AppColors.inkSoft,
                            ),
                            tooltip: '返回',
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _registering ? '注册账号' : '登录',
                            style: serif(20,
                                weight: FontWeight.w600, spacing: 3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.sealSoft,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.account_circle_outlined,
                            size: 34,
                            color: AppColors.seal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '拾 · 云同步',
                        textAlign: TextAlign.center,
                        style: serif(21,
                            weight: FontWeight.w700, spacing: 3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '登录后可在多台设备间同步答题进度。\n不登录也能照常离线使用。',
                        textAlign: TextAlign.center,
                        style: serif(13,
                            color: AppColors.inkSoft, height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      InkCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            TextFormField(
                              controller: _usernameController,
                              focusNode: _usernameFocus,
                              validator: _validateUsername,
                              autofocus: false,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9_]'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: '用户名',
                                hintText: '3~20 位字母、数字或下划线',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              validator: _validatePassword,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              enableSuggestions: false,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: '密码',
                                hintText: '至少 8 位',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(),
                              ),
                              onFieldSubmitted: (_) => _submit(),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 12),
                        InkCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          color: AppColors.sealSoft,
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.error_outline,
                                  size: 18, color: AppColors.seal),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: serif(13, color: AppColors.seal),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: _registering ? '注册并登录' : '登录',
                        icon: Icons.login,
                        onPressed: _submitting ? null : _submit,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            _registering ? '已有账号？' : '还没有账号？',
                            style: serif(13, color: AppColors.inkSoft),
                          ),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () => setState(() {
                                      _registering = !_registering;
                                      _error = null;
                                      _formKey.currentState?.reset();
                                    }),
                            child: Text(
                              _registering ? '去登录' : '注册一个',
                              style: const TextStyle(
                                color: AppColors.seal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
