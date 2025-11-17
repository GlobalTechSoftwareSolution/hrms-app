class Task {
  final int? id;
  final String? title;
  final String? description;
  final String? status; // pending, in_progress, completed
  final String? email;
  final String? emailId;
  final DateTime? createdAt;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? priority; // low, medium, high
  final double? score;

  Task({
    this.id,
    this.title,
    this.description,
    this.status,
    this.email,
    this.emailId,
    this.createdAt,
    this.dueDate,
    this.completedAt,
    this.priority,
    this.score,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String?,
      email: json['email'] as String?,
      emailId: json['email_id'] as String?,
      createdAt: _parseDate(json['created_at']),
      dueDate: _parseDate(json['due_date']),
      completedAt: _parseDate(json['completed_at']),
      priority: json['priority'] as String?,
      score: (json['score'] as num?)?.toDouble(),
    );
  }

  static DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is DateTime) return dateValue;
    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue.replaceFirst(' ', 'T'));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'status': status,
    'email': email,
    'email_id': emailId,
    'created_at': createdAt?.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'priority': priority,
    'score': score,
  };

  bool get isCompleted => status?.toLowerCase() == 'completed';
  bool get isPending => status?.toLowerCase() == 'pending';
  bool get isInProgress => status?.toLowerCase() == 'in_progress';
}
