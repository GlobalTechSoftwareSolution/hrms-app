class Project {
  final String id;
  final String title;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final String? assignedTo;
  final List<String> members;
  final String? name;
  final String? email;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? additionalInfo;

  Project({
    required this.id,
    required this.title,
    this.description,
    this.startDate,
    this.endDate,
    this.status,
    this.assignedTo,
    this.members = const [],
    this.name,
    this.email,
    this.createdAt,
    this.updatedAt,
    this.additionalInfo,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    // Extract known fields
    final knownFields = {
      'id',
      'title',
      'description',
      'start_date',
      'end_date',
      'status',
      'assigned_to',
      'members',
      'name',
      'email',
      'created_at',
      'updated_at',
    };

    // Collect additional fields
    final additionalInfo = <String, dynamic>{};
    json.forEach((key, value) {
      if (!knownFields.contains(key) && value != null) {
        additionalInfo[key] = value;
      }
    });

    return Project(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'],
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date']) : null,
      status: json['status'],
      assignedTo: json['assigned_to'],
      members: json['members'] != null
          ? List<String>.from(json['members'])
          : [],
      name: json['name'],
      email: json['email'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      additionalInfo: additionalInfo.isNotEmpty ? additionalInfo : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'id': id,
      'title': title,
      'description': description,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status,
      'assigned_to': assignedTo,
      'members': members,
      'name': name,
      'email': email,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };

    // Add additional info
    if (additionalInfo != null) {
      map.addAll(additionalInfo!);
    }

    return map;
  }
}
