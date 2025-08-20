import 'dart:convert';

WifiAccessPointData wifiAccessPointDataFromJson(String str) =>
    WifiAccessPointData.fromJson(json.decode(str));

String wifiAccessPointDataToJson(WifiAccessPointData data) =>
    json.encode(data.toJson());

class WifiAccessPointData {
  String bssid;
  String essid;
  String signals;
  String chanel;
  String frequency;
  String secue;

  // เพิ่ม 4 ตัวนี้ตามข้อมูล hardware
  String assetCode;
  String deviceName;
  String location;
  String standard;

  WifiAccessPointData({
    required this.bssid,
    required this.essid,
    required this.signals,
    required this.chanel,
    required this.frequency,
    required this.secue,
    required this.assetCode,
    required this.deviceName,
    required this.location,
    required this.standard,
  });

  factory WifiAccessPointData.fromJson(Map<String, dynamic> json) =>
      WifiAccessPointData(
        bssid: json["bssid"],
        essid: json["essid"],
        signals: json["signals"],
        chanel: json["chanel"],
        frequency: json["frequency"],
        secue: json["secue"],
        assetCode: json["assetCode"] ?? '',
        deviceName: json["deviceName"] ?? '',
        location: json["location"] ?? '',
        standard: json["standard"] ?? '',
      );

  Map<String, dynamic> toJson() => {
        "bssid": bssid,
        "essid": essid,
        "signals": signals,
        "chanel": chanel,
        "frequency": frequency,
        "secue": secue,
        "assetCode": assetCode,
        "deviceName": deviceName,
        "location": location,
        "standard": standard,
      };
}
