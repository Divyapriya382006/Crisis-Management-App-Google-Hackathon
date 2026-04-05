// lib/shared/models/user_model.dart

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'user' | 'admin' | 'hospital' | 'rescuer' | 'hospitality'
  final String? photoUrl;
  final String? phone;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    role: json['role'],
    photoUrl: json['photo_url'],
    phone: json['phone'],
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'email': email,
    'role': role, 'photo_url': photoUrl, 'phone': phone,
  };
}

// lib/shared/models/notification_model.dart
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;       // 'alert' | 'warning' | 'info' | 'critical'
  final String source;
  final DateTime timestamp;
  final bool isRead;
  final String? actionUrl;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.source,
    required this.timestamp,
    this.isRead = false,
    this.actionUrl,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
    id: json['id'],
    title: json['title'],
    body: json['body'],
    type: json['type'],
    source: json['source'],
    timestamp: DateTime.parse(json['timestamp']),
    isRead: json['is_read'] ?? false,
    actionUrl: json['action_url'],
  );
}

// lib/shared/models/emergency_request_model.dart
class EmergencyRequestModel {
  final String id;
  final String userId;
  final String type;         // 'food' | 'water' | 'electricity' | 'boat' | 'helicopter'
  final String priority;     // 'critical' | 'high' | 'medium' | 'low'
  final String status;       // 'pending' | 'accepted' | 'in_progress' | 'resolved'
  final double latitude;
  final double longitude;
  final String? description;
  final String? contactNumber;
  final DateTime createdAt;

  const EmergencyRequestModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.priority,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.description,
    this.contactNumber,
    required this.createdAt,
  });

  factory EmergencyRequestModel.fromJson(Map<String, dynamic> json) => EmergencyRequestModel(
    id: json['id'],
    userId: json['user_id'],
    type: json['type'],
    priority: json['priority'],
    status: json['status'],
    latitude: json['latitude'].toDouble(),
    longitude: json['longitude'].toDouble(),
    description: json['description'],
    contactNumber: json['contact_number'],
    createdAt: DateTime.parse(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'latitude': latitude,
    'longitude': longitude,
    'description': description,
    'contact_number': contactNumber,
  };
}

// lib/shared/models/stats_model.dart
class WeatherStats {
  final double temperature;
  final double humidity;
  final String condition;
  final double windSpeed;
  final String windDirection;
  final DateTime updatedAt;

  const WeatherStats({
    required this.temperature,
    required this.humidity,
    required this.condition,
    required this.windSpeed,
    required this.windDirection,
    required this.updatedAt,
  });

  factory WeatherStats.fromJson(Map<String, dynamic> json) => WeatherStats(
    temperature: json['temperature'].toDouble(),
    humidity: json['humidity'].toDouble(),
    condition: json['condition'],
    windSpeed: json['wind_speed'].toDouble(),
    windDirection: json['wind_direction'],
    updatedAt: DateTime.parse(json['updated_at']),
  );

  // Demo / mock data
  factory WeatherStats.mock() => WeatherStats(
    temperature: 32.4,
    humidity: 78.0,
    condition: 'Partly Cloudy',
    windSpeed: 14.5,
    windDirection: 'NE',
    updatedAt: DateTime.now(),
  );
}

class SeismicStats {
  final double magnitude;
  final String level;  // 'none' | 'low' | 'moderate' | 'high'
  final String region;
  final DateTime? lastActivity;

  const SeismicStats({
    required this.magnitude,
    required this.level,
    required this.region,
    this.lastActivity,
  });

  factory SeismicStats.mock() => SeismicStats(
    magnitude: 1.2,
    level: 'low',
    region: 'Bay of Bengal',
    lastActivity: DateTime.now().subtract(const Duration(hours: 3)),
  );
}

class MapMarkerModel {
  final String id;
  final String type;   // 'hospital' | 'shelter' | 'safe_building' | 'rescue'
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;
  final int? capacity;
  final bool isOpen;

  const MapMarkerModel({
    required this.id,
    required this.type,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
    this.capacity,
    required this.isOpen,
  });

  factory MapMarkerModel.fromJson(Map<String, dynamic> json) => MapMarkerModel(
    id: json['id'],
    type: json['type'],
    name: json['name'],
    latitude: json['latitude'].toDouble(),
    longitude: json['longitude'].toDouble(),
    address: json['address'],
    phone: json['phone'],
    capacity: json['capacity'],
    isOpen: json['is_open'] ?? true,
  );
}
