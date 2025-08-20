import 'dart:convert';

UserLoginResponse loginResponseFromJson(String str) => UserLoginResponse.fromJson(json.decode(str));
String loginResponseToJson(UserLoginResponse data) => json.encode(data.toJson());

class UserLoginResponse {
  bool success;
  String message;
  User user;

  UserLoginResponse({
    required this.success,
    required this.message,
    required this.user,
  });

  factory UserLoginResponse.fromJson(Map<String, dynamic> json) => UserLoginResponse(
        success: json["success"] ?? true,
        message: json["message"],
        user: User.fromJson(json["user"]),
      );

  Map<String, dynamic> toJson() => {
        "success": success,
        "message": message,
        "user": user.toJson(),
      };
}

class User {
  int uid;
  String username;
  String email;
  String? descriptions;
  String? image;
  String roles;

  User({
    required this.uid,
    required this.username,
    required this.email,
    this.descriptions,
    this.image,
    required this.roles,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        uid: json["uid"],
        username: json["username"],
        email: json["email"],
        descriptions: json["descriptions"],
        image: json["image"],
        roles: json["roles"],
      );

  Map<String, dynamic> toJson() => {
        "uid": uid,
        "username": username,
        "email": email,
        "descriptions": descriptions,
        "image": image,
        "roles": roles,
      };
}
