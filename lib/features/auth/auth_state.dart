import 'models/user_profile.dart';

class AuthState {
  const AuthState({
    required this.initialized,
    required this.hasSeenIntro,
    required this.isLoggedIn,
    this.activeUser,
  });

  const AuthState.initial()
    : initialized = false,
      hasSeenIntro = false,
      isLoggedIn = false,
      activeUser = null;

  final bool initialized;
  final bool hasSeenIntro;
  final bool isLoggedIn;
  final UserProfile? activeUser;

  AuthState copyWith({
    bool? initialized,
    bool? hasSeenIntro,
    bool? isLoggedIn,
    UserProfile? activeUser,
  }) {
    return AuthState(
      initialized: initialized ?? this.initialized,
      hasSeenIntro: hasSeenIntro ?? this.hasSeenIntro,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      activeUser: activeUser ?? this.activeUser,
    );
  }
}
