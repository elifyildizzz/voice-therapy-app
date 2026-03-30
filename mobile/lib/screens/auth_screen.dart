import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

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
        duration: const Duration(milliseconds: 700),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF1F7A45),
            fontWeight: FontWeight.w600,
          ),
        ),
        margin: const EdgeInsets.only(left: 80, right: 16, bottom: 16),
      ),
    );
  }

  void _showErrorMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0xFFB42318),
            fontWeight: FontWeight.w600,
          ),
        ),
        margin: const EdgeInsets.only(left: 80, right: 16, bottom: 16),
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
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Voice Therapy App',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isLoginMode
                                ? 'E-posta ve şifrenizle giriş yapın.'
                                : 'Hesabınızı oluşturarak uygulamayı kişisel geçmişinizle kullanın.',
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: Color(0xFF5F6E84),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: _ModeButton(
                                  label: 'Giriş Yap',
                                  isSelected: _isLoginMode,
                                  onTap: () {
                                    setState(() {
                                      _isLoginMode = true;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ModeButton(
                                  label: 'Kayıt Ol',
                                  isSelected: !_isLoginMode,
                                  onTap: () {
                                    setState(() {
                                      _isLoginMode = false;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _isLoginMode
                                ? _LoginForm(
                                    key: const ValueKey<String>('login'),
                                    formKey: _loginFormKey,
                                    emailController: _loginEmailController,
                                    passwordController:
                                        _loginPasswordController,
                                    isSubmitting: _isSubmitting,
                                    validateEmail: _validateEmail,
                                    validatePassword: _validatePassword,
                                    onSubmit: _submitLogin,
                                  )
                                : _RegisterForm(
                                    key: const ValueKey<String>('register'),
                                    formKey: _registerFormKey,
                                    emailController: _registerEmailController,
                                    passwordController:
                                        _registerPasswordController,
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
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: validateEmail,
          ),
          const SizedBox(height: 14),
          _AuthField(
            controller: passwordController,
            label: 'Şifre',
            obscureText: true,
            textInputAction: TextInputAction.done,
            validator: validatePassword,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: isSubmitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.darkBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
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
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: validateEmail,
          ),
          const SizedBox(height: 14),
          _AuthField(
            controller: passwordController,
            label: 'Şifre',
            obscureText: true,
            textInputAction: TextInputAction.next,
            validator: validatePassword,
          ),
          const SizedBox(height: 14),
          _AuthField(
            controller: passwordAgainController,
            label: 'Şifre Tekrar',
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
            onPressed: isSubmitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.darkBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              isSubmitting ? 'Kayıt oluşturuluyor...' : 'Kayıt Ol',
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFC62828)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.darkBlue),
        ),
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
      color: isSelected ? AppTheme.darkBlue : const Color(0xFFF2F4F7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF4B5B6C),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
