class ResponseMatchAuth {
  String match_token;

  ResponseMatchAuth({
    required this.match_token,
  });

  factory ResponseMatchAuth.fromJson(Map<String, dynamic> json) => ResponseMatchAuth(
    match_token: json["match_token"],
  );
}