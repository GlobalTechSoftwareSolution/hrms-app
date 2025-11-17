class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final bool isRead;
  final NotificationType type;
  final String? ticketId;
  final String? actionUrl;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.data,
    required this.timestamp,
    this.isRead = false,
    required this.type,
    this.ticketId,
    this.actionUrl,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      imageUrl: json['image_url'],
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['is_read'] ?? false,
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${json['type']}',
        orElse: () => NotificationType.general,
      ),
      ticketId: json['ticket_id'],
      actionUrl: json['action_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'image_url': imageUrl,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'type': type.toString().split('.').last,
      'ticket_id': ticketId,
      'action_url': actionUrl,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? imageUrl,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isRead,
    NotificationType? type,
    String? ticketId,
    String? actionUrl,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      ticketId: ticketId ?? this.ticketId,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }

}

enum NotificationType {
  general,
  ticketAssigned,
  ticketUpdated,
  ticketClosed,
  leaveApproved,
  leaveRejected,
  attendanceReminder,
  announcement,
}

extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.general:
        return 'General';
      case NotificationType.ticketAssigned:
        return 'Ticket Assigned';
      case NotificationType.ticketUpdated:
        return 'Ticket Updated';
      case NotificationType.ticketClosed:
        return 'Ticket Closed';
      case NotificationType.leaveApproved:
        return 'Leave Approved';
      case NotificationType.leaveRejected:
        return 'Leave Rejected';
      case NotificationType.attendanceReminder:
        return 'Attendance Reminder';
      case NotificationType.announcement:
        return 'Announcement';
    }
  }

  String get iconPath {
    switch (this) {
      case NotificationType.general:
        return 'assets/icons/notification.png';
      case NotificationType.ticketAssigned:
        return 'assets/icons/ticket.png';
      case NotificationType.ticketUpdated:
        return 'assets/icons/update.png';
      case NotificationType.ticketClosed:
        return 'assets/icons/check.png';
      case NotificationType.leaveApproved:
        return 'assets/icons/approved.png';
      case NotificationType.leaveRejected:
        return 'assets/icons/rejected.png';
      case NotificationType.attendanceReminder:
        return 'assets/icons/clock.png';
      case NotificationType.announcement:
        return 'assets/icons/announcement.png';
    }
  }
}
