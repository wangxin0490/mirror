class AccessSession {
  AccessSession({
    required this.accessToken,
    required this.expiresIn,
    required this.expiresAt,
    this.sessionTtlDays = 30,
  });

  final String accessToken;
  final int expiresIn;
  final int expiresAt;
  final int sessionTtlDays;

  factory AccessSession.fromJson(Map<String, dynamic> j) => AccessSession(
        accessToken: j['access_token'] as String? ?? '',
        expiresIn: j['expires_in'] as int? ?? 0,
        expiresAt: j['expires_at'] as int? ?? 0,
        sessionTtlDays: j['session_ttl_days'] as int? ?? 30,
      );
}

class SessionInfo {
  SessionInfo({
    required this.userId,
    required this.displayName,
    required this.handle,
    this.phone,
    this.expiresIn = 0,
    this.expiresAt = 0,
  });

  final int userId;
  final String displayName;
  final String handle;
  final String? phone;
  final int expiresIn;
  final int expiresAt;

  factory SessionInfo.fromJson(Map<String, dynamic> j) => SessionInfo(
        userId: j['user_id'] as int? ?? 0,
        displayName: j['display_name'] as String? ?? '',
        handle: j['handle'] as String? ?? '',
        phone: j['phone'] as String?,
        expiresIn: j['expires_in'] as int? ?? 0,
        expiresAt: j['expires_at'] as int? ?? 0,
      );
}

class DemoUser {
  DemoUser({
    required this.userId,
    required this.displayName,
    required this.handle,
    required this.homeUrl,
    required this.avatarLetter,
    required this.planCode,
  });

  final int userId;
  final String displayName;
  final String handle;
  final String homeUrl;
  final String avatarLetter;
  final String planCode;

  factory DemoUser.fromJson(Map<String, dynamic> j) => DemoUser(
        userId: j['user_id'] as int? ?? 0,
        displayName: j['display_name'] as String? ?? '',
        handle: j['handle'] as String? ?? '',
        homeUrl: j['home_url'] as String? ?? '',
        avatarLetter: j['avatar_letter'] as String? ?? '?',
        planCode: j['plan_code'] as String? ?? 'free',
      );

  String get planLabel => planCode == 'pro' ? 'PRO' : planCode.toUpperCase();
}

class SendSmsResult {
  SendSmsResult({required this.phone, this.devCode});

  final String phone;
  final String? devCode;

  factory SendSmsResult.fromJson(Map<String, dynamic> j) => SendSmsResult(
        phone: j['phone'] as String? ?? '',
        devCode: j['dev_code'] as String?,
      );
}

class PhoneLoginResult {
  PhoneLoginResult({
    required this.status,
    this.userId,
    this.displayName,
    this.handle,
    this.phone,
    this.registerToken,
    this.accessToken,
  });

  final String status;
  final int? userId;
  final String? displayName;
  final String? handle;
  final String? phone;
  final String? registerToken;
  final String? accessToken;

  bool get loggedIn => status == 'logged_in';
  bool get needsRegister => status == 'needs_register';

  factory PhoneLoginResult.fromJson(Map<String, dynamic> j) => PhoneLoginResult(
        status: j['status'] as String? ?? '',
        userId: j['user_id'] as int?,
        displayName: j['display_name'] as String?,
        handle: j['handle'] as String?,
        phone: j['phone'] as String?,
        registerToken: j['register_token'] as String?,
        accessToken: j['access_token'] as String?,
      );
}

class RegisterResult {
  RegisterResult({
    required this.userId,
    required this.displayName,
    required this.handle,
    required this.phone,
    this.accessToken,
  });

  final int userId;
  final String displayName;
  final String handle;
  final String phone;
  final String? accessToken;

  factory RegisterResult.fromJson(Map<String, dynamic> j) => RegisterResult(
        userId: j['user_id'] as int? ?? 0,
        displayName: j['display_name'] as String? ?? '',
        handle: j['handle'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        accessToken: j['access_token'] as String?,
      );
}
