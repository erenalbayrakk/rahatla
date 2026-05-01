import 'package:flutter/widgets.dart';

import '../../features/auth/domain/app_user.dart';
import '../locale/locale_text.dart';

/// API `UserRole` değerleriyle uyumlu hesap türü (kullanıcıya gösterim).
enum UserAccountKind {
  /// `normal_user` — destek alan / sohbet eden üye
  helpSeeker,

  /// `listener_applicant` — dinleyen başvurusu yapmış
  listenerApplicant,

  /// `approved_listener` — onaylı dinleyen
  approvedListener,

  /// `admin`
  admin,
}

UserAccountKind userAccountKindFromApiRole(String role) {
  switch (role) {
    case 'normal_user':
      return UserAccountKind.helpSeeker;
    case 'listener_applicant':
      return UserAccountKind.listenerApplicant;
    case 'approved_listener':
      return UserAccountKind.approvedListener;
    case 'admin':
      return UserAccountKind.admin;
    default:
      return UserAccountKind.helpSeeker;
  }
}

extension UserAccountKindLabels on UserAccountKind {
  /// Profil kartında ana etiket
  String get title => switch (this) {
    UserAccountKind.helpSeeker => 'Yardım isteyen',
    UserAccountKind.listenerApplicant => 'Yardım eden · başvuru',
    UserAccountKind.approvedListener => 'Onaylı yardım eden',
    UserAccountKind.admin => 'Yönetim',
  };

  String titleL10n(BuildContext context) => switch (this) {
    UserAccountKind.helpSeeker =>
      trEn(context, 'Yardım isteyen', 'Help seeker'),
    UserAccountKind.listenerApplicant =>
      trEn(context, 'Yardım eden · başvuru', 'Helper · application'),
    UserAccountKind.approvedListener =>
      trEn(context, 'Onaylı yardım eden', 'Verified helper'),
    UserAccountKind.admin => trEn(context, 'Yönetim', 'Admin'),
  };

  String get description => switch (this) {
    UserAccountKind.helpSeeker =>
      'Destek ve güvenli sohbet için standart hesap.',
    UserAccountKind.listenerApplicant =>
      'Dinleyen olmak için başvurdun; onay sonrası yardım eden olarak listelenirsin.',
    UserAccountKind.approvedListener =>
      'Başvurun onaylandı; kullanıcılar seni dinleyen olarak seçebilir.',
    UserAccountKind.admin => 'Yönetim ve moderasyon yetkileri.',
  };

  String descriptionL10n(BuildContext context) => switch (this) {
    UserAccountKind.helpSeeker => trEn(
        context,
        'Destek ve güvenli sohbet için standart hesap.',
        'Standard account for support and safe conversation.',
      ),
    UserAccountKind.listenerApplicant => trEn(
        context,
        'Dinleyen olmak için başvurdun; onay sonrası yardım eden olarak listelenirsin.',
        'You applied to be a listener; after approval you are listed as a helper.',
      ),
    UserAccountKind.approvedListener => trEn(
        context,
        'Başvurun onaylandı; kullanıcılar seni dinleyen olarak seçebilir.',
        'Your application was approved; users can choose you as a listener.',
      ),
    UserAccountKind.admin => trEn(
        context,
        'Yönetim ve moderasyon yetkileri.',
        'Administration and moderation permissions.',
      ),
  };
}

extension AppUserAccountLabels on AppUser {
  UserAccountKind get accountKind => userAccountKindFromApiRole(role);

  String get emailVerificationLabel =>
      isVerified ? 'E-posta doğrulandı' : 'E-posta henüz doğrulanmadı';

  String emailVerificationLabelL10n(BuildContext context) => isVerified
      ? trEn(context, 'E-posta doğrulandı', 'Email verified')
      : trEn(context, 'E-posta henüz doğrulanmadı', 'Email not verified yet');
}
