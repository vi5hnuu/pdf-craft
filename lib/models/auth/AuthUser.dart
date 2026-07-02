/// Public profile of the authenticated account, as returned by the auth service.
class AuthUser {
  final String id;
  final String accountType; // USER | GUEST
  final String authProvider; // LOCAL | GOOGLE | GUEST
  final String? email;
  final String? username;
  final String? firstName;
  final String? lastName;
  final bool enabled;

  const AuthUser({
    required this.id,
    required this.accountType,
    required this.authProvider,
    this.email,
    this.username,
    this.firstName,
    this.lastName,
    required this.enabled,
  });

  bool get isGuest => accountType == 'GUEST';

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        accountType: json['accountType'] as String? ?? 'USER',
        authProvider: json['authProvider'] as String? ?? 'LOCAL',
        email: json['email'] as String?,
        username: json['username'] as String?,
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        enabled: json['enabled'] as bool? ?? false,
      );
}
