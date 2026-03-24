import 'package:equatable/equatable.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({required this.status, this.token});

  final AuthStatus status;
  final String? token;

  AuthState copyWith({AuthStatus? status, String? token}) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
    );
  }

  @override
  List<Object?> get props => [status, token];
}

