import 'lib/models/action_log.dart';

void main() {
  // Simuliraj tačno ono što radi mesecni_putnik_service.dart
  final actionLog = ActionLog(
    createdBy: '550e8400-e29b-41d4-a716-446655440000',
    createdAt: DateTime.now(),
  ).addAction(
    ActionType.paid,
    '550e8400-e29b-41d4-a716-446655440000',
    'Test mesečno plaćanje',
  );

  print('ActionLog JSON: ${actionLog.toJsonString()}');

  final json = actionLog.toJson();
  print('Has actions key: ${json.containsKey("actions")}');
  print('Actions type: ${json["actions"].runtimeType}');
  print('Actions length: ${json["actions"].length}');
  print('Actions content: ${json["actions"]}');
}
