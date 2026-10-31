/// A signed-in demo identity shared by each supported sign-in method.
final class Session {
  const Session({required this.userId, required this.email});

  final String userId;
  final String email;
}
