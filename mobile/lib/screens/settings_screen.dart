import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../models/notification_profile.dart';
import '../services/auth_service.dart';
import '../services/notification_profile_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _SettingsPanel {
  profile,
  notifications,
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _newPasswordConfirmController = TextEditingController();

  late Future<NotificationProfile> _notificationProfileFuture;
  bool _isSavingProfile = false;
  bool _isSavingNotifications = false;
  _SettingsPanel? _expandedPanel;
  bool _vocalHygieneEnabled = true;
  int _maxDailyNotifications = 2;
  List<String> _preferredTimes = const <String>['10:30', '15:30'];
  Set<String> _enabledTopics = NotificationProfile.defaultTopics.toSet();

  static const List<String> _timeOptions = <String>[
    '09:30',
    '10:30',
    '11:30',
    '14:00',
    '15:30',
    '17:00',
    '20:30',
  ];

  static const Map<String, String> _topicLabels = <String, String>{
    'hydration': 'Su tüketimi',
    'nutrition': 'Beslenme',
    'voice_usage': 'Ses kullanımı',
    'environmental_factors': 'Ortam koşulları',
    'irritants': 'Kafein ve duman',
    'voice_rest': 'Ses molası',
    'throat_clearing': 'Boğaz temizleme',
    'reflux_control': 'Reflü kontrolü',
  };

  @override
  void initState() {
    super.initState();
    _syncUser(AuthService.instance.currentUser);
    _notificationProfileFuture = _loadNotificationProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _newPasswordConfirmController.dispose();
    super.dispose();
  }

  void _syncUser(AppUser? user) {
    if (user == null) {
      return;
    }
    _firstNameController.text = user.firstName;
    _lastNameController.text = user.lastName;
    _emailController.text = user.email;
  }

  Future<NotificationProfile> _loadNotificationProfile() async {
    final profile = await NotificationProfileRepository.instance.fetchProfile();
    if (mounted) {
      _applyNotificationProfile(profile);
    }
    return profile;
  }

  void _applyNotificationProfile(NotificationProfile profile) {
    setState(() {
      _vocalHygieneEnabled = profile.vocalHygieneEnabled;
      _maxDailyNotifications = profile.maxDailyNotifications;
      _preferredTimes = _normalizeTimes(profile.preferredTimes);
      _enabledTopics = profile.enabledTopics.toSet();
    });
  }

  void _togglePanel(_SettingsPanel panel) {
    HapticFeedback.selectionClick();
    setState(() {
      _expandedPanel = _expandedPanel == panel ? null : panel;
    });
  }

  List<String> _normalizeTimes(List<String> times) {
    final next = times.isEmpty ? const <String>['10:30', '15:30'] : times;
    return List<String>.generate(
      _maxDailyNotifications,
      (index) => next[index % next.length],
    );
  }

  Future<void> _saveProfile() async {
    final form = _profileFormKey.currentState;
    if (form == null || !form.validate() || _isSavingProfile) {
      return;
    }

    setState(() {
      _isSavingProfile = true;
    });

    try {
      await AuthService.instance.updateCurrentUserProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _newPasswordConfirmController.clear();
      _showMessage('Profil bilgileri güncellendi.', success: true);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
        });
      }
    }
  }

  Future<void> _saveNotifications() async {
    if (_isSavingNotifications) {
      return;
    }

    setState(() {
      _isSavingNotifications = true;
    });

    try {
      final profile =
          await NotificationProfileRepository.instance.updateProfile(
        vocalHygieneEnabled: _vocalHygieneEnabled,
        maxDailyNotifications: _maxDailyNotifications,
        preferredTimes: _preferredTimes.take(_maxDailyNotifications).toList(),
        enabledTopics: _enabledTopics.toList(),
      );
      _applyNotificationProfile(profile);
      _showMessage('Bildirim tercihleri güncellendi.', success: true);
    } catch (_) {
      _showMessage('Bildirim tercihleri güncellenirken sorun oluştu.');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingNotifications = false;
        });
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppTheme.card,
          title: const Text(
            'Çıkış Yap',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          content: const Text(
            'Hesabından çıkış yapmak istediğine emin misin?',
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: AppTheme.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
              ),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7A1B1B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Çıkış Yap'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true || !mounted) {
      return;
    }

    await AuthService.instance.signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        content: Text(
          message,
          style: TextStyle(
            color: success ? const Color(0xFF1F7A45) : const Color(0xFFB42318),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String? _validateRequired(String? value, String fieldLabel) {
    if ((value ?? '').trim().isEmpty) {
      return '$fieldLabel alanı boş bırakılamaz.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'E-posta alanı zorunludur.';
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.length < 8) {
      return 'Yeni şifre en az 8 karakter olmalıdır.';
    }
    if (_currentPasswordController.text.trim().isEmpty) {
      return 'Mevcut şifreyi girin.';
    }
    return null;
  }

  String? _validatePasswordConfirm(String? value) {
    final text = (value ?? '').trim();
    if (_newPasswordController.text.trim().isEmpty && text.isEmpty) {
      return null;
    }
    if (text != _newPasswordController.text.trim()) {
      return 'Yeni şifreler eşleşmiyor.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
                labelStyle: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                helperStyle: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
        ),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: AppTheme.surface,
          ),
          child: Column(
            children: [
              const AppTopHeader.withBack(
                title: 'Ayarlar',
                showDivider: true,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  children: [
                    _SettingsSection(
                      title: 'Profilim',
                      subtitle: 'Ad, e-posta ve şifre bilgilerini güncelle.',
                      icon: Icons.person_rounded,
                      isExpanded: _expandedPanel == _SettingsPanel.profile,
                      onTap: () => _togglePanel(_SettingsPanel.profile),
                      child: _buildProfileForm(),
                    ),
                    const SizedBox(height: 14),
                    FutureBuilder<NotificationProfile>(
                      future: _notificationProfileFuture,
                      builder: (context, snapshot) {
                        final isLoading =
                            snapshot.connectionState != ConnectionState.done;
                        return _SettingsSection(
                          title: 'Bildirimlerim',
                          subtitle:
                              'Vokal hijyen hatırlatmalarını ve saatlerini yönet.',
                          icon: Icons.notifications_rounded,
                          isExpanded:
                              _expandedPanel == _SettingsPanel.notifications,
                          onTap: () =>
                              _togglePanel(_SettingsPanel.notifications),
                          child: isLoading
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                )
                              : _buildNotificationForm(snapshot.data),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _SettingsActionSection(
                      title: 'Çıkış Yap',
                      subtitle: 'Bu cihazdaki oturumunu güvenli şekilde kapat.',
                      icon: Icons.logout_rounded,
                      onTap: _confirmSignOut,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileForm() {
    return Form(
      key: _profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _firstNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Ad'),
            validator: (value) => _validateRequired(value, 'Ad'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _lastNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Soyad'),
            validator: (value) => _validateRequired(value, 'Soyad'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'E-posta'),
            validator: _validateEmail,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _currentPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Mevcut şifre',
              helperText: 'Şifre değiştirmeyeceksen boş bırak.',
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Yeni şifre'),
            validator: _validateNewPassword,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _newPasswordConfirmController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Yeni şifre tekrar'),
            validator: _validatePasswordConfirm,
            onFieldSubmitted: (_) => _saveProfile(),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _isSavingProfile ? null : _saveProfile,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.textPrimary,
              side: const BorderSide(color: AppTheme.cardBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child:
                Text(_isSavingProfile ? 'Kaydediliyor...' : 'Profili Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationForm(NotificationProfile? profile) {
    final activeItems = profile?.activePlan?.items ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _vocalHygieneEnabled,
          title: const Text('Vokal hijyen bildirimleri'),
          subtitle: const Text(
            'Cevaplarına göre kişisel hatırlatmalar al.',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTheme.homeAccent;
            }
            return AppTheme.textMuted;
          }),
          trackColor: const WidgetStatePropertyAll(Colors.white),
          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTheme.homeAccent;
            }
            return AppTheme.cardBorder;
          }),
          onChanged: (value) {
            setState(() {
              _vocalHygieneEnabled = value;
            });
          },
        ),
        const SizedBox(height: 6),
        const Text(
          'Günlük bildirim sayısı',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [1, 2, 3].map((count) {
            final selected = _maxDailyNotifications == count;
            return ChoiceChip(
              label: Text('$count'),
              selected: selected,
              backgroundColor: Colors.white,
              selectedColor: Colors.white,
              checkmarkColor: AppTheme.homeAccent,
              side: BorderSide(
                color: selected ? AppTheme.homeAccent : AppTheme.cardBorder,
                width: selected ? 1.4 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              labelStyle: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) {
                setState(() {
                  _maxDailyNotifications = count;
                  _preferredTimes = _normalizeTimes(_preferredTimes);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        ...List<Widget>.generate(_maxDailyNotifications, (index) {
          final value = _preferredTimes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              initialValue:
                  _timeOptions.contains(value) ? value : _timeOptions.first,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
              decoration: InputDecoration(
                labelText: '${index + 1}. bildirim saati',
                filled: true,
                fillColor: Colors.white,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: AppTheme.homeAccent,
                    width: 1.4,
                  ),
                ),
              ),
              items: _timeOptions
                  .map(
                    (time) => DropdownMenuItem<String>(
                      value: time,
                      child: Text(time),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  final times = [..._preferredTimes];
                  times[index] = value;
                  _preferredTimes = times;
                });
              },
            ),
          );
        }),
        const SizedBox(height: 4),
        const Text(
          'Bildirim konuları',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: NotificationProfile.defaultTopics.map((topic) {
            final selected = _enabledTopics.contains(topic);
            return FilterChip(
              label: Text(_topicLabels[topic] ?? topic),
              selected: selected,
              backgroundColor: Colors.white,
              selectedColor: Colors.white,
              checkmarkColor: AppTheme.homeAccent,
              side: BorderSide(
                color: selected ? AppTheme.homeAccent : AppTheme.cardBorder,
                width: selected ? 1.4 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              labelStyle: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _enabledTopics.add(topic);
                  } else {
                    _enabledTopics.remove(topic);
                  }
                });
              },
            );
          }).toList(),
        ),
        if (activeItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Aktif plan',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...activeItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${item.time} - ${item.title}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _isSavingNotifications ? null : _saveNotifications,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.textPrimary,
            side: const BorderSide(color: AppTheme.cardBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(
            _isSavingNotifications ? 'Kaydediliyor...' : 'Bildirimleri Kaydet',
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isExpanded,
    required this.onTap,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isExpanded
              ? AppTheme.homeAccent.withValues(alpha: 0.24)
              : AppTheme.cardBorder,
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.homeIconBackground,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          icon,
                          color: AppTheme.homeAccent,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: isExpanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 14),
                            child,
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsActionSection extends StatelessWidget {
  const _SettingsActionSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A1B1B).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: const Color(0xFF7A1B1B),
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
