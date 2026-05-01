// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AppUser {
  String get id => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get role => throw _privateConstructorUsedError;
  bool get isVerified => throw _privateConstructorUsedError;

  /// API `Gender` enum string veya null: female, male, non_binary, prefer_not_to_say
  String? get gender => throw _privateConstructorUsedError;

  /// API `SupportCategory` veya null (profilde ruh hali).
  String? get moodCategory => throw _privateConstructorUsedError;

  /// İsteğe bağlı profil avatarı (S3).
  String? get avatarUrl => throw _privateConstructorUsedError;

  /// Doğrulama selfie'si; `avatarUrl` ile ayrı (S3 `verify_selfie_url`).
  String? get verifySelfieUrl => throw _privateConstructorUsedError;

  /// Diğer kullanıcılara gerçek ad yerine anonim göster.
  bool get preferAnonymous => throw _privateConstructorUsedError;

  /// Dinleyen keşfet listesi / aramada görünsün mü (`visible_in_discover`).
  bool get visibleInDiscover => throw _privateConstructorUsedError;

  /// Profilde ek fotoğraflar (S3 URL listesi, `profile_image_urls`).
  List<String> get profileImageUrls => throw _privateConstructorUsedError;

  /// Dinleyen için: `available` | `automatic` | `busy` (API snake_case).
  String? get listenerAvailabilityMode => throw _privateConstructorUsedError;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppUserCopyWith<AppUser> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppUserCopyWith<$Res> {
  factory $AppUserCopyWith(AppUser value, $Res Function(AppUser) then) =
      _$AppUserCopyWithImpl<$Res, AppUser>;
  @useResult
  $Res call({
    String id,
    String email,
    String role,
    bool isVerified,
    String? gender,
    String? moodCategory,
    String? avatarUrl,
    String? verifySelfieUrl,
    bool preferAnonymous,
    bool visibleInDiscover,
    List<String> profileImageUrls,
    String? listenerAvailabilityMode,
  });
}

/// @nodoc
class _$AppUserCopyWithImpl<$Res, $Val extends AppUser>
    implements $AppUserCopyWith<$Res> {
  _$AppUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? role = null,
    Object? isVerified = null,
    Object? gender = freezed,
    Object? moodCategory = freezed,
    Object? avatarUrl = freezed,
    Object? verifySelfieUrl = freezed,
    Object? preferAnonymous = null,
    Object? visibleInDiscover = null,
    Object? profileImageUrls = null,
    Object? listenerAvailabilityMode = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as String,
            isVerified: null == isVerified
                ? _value.isVerified
                : isVerified // ignore: cast_nullable_to_non_nullable
                      as bool,
            gender: freezed == gender
                ? _value.gender
                : gender // ignore: cast_nullable_to_non_nullable
                      as String?,
            moodCategory: freezed == moodCategory
                ? _value.moodCategory
                : moodCategory // ignore: cast_nullable_to_non_nullable
                      as String?,
            avatarUrl: freezed == avatarUrl
                ? _value.avatarUrl
                : avatarUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            verifySelfieUrl: freezed == verifySelfieUrl
                ? _value.verifySelfieUrl
                : verifySelfieUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            preferAnonymous: null == preferAnonymous
                ? _value.preferAnonymous
                : preferAnonymous // ignore: cast_nullable_to_non_nullable
                      as bool,
            visibleInDiscover: null == visibleInDiscover
                ? _value.visibleInDiscover
                : visibleInDiscover // ignore: cast_nullable_to_non_nullable
                      as bool,
            profileImageUrls: null == profileImageUrls
                ? _value.profileImageUrls
                : profileImageUrls // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            listenerAvailabilityMode: freezed == listenerAvailabilityMode
                ? _value.listenerAvailabilityMode
                : listenerAvailabilityMode // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AppUserImplCopyWith<$Res> implements $AppUserCopyWith<$Res> {
  factory _$$AppUserImplCopyWith(
    _$AppUserImpl value,
    $Res Function(_$AppUserImpl) then,
  ) = __$$AppUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String email,
    String role,
    bool isVerified,
    String? gender,
    String? moodCategory,
    String? avatarUrl,
    String? verifySelfieUrl,
    bool preferAnonymous,
    bool visibleInDiscover,
    List<String> profileImageUrls,
    String? listenerAvailabilityMode,
  });
}

/// @nodoc
class __$$AppUserImplCopyWithImpl<$Res>
    extends _$AppUserCopyWithImpl<$Res, _$AppUserImpl>
    implements _$$AppUserImplCopyWith<$Res> {
  __$$AppUserImplCopyWithImpl(
    _$AppUserImpl _value,
    $Res Function(_$AppUserImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? role = null,
    Object? isVerified = null,
    Object? gender = freezed,
    Object? moodCategory = freezed,
    Object? avatarUrl = freezed,
    Object? verifySelfieUrl = freezed,
    Object? preferAnonymous = null,
    Object? visibleInDiscover = null,
    Object? profileImageUrls = null,
    Object? listenerAvailabilityMode = freezed,
  }) {
    return _then(
      _$AppUserImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as String,
        isVerified: null == isVerified
            ? _value.isVerified
            : isVerified // ignore: cast_nullable_to_non_nullable
                  as bool,
        gender: freezed == gender
            ? _value.gender
            : gender // ignore: cast_nullable_to_non_nullable
                  as String?,
        moodCategory: freezed == moodCategory
            ? _value.moodCategory
            : moodCategory // ignore: cast_nullable_to_non_nullable
                  as String?,
        avatarUrl: freezed == avatarUrl
            ? _value.avatarUrl
            : avatarUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        verifySelfieUrl: freezed == verifySelfieUrl
            ? _value.verifySelfieUrl
            : verifySelfieUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        preferAnonymous: null == preferAnonymous
            ? _value.preferAnonymous
            : preferAnonymous // ignore: cast_nullable_to_non_nullable
                  as bool,
        visibleInDiscover: null == visibleInDiscover
            ? _value.visibleInDiscover
            : visibleInDiscover // ignore: cast_nullable_to_non_nullable
                  as bool,
        profileImageUrls: null == profileImageUrls
            ? _value._profileImageUrls
            : profileImageUrls // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        listenerAvailabilityMode: freezed == listenerAvailabilityMode
            ? _value.listenerAvailabilityMode
            : listenerAvailabilityMode // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$AppUserImpl implements _AppUser {
  const _$AppUserImpl({
    required this.id,
    required this.email,
    required this.role,
    this.isVerified = false,
    this.gender,
    this.moodCategory,
    this.avatarUrl,
    this.verifySelfieUrl,
    this.preferAnonymous = false,
    this.visibleInDiscover = true,
    final List<String> profileImageUrls = const <String>[],
    this.listenerAvailabilityMode,
  }) : _profileImageUrls = profileImageUrls;

  @override
  final String id;
  @override
  final String email;
  @override
  final String role;
  @override
  @JsonKey()
  final bool isVerified;

  /// API `Gender` enum string veya null: female, male, non_binary, prefer_not_to_say
  @override
  final String? gender;

  /// API `SupportCategory` veya null (profilde ruh hali).
  @override
  final String? moodCategory;

  /// İsteğe bağlı profil avatarı (S3).
  @override
  final String? avatarUrl;

  /// Doğrulama selfie'si; `avatarUrl` ile ayrı (S3 `verify_selfie_url`).
  @override
  final String? verifySelfieUrl;

  /// Diğer kullanıcılara gerçek ad yerine anonim göster.
  @override
  @JsonKey()
  final bool preferAnonymous;

  /// Dinleyen keşfet listesi / aramada görünsün mü (`visible_in_discover`).
  @override
  @JsonKey()
  final bool visibleInDiscover;

  /// Profilde ek fotoğraflar (S3 URL listesi, `profile_image_urls`).
  final List<String> _profileImageUrls;

  /// Profilde ek fotoğraflar (S3 URL listesi, `profile_image_urls`).
  @override
  @JsonKey()
  List<String> get profileImageUrls {
    if (_profileImageUrls is EqualUnmodifiableListView)
      return _profileImageUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_profileImageUrls);
  }

  /// Dinleyen için: `available` | `automatic` | `busy` (API snake_case).
  @override
  final String? listenerAvailabilityMode;

  @override
  String toString() {
    return 'AppUser(id: $id, email: $email, role: $role, isVerified: $isVerified, gender: $gender, moodCategory: $moodCategory, avatarUrl: $avatarUrl, verifySelfieUrl: $verifySelfieUrl, preferAnonymous: $preferAnonymous, visibleInDiscover: $visibleInDiscover, profileImageUrls: $profileImageUrls, listenerAvailabilityMode: $listenerAvailabilityMode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.gender, gender) || other.gender == gender) &&
            (identical(other.moodCategory, moodCategory) ||
                other.moodCategory == moodCategory) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.verifySelfieUrl, verifySelfieUrl) ||
                other.verifySelfieUrl == verifySelfieUrl) &&
            (identical(other.preferAnonymous, preferAnonymous) ||
                other.preferAnonymous == preferAnonymous) &&
            (identical(other.visibleInDiscover, visibleInDiscover) ||
                other.visibleInDiscover == visibleInDiscover) &&
            const DeepCollectionEquality().equals(
              other._profileImageUrls,
              _profileImageUrls,
            ) &&
            (identical(
                  other.listenerAvailabilityMode,
                  listenerAvailabilityMode,
                ) ||
                other.listenerAvailabilityMode == listenerAvailabilityMode));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    email,
    role,
    isVerified,
    gender,
    moodCategory,
    avatarUrl,
    verifySelfieUrl,
    preferAnonymous,
    visibleInDiscover,
    const DeepCollectionEquality().hash(_profileImageUrls),
    listenerAvailabilityMode,
  );

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppUserImplCopyWith<_$AppUserImpl> get copyWith =>
      __$$AppUserImplCopyWithImpl<_$AppUserImpl>(this, _$identity);
}

abstract class _AppUser implements AppUser {
  const factory _AppUser({
    required final String id,
    required final String email,
    required final String role,
    final bool isVerified,
    final String? gender,
    final String? moodCategory,
    final String? avatarUrl,
    final String? verifySelfieUrl,
    final bool preferAnonymous,
    final bool visibleInDiscover,
    final List<String> profileImageUrls,
    final String? listenerAvailabilityMode,
  }) = _$AppUserImpl;

  @override
  String get id;
  @override
  String get email;
  @override
  String get role;
  @override
  bool get isVerified;

  /// API `Gender` enum string veya null: female, male, non_binary, prefer_not_to_say
  @override
  String? get gender;

  /// API `SupportCategory` veya null (profilde ruh hali).
  @override
  String? get moodCategory;

  /// İsteğe bağlı profil avatarı (S3).
  @override
  String? get avatarUrl;

  /// Doğrulama selfie'si; `avatarUrl` ile ayrı (S3 `verify_selfie_url`).
  @override
  String? get verifySelfieUrl;

  /// Diğer kullanıcılara gerçek ad yerine anonim göster.
  @override
  bool get preferAnonymous;

  /// Dinleyen keşfet listesi / aramada görünsün mü (`visible_in_discover`).
  @override
  bool get visibleInDiscover;

  /// Profilde ek fotoğraflar (S3 URL listesi, `profile_image_urls`).
  @override
  List<String> get profileImageUrls;

  /// Dinleyen için: `available` | `automatic` | `busy` (API snake_case).
  @override
  String? get listenerAvailabilityMode;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppUserImplCopyWith<_$AppUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
