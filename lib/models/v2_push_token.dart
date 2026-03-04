/// Model za push tokene (v2_push_tokens tabela)
class V2PushToken {
  final String id;
  final String token;
  final String provider;
  final String? vozacId;
  final String? putnikId;
  final String? putnikTabela;
  final DateTime? updatedAt;

  V2PushToken({
    required this.id,
    required this.token,
    required this.provider,
    this.vozacId,
    this.putnikId,
    this.putnikTabela,
    this.updatedAt,
  });

  factory V2PushToken.fromJson(Map<String, dynamic> json) {
    return V2PushToken(
      id: json['id'] as String? ?? '',
      token: json['token'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      vozacId: json['vozac_id'] as String?,
      putnikId: json['putnik_id'] as String?,
      putnikTabela: json['putnik_tabela'] as String?,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'token': token,
      'provider': provider,
      'vozac_id': vozacId,
      'putnik_id': putnikId,
      'putnik_tabela': putnikTabela,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
