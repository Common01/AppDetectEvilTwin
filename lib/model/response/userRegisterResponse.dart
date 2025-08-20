// userRegisterResponse.dart
import 'dart:convert';

UserRegisterResponse userRegisterResponseFromJson(String str) =>
    UserRegisterResponse.fromJson(json.decode(str));

class UserRegisterResponse {
  bool success;
  String message;
  User user;

  UserRegisterResponse({
    required this.success,
    required this.message,
    required this.user,
  });

  factory UserRegisterResponse.fromJson(Map<String, dynamic> json) =>
      UserRegisterResponse(
        success: json["success"],
        message: json["message"],
        user: User.fromJson(json["user"]),
      );
}

class User {
  String username;
  String email;

  User({
    required this.username,
    required this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        username: json["username"],
        email: json["email"],
      );
}
