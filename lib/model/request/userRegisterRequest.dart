// To parse this JSON data, do
//
//     final userRegisterRequest = userRegisterRequestFromJson(jsonString);

import 'dart:convert';

UserRegisterRequest userRegisterRequestFromJson(String str) => UserRegisterRequest.fromJson(json.decode(str));

String userRegisterRequestToJson(UserRegisterRequest data) => json.encode(data.toJson());

// userRegisterRequest.dart

class UserRegisterRequest {
  final String username;
  final String email;
  final String passwords;

  UserRegisterRequest({
    required this.username,
    required this.email,
    required this.passwords,
  });

  // ฟังก์ชันนี้ใช้เพื่อแปลงข้อมูลเป็น JSON
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'passwords': passwords,
    };
  }

  // ฟังก์ชันนี้ใช้เพื่อแปลง JSON เป็น UserRegisterRequest
  static UserRegisterRequest fromJson(Map<String, dynamic> json) {
    return UserRegisterRequest(
      username: json['username'],
      email: json['email'],
      passwords: json['passwords'],
    );
  }
}
