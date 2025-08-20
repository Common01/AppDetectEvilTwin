class Hardware {
  final String equipmentCode;
  final String equipmentName;
  final String location;
  final String ieeeStandard;
  final String bssid;   // เพิ่ม
  final String essid;   // เพิ่ม

  Hardware({
    required this.equipmentCode,
    required this.equipmentName,
    required this.location,
    required this.ieeeStandard,
    required this.bssid,
    required this.essid,
  });

  factory Hardware.fromJson(Map<String, dynamic> json) {
    return Hardware(
      equipmentCode: json['equipment_code'] ?? '',
      equipmentName: json['equipment_name'] ?? '',
      location: json['location'] ?? '',
      ieeeStandard: json['ieee_standard'] ?? '',
      bssid: json['bssid'] ?? '',
      essid: json['essid'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'equipment_code': equipmentCode,
    'equipment_name': equipmentName,
    'location': location,
    'ieee_standard': ieeeStandard,
    'bssid': bssid,
    'essid': essid,
  };
}
