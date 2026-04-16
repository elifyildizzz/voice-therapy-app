import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

const Color _authButtonColor = Color(0xFF4C766A);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerPasswordAgainController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isLoginMode = true;
  bool _isSubmitting = false;

  void _switchMode(bool loginMode) {
    if (_isSubmitting || _isLoginMode == loginMode) {
      return;
    }
    setState(() {
      _isLoginMode = loginMode;
    });
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerPasswordAgainController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final form = _loginFormKey.currentState;
    if (form == null || !form.validate() || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AuthService.instance.signIn(
        email: _loginEmailController.text,
        password: _loginPasswordController.text,
      );
      _showSuccessMessage('Başarıyla giriş yaptınız.');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      _showErrorMessage(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitRegister() async {
    final form = _registerFormKey.currentState;
    if (form == null || !form.validate() || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AuthService.instance.register(
        email: _registerEmailController.text,
        password: _registerPasswordController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
      );
      _registerPasswordController.clear();
      _registerPasswordAgainController.clear();
      _loginEmailController.text = _registerEmailController.text.trim();
      _loginPasswordController.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoginMode = true;
      });

      _showSuccessMessage(
        'Kayıt başarıyla oluşturuldu. Şimdi giriş yapabilirsiniz.',
      );
    } on AuthException catch (error) {
      _showErrorMessage(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccessMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 900),
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF1F7A45),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _showErrorMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1500),
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0xFFB42318),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'E-posta alanı zorunludur.';
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(text)) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Şifre alanı zorunludur.';
    }
    if (text.length < 8) {
      return 'Şifre en az 8 karakter olmalıdır.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surface,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AuthIntro(),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppTheme.cardBorder),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ModeSwitcher(
                            isLoginMode: _isLoginMode,
                            onSelectLogin: () => _switchMode(true),
                            onSelectRegister: () => _switchMode(false),
                          ),
                          const SizedBox(height: 22),
                          Visibility(
                            visible: _isLoginMode,
                            maintainState: true,
                            child: _LoginForm(
                              key: const ValueKey<String>('login'),
                              formKey: _loginFormKey,
                              emailController: _loginEmailController,
                              passwordController: _loginPasswordController,
                              isSubmitting: _isSubmitting,
                              validateEmail: _validateEmail,
                              validatePassword: _validatePassword,
                              onSubmit: _submitLogin,
                            ),
                          ),
                          Visibility(
                            visible: !_isLoginMode,
                            maintainState: true,
                            child: _RegisterForm(
                              key: const ValueKey<String>('register'),
                              formKey: _registerFormKey,
                              emailController: _registerEmailController,
                              passwordController: _registerPasswordController,
                              passwordAgainController:
                                  _registerPasswordAgainController,
                              firstNameController: _firstNameController,
                              lastNameController: _lastNameController,
                              isSubmitting: _isSubmitting,
                              validateEmail: _validateEmail,
                              validatePassword: _validatePassword,
                              onSubmit: _submitRegister,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthIntro extends StatelessWidget {
  const _AuthIntro();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Akıllı Ses Terapisi',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({
    required this.isLoginMode,
    required this.onSelectLogin,
    required this.onSelectRegister,
  });

  final bool isLoginMode;
  final VoidCallback onSelectLogin;
  final VoidCallback onSelectRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.soft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: 'Giriş Yap',
              isSelected: isLoginMode,
              onTap: onSelectLogin,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeButton(
              label: 'Kayıt Ol',
              isSelected: !isLoginMode,
              onTap: onSelectRegister,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isSubmitting,
    required this.validateEmail,
    required this.validatePassword,
    required this.onSubmit,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isSubmitting;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthField(
            controller: emailController,
            label: 'E-posta',
            hintText: 'ornek@email.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: validateEmail,
          ),
          const SizedBox(height: 14),
          _AuthField(
            controller: passwordController,
            label: 'Şifre',
            hintText: '........',
            obscureText: true,
            textInputAction: TextInputAction.done,
            validator: validatePassword,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _authButtonColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: isSubmitting ? null : onSubmit,
            child: Text(isSubmitting ? 'Giriş yapılıyor...' : 'Giriş Yap'),
          ),
        ],
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordAgainController,
    required this.firstNameController,
    required this.lastNameController,
    required this.isSubmitting,
    required this.validateEmail,
    required this.validatePassword,
    required this.onSubmit,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController passwordAgainController;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final bool isSubmitting;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthField(
            controller: firstNameController,
            label: 'Ad',
            hintText: 'Adınızı girin',
            textInputAction: TextInputAction.next,
            validator: (value) {
              if ((value?.trim() ?? '').isEmpty) {
                return 'Ad alanı zorunludur.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _AuthField(
            controller: lastNameController,
            label: 'Soyad',
            hintText: 'Soyadınızı girin',
            textInputAction: TextInputAction.next,
            validator: (value) {
              if ((value?.trim() ?? '').isEmpty) {
                return 'Soyad alanı zorunludur.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _AuthField(
            controller: emailController,
            label: 'E-posta',
            hintText: 'ornek@email.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: validateEmail,
          ),
          const SizedBox(height: 14),
          _AuthField(
            controller: passwordController,
            label: 'Şifre',
            hintText: '........',
            obscureText: true,
            textInputAction: TextInputAction.next,
            validator: validatePassword,
          ),
          const SizedBox(height: 14),
          _AuthField(
            controller: passwordAgainController,
            label: 'Şifre Tekrar',
            hintText: '........',
            obscureText: true,
            textInputAction: TextInputAction.done,
            validator: (value) {
              final passwordError = validatePassword(value);
              if (passwordError != null) {
                return passwordError;
              }
              if ((value ?? '') != passwordController.text) {
                return 'Şifreler birbiriyle eşleşmiyor.';
              }
              return null;
            },
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _authButtonColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: isSubmitting ? null : onSubmit,
            child: Text(
              isSubmitting ? 'Kayıt oluşturuluyor...' : 'Kayıt Ol',
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthField extends StatefulWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.validator,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  late bool _isObscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _isObscured,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        suffixIcon: widget.obscureText
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _isObscured = !_isObscured;
                  });
                },
                icon: Icon(
                  _isObscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppTheme.textMuted,
                ),
              )
            : null,
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? _authButtonColor : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : _authButtonColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
