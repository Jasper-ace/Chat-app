class User {
  final int id;
  final String name;
  final String email;
  final String userType;

  User({required this.id, required this.name, required this.email, required this.userType});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'] ?? json['first_name'] ?? '',
      email: json['email'],
      userType: json['userType'] ?? '',
    );
  }
}
