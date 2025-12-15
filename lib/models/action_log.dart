import 'dart:convert';

/// Helper klasa za rad sa action_log JSONB kolom
/// Umesto 5 vozac_id kolona sada koristimo strukturisan action_log
class ActionLog {
  ActionLog({
    this.createdBy,
    this.paidBy,
    this.pickedBy,
    this.cancelledBy,
    this.primaryDriver,
    this.createdAt,
    this.actions = const [],
  });

  factory ActionLog.fromJson(Map<String, dynamic> json) {
    return ActionLog(
      createdBy: json['created_by'] as String?,
      paidBy: json['paid_by'] as String?,
      pickedBy: json['picked_by'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      primaryDriver: json['primary_driver'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      actions: (json['actions'] as List<dynamic>?)
              ?.map((action) => ActionEntry.fromJson(action as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory ActionLog.empty() {
    return ActionLog();
  }

  factory ActionLog.fromString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty || jsonString == '{}') {
      return ActionLog.empty();
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ActionLog.fromJson(json);
    } catch (e) {
      return ActionLog.empty();
    }
  }

  /// ✅ NOVO: Sigurno parsiranje action_log iz baze - rukuje [], {}, String ili Map
  factory ActionLog.fromDynamic(dynamic value) {
    if (value == null) return ActionLog.empty();
    if (value is List && value.isEmpty) return ActionLog.empty();
    if (value is String) {
      if (value.isEmpty || value == '{}' || value == '[]') return ActionLog.empty();
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return ActionLog.fromJson(Map<String, dynamic>.from(decoded));
        }
        return ActionLog.empty();
      } catch (_) {
        return ActionLog.empty();
      }
    }
    if (value is Map) {
      return ActionLog.fromJson(Map<String, dynamic>.from(value));
    }
    return ActionLog.empty();
  }

  final String? createdBy;
  final String? paidBy;
  final String? pickedBy;
  final String? cancelledBy;
  final String? primaryDriver;
  final DateTime? createdAt;
  final List<ActionEntry> actions;

  Map<String, dynamic> toJson() {
    return {
      'created_by': createdBy,
      'paid_by': paidBy,
      'picked_by': pickedBy,
      'cancelled_by': cancelledBy,
      'primary_driver': primaryDriver,
      'created_at': createdAt?.toIso8601String(),
      'actions': actions.map((action) => action.toJson()).toList(),
    };
  }

  /// Kreira novi ActionLog sa dodanim akcijom
  ActionLog addAction(ActionType type, String vozacId, [String? note]) {
    final newAction = ActionEntry(
      type: type,
      vozacId: vozacId,
      timestamp: DateTime.now(),
      note: note,
    );

    return ActionLog(
      createdBy: createdBy,
      paidBy: type == ActionType.paid ? vozacId : paidBy,
      pickedBy: type == ActionType.picked ? vozacId : pickedBy,
      cancelledBy: type == ActionType.cancelled ? vozacId : cancelledBy,
      primaryDriver: primaryDriver,
      createdAt: createdAt,
      actions: [...actions, newAction],
    );
  }

  @override
  String toString() {
    return 'ActionLog{createdBy: $createdBy, actions: ${actions.length}}';
  }
}

/// Pojedinačna akcija u log-u
class ActionEntry {
  ActionEntry({
    required this.type,
    required this.vozacId,
    required this.timestamp,
    this.note,
  });

  factory ActionEntry.fromJson(Map<String, dynamic> json) {
    return ActionEntry(
      type: ActionType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => ActionType.created,
      ),
      vozacId: json['vozac_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      note: json['note'] as String?,
    );
  }

  final ActionType type;
  final String vozacId;
  final DateTime timestamp;
  final String? note;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'vozac_id': vozacId,
      'timestamp': timestamp.toIso8601String(),
      'note': note,
    };
  }

  @override
  String toString() {
    return 'ActionEntry{type: $type, vozacId: $vozacId, timestamp: $timestamp}';
  }
}

/// Tipovi akcija koje vozači mogu da izvrše
enum ActionType {
  created, // Kreirao putnika
  paid, // Naplatio
  picked, // Pokupio
  cancelled, // Otkazao
}

extension ActionTypeExtension on ActionType {
  String get displayName {
    switch (this) {
      case ActionType.created:
        return 'Kreirao';
      case ActionType.paid:
        return 'Naplatio';
      case ActionType.picked:
        return 'Pokupio';
      case ActionType.cancelled:
        return 'Otkazao';
    }
  }

  String get icon {
    switch (this) {
      case ActionType.created:
        return '➕';
      case ActionType.paid:
        return '💰';
      case ActionType.picked:
        return '🚐';
      case ActionType.cancelled:
        return '❌';
    }
  }
}
