/// Model za zahteve za mesta u kombiju (seat_requests tabela)
class SeatRequest {
  final String id;
  final String? putnikId;
  final String? grad;
  final DateTime? datum;
  final String? zeljenoVreme;
  final String? dodeljenoVreme;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? processedAt;
  final int priority;
  final String? batchId;
  final List<dynamic>? alternatives;
  final int changesCount;
  final int brojMesta;
  final String? vozacId;
  final String? customAdresa;
  final String? customAdresaId;

  // Polja iz join-a (opciono)
  final String? putnikIme;
  final String? brojTelefona;
  final String? tipPutnika;

  SeatRequest({
    required this.id,
    this.putnikId,
    this.grad,
    this.datum,
    this.zeljenoVreme,
    this.dodeljenoVreme,
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
    this.processedAt,
    this.priority = 1,
    this.batchId,
    this.alternatives,
    this.changesCount = 0,
    this.brojMesta = 1,
    this.vozacId,
    this.customAdresa,
    this.customAdresaId,
    this.putnikIme,
    this.brojTelefona,
    this.tipPutnika,
  });

  factory SeatRequest.fromJson(Map<String, dynamic> json) {
    // Provera da li su podaci o putniku ugneždeni (iz JOIN-a)
    final putnikData = json['registrovani_putnici'] as Map<String, dynamic>?;

    return SeatRequest(
      id: json['id'] as String,
      putnikId: json['putnik_id'] as String?,
      grad: json['grad'] as String?,
      datum: json['datum'] != null ? DateTime.parse(json['datum'] as String) : null,
      zeljenoVreme: json['zeljeno_vreme'] as String?,
      dodeljenoVreme: json['dodeljeno_vreme'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      processedAt: json['processed_at'] != null ? DateTime.parse(json['processed_at'] as String) : null,
      priority: json['priority'] as int? ?? 1,
      batchId: json['batch_id'] as String?,
      alternatives: json['alternatives'] != null ? json['alternatives'] as List<dynamic> : null,
      changesCount: json['changes_count'] as int? ?? 0,
      brojMesta: json['broj_mesta'] as int? ?? 1,
      vozacId: json['vozac_id'] as String?,
      customAdresa: json['custom_adresa'] as String?,
      customAdresaId: json['custom_adresa_id'] as String?,
      putnikIme: putnikData?['putnik_ime'] ?? json['putnik_ime'] as String?,
      brojTelefona: putnikData?['broj_telefona'] ?? json['broj_telefona'] as String?,
      tipPutnika: putnikData?['tip'] ?? json['tip'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'putnik_id': putnikId,
      'grad': grad,
      'datum': datum?.toIso8601String().split('T')[0],
      'zeljeno_vreme': zeljenoVreme,
      'dodeljeno_vreme': dodeljenoVreme,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
      'priority': priority,
      'batch_id': batchId,
      'alternatives': alternatives,
      'changes_count': changesCount,
      'broj_mesta': brojMesta,
      'vozac_id': vozacId,
      'custom_adresa': customAdresa,
      'custom_adresa_id': customAdresaId,
      if (putnikIme != null) 'putnik_ime': putnikIme,
      if (brojTelefona != null) 'broj_telefona': brojTelefona,
      if (tipPutnika != null) 'tip': tipPutnika,
    };
  }

  SeatRequest copyWith({
    String? id,
    String? putnikId,
    String? grad,
    DateTime? datum,
    String? zeljenoVreme,
    String? dodeljenoVreme,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? processedAt,
    int? priority,
    String? batchId,
    List<dynamic>? alternatives,
    int? changesCount,
    int? brojMesta,
    String? vozacId,
    String? customAdresa,
    String? customAdresaId,
    String? putnikIme,
    String? brojTelefona,
    String? tipPutnika,
  }) {
    return SeatRequest(
      id: id ?? this.id,
      putnikId: putnikId ?? this.putnikId,
      grad: grad ?? this.grad,
      datum: datum ?? this.datum,
      zeljenoVreme: zeljenoVreme ?? this.zeljenoVreme,
      dodeljenoVreme: dodeljenoVreme ?? this.dodeljenoVreme,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      processedAt: processedAt ?? this.processedAt,
      priority: priority ?? this.priority,
      batchId: batchId ?? this.batchId,
      alternatives: alternatives ?? this.alternatives,
      changesCount: changesCount ?? this.changesCount,
      brojMesta: brojMesta ?? this.brojMesta,
      vozacId: vozacId ?? this.vozacId,
      customAdresa: customAdresa ?? this.customAdresa,
      customAdresaId: customAdresaId ?? this.customAdresaId,
      putnikIme: putnikIme ?? this.putnikIme,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      tipPutnika: tipPutnika ?? this.tipPutnika,
    );
  }
}
