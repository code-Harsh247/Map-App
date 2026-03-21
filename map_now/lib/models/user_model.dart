class UserModel {
  final String name;
  final String mobile;
  final String? token;

  UserModel({
    required this.name,
    required this.mobile,
    this.token,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mobile': mobile,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] ?? '',
      mobile: json['mobile'] ?? '',
      token: json['token'],
    );
  }
}
