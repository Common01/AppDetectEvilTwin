class WifiHistoryRequest {
  final String bssid;
  final String essid;
  final String dateTime;
  final String email;
  final int uid;
  final String? classification;

  WifiHistoryRequest({
    required this.bssid,
    required this.essid,
    required this.dateTime,
    required this.email,
    required this.uid,
    this.classification,
  });

  Map<String, dynamic> toJson() => {
        'bssid': bssid,
        'essid': essid,
        'date_time': dateTime,
        'email': email,
        'uid': uid,
        'classification': classification,
      };
}
