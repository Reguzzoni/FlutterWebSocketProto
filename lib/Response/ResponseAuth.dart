class ResponseAuth {
  String access_token;

  ResponseAuth({
    required this.access_token,
  });

  factory ResponseAuth.fromJson(Map<String, dynamic> json) => ResponseAuth(
    access_token: json["access_token"],
  );
}