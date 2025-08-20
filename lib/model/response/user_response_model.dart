class UserResponseModel {
  final int uid;
  final String username;
  final String email;
  final String roles;

  UserResponseModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.roles,
  });

  factory UserResponseModel.fromJson(Map<String, dynamic> json) {
    return UserResponseModel(
      uid: json['uid'],
      username: json['username'],
      email: json['email'],
      roles: json['roles'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'roles': roles,
    };
  }
}
