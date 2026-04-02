
// ── User model ───────────────────────────────────────────────────────────────

class User {
  final int? id;
  final String email;
  final String name;
  final String role;
  final String createdAt;

  const User({
    this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory User.fromMap(Map<String, dynamic> m) => User(
    id: m['id'] as int?,
    email: m['email'] as String,
    name: m['name'] as String,
    role: m['role'] as String,
    createdAt: m['created_at'] as String,
  );
}