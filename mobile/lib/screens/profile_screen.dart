import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../models/notification_profile.dart';
import '../services/auth_service.dart';
import '../services/measurement_repository.dart';
import '../services/notification_profile_repository.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum _ProfilePanel {
  profile,
  notifications,
}

class _ProfileScreenState extends State<ProfileScreen> {
  final MeasurementRepository _measurementRepository =
      MeasurementRepository.instance;
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
  bool _isLoadingTodayRecordCount = true;
  _ProfilePanel? _expandedPanel;
  bool _vocalHygieneEnabled = true;
  int _maxDailyNotifications = 2;
  int _todayRecordCount = 0;
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
    _measurementRepository.changes.addListener(_handleMeasurementChange);
    _loadTodayRecordCount();
  }

  @override
  void dispose() {
    _measurementRepository.changes.removeListener(_handleMeasurementChange);
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

  List<String> _normalizeTimes(List<String> times) {
    final next = times.isEmpty ? const <String>['10:30', '15:30'] : times;
    return List<String>.generate(
      _maxDailyNotifications,
      (index) => next[index % next.length],
    );
  }

  void _handleMeasurementChange() {
    _loadTodayRecordCount();
  }

  Future<void> _loadTodayRecordCount() async {
    if (!_measurementRepository.hasLoadedCache) {
      if (mounted) {
        setState(() {
          _isLoadingTodayRecordCount = true;
        });
      }
    }

    try {
      final records = _measurementRepository.hasLoadedCache
          ? _measurementRepository.peekRecords()
          : await _measurementRepository.fetchRecords();
      final todayClientDate = _formatClientDate(DateTime.now());
      final todayCount = records
          .where((record) => record.clientDate == todayClientDate)
          .length;
      if (!mounted) {
        return;
      }
      setState(() {
        _todayRecordCount = todayCount;
        _isLoadingTodayRecordCount = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _todayRecordCount = 0;
        _isLoadingTodayRecordCount = false;
      });
    }
  }

  String _formatClientDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  void _togglePanel(_ProfilePanel panel) {
    HapticFeedback.selectionClick();
    setState(() {
      _expandedPanel = _expandedPanel == panel ? null : panel;
    });
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
    _syncUser(AuthService.instance.currentUser);
    final user = AuthService.instance.currentUser;
    final fullName =
        user == null ? 'Profil' : '${user.firstName} ${user.lastName}'.trim();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
                labelStyle: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                floatingLabelStyle: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                helperStyle: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _ProfileHeaderCard(
                fullName: fullName,
                todayRecordCount: _todayRecordCount,
                isLoadingTodayRecordCount: _isLoadingTodayRecordCount,
              ),
              const SizedBox(height: 18),
              _ExpandableCard(
                title: 'Profil Bilgileri',
                subtitle: 'Ad, e-posta ve diğer bilgilerini düzenle.',
                icon: Icons.person_outline_rounded,
                iconColor: AppTheme.homeAccent,
                iconBackgroundColor: AppTheme.homeIconBackground,
                isExpanded: _expandedPanel == _ProfilePanel.profile,
                onTap: () => _togglePanel(_ProfilePanel.profile),
                child: _buildProfileForm(),
              ),
              const SizedBox(height: 18),
              FutureBuilder<NotificationProfile>(
                future: _notificationProfileFuture,
                builder: (context, snapshot) {
                  final isLoading =
                      snapshot.connectionState != ConnectionState.done;
                  return _ExpandableCard(
                    title: 'Bildirimler',
                    subtitle:
                        'Vokal hijyen hatırlatmalarını ve saatlerini yönet.',
                    icon: Icons.notifications_none_rounded,
                    iconColor: AppTheme.homeAccent,
                    iconBackgroundColor: AppTheme.homeIconBackground,
                    isExpanded: _expandedPanel == _ProfilePanel.notifications,
                    onTap: () => _togglePanel(_ProfilePanel.notifications),
                    child: isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _buildNotificationForm(snapshot.data),
                  );
                },
              ),
              const SizedBox(height: 18),
              _ActionCard(
                title: 'Çıkış Yap',
                subtitle: 'Bu cihazdaki oturumunu güvenli şekilde kapat.',
                icon: Icons.logout_outlined,
                iconColor: const Color(0xFF9F3C31),
                iconBackgroundColor: const Color(0xFFF8EEEC),
                onTap: _confirmSignOut,
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
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w400,
            ),
            decoration: const InputDecoration(labelText: 'Ad'),
            validator: (value) => _validateRequired(value, 'Ad'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _lastNameController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w400,
            ),
            decoration: const InputDecoration(labelText: 'Soyad'),
            validator: (value) => _validateRequired(value, 'Soyad'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w400,
            ),
            decoration: const InputDecoration(labelText: 'E-posta'),
            validator: _validateEmail,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _currentPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w400,
            ),
            decoration: const InputDecoration(
              labelText: 'Mevcut şifre',
              helperText: 'Şifre değiştirmeyeceksen boş bırak.',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w400,
            ),
            decoration: const InputDecoration(labelText: 'Yeni şifre'),
            validator: _validateNewPassword,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _newPasswordConfirmController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w400,
            ),
            decoration: const InputDecoration(labelText: 'Yeni şifre tekrar'),
            validator: _validatePasswordConfirm,
            onFieldSubmitted: (_) => _saveProfile(),
          ),
          const SizedBox(height: 20),
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
            child: Text(
              _isSavingProfile ? 'Kaydediliyor...' : 'Profili Kaydet',
            ),
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
          title: const Text(
            'Vokal hijyen bildirimleri',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: const Text(
            'Cevaplarına göre kişisel hatırlatmalar al.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
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
                fontSize: 12,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppTheme.textPrimary,
              ),
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
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
                fontSize: 12,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          ...activeItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${item.time} - ${item.title}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w400,
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

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.fullName,
    required this.todayRecordCount,
    required this.isLoadingTodayRecordCount,
  });

  final String fullName;
  final int todayRecordCount;
  final bool isLoadingTodayRecordCount;

  @override
  Widget build(BuildContext context) {
    final segments = fullName.trim().split(RegExp(r'\s+'));
    final initials = segments.isEmpty
        ? 'P'
        : segments
            .take(2)
            .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
            .join();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.homeCard,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.homeIconBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFD4E0D4)),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.homeAccent,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.homeAccent,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Bugünkü aktivite özeti',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.light,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.homeIconBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD4E0D4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bugün',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.homeAccent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLoadingTodayRecordCount ? '...' : '$todayRecordCount kayit',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.homeAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableCard extends StatelessWidget {
  const _ExpandableCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.isExpanded,
    required this.onTap,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: iconBackgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          icon,
                          color: iconColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 24,
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
                          children: <Widget>[
                            const Divider(height: 1),
                            const SizedBox(height: 16),
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: iconBackgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
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
