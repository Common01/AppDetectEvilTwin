class UpdateUserRequest {
  final String roles;

  UpdateUserRequest({required this.roles});

  Map<String, dynamic> toJson() {
    return {
      'roles': roles,
    };
  }
}
