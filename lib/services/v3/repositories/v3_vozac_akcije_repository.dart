import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/v3_vozac_akcije.dart';

class V3VozacAkcijeRepository {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'v3_vozac_akcije';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  Future<List<V3VozacAkcija>> getAll() async {
    try {
      final snapshot = await _collection.get();
      return snapshot.docs
          .map((doc) => V3VozacAkcija.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Greška pri učitavanju akcija: $e');
    }
  }

  Future<V3VozacAkcija> getById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) {
        throw Exception('Akcija sa ID $id ne postoji');
      }
      return V3VozacAkcija.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      throw Exception('Greška pri učitavanju akcije: $e');
    }
  }

  Future<List<V3VozacAkcija>> getByVozacId(String vozacId) async {
    try {
      final snapshot = await _collection
          .where('vozac_id', isEqualTo: vozacId)
          .orderBy('datum', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => V3VozacAkcija.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Greška pri učitavanju akcija za vozača: $e');
    }
  }

  Future<List<V3VozacAkcija>> getByVozacIDan({
    required String vozacId,
    required DateTime dan,
  }) async {
    try {
      final startOfDay = DateTime(dan.year, dan.month, dan.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final snapshot = await _collection
          .where('vozac_id', isEqualTo: vozacId)
          .where('datum', isGreaterThanOrEqualTo: startOfDay)
          .where('datum', isLessThan: endOfDay)
          .orderBy('datum', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => V3VozacAkcija.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Greška pri učitavanju akcija za vozača i dan: $e');
    }
  }

  Future<List<V3VozacAkcija>> getNaplataByVozacIDan({
    required String vozacId,
    required DateTime dan,
  }) async {
    try {
      final startOfDay = DateTime(dan.year, dan.month, dan.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final snapshot = await _collection
          .where('vozac_id', isEqualTo: vozacId)
          .where('tip_akcije', isEqualTo: 'naplata')
          .where('datum', isGreaterThanOrEqualTo: startOfDay)
          .where('datum', isLessThan: endOfDay)
          .orderBy('datum', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => V3VozacAkcija.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Greška pri učitavanju naplata za vozača i dan: $e');
    }
  }

  Future<List<V3VozacAkcija>> getPokupioByVozacIDan({
    required String vozacId,
    required DateTime dan,
  }) async {
    try {
      final startOfDay = DateTime(dan.year, dan.month, dan.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final snapshot = await _collection
          .where('vozac_id', isEqualTo: vozacId)
          .where('tip_akcije', isEqualTo: 'pokupio')
          .where('datum', isGreaterThanOrEqualTo: startOfDay)
          .where('datum', isLessThan: endOfDay)
          .orderBy('datum', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => V3VozacAkcija.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Greška pri učitavanju pokupljenih za vozača i dan: $e');
    }
  }

  Future<V3VozacAkcija> insert(V3VozacAkcija akcija) async {
    try {
      final docRef = await _collection.add(akcija.toJson());
      final createdDoc = await docRef.get();
      return V3VozacAkcija.fromJson({...createdDoc.data()!, 'id': createdDoc.id});
    } catch (e) {
      throw Exception('Greška pri kreiranju akcije: $e');
    }
  }

  Future<Map<String, dynamic>> insertReturning(Map<String, dynamic> data) async {
    try {
      final docRef = await _collection.add(data);
      final createdDoc = await docRef.get();
      return {...createdDoc.data()!, 'id': createdDoc.id};
    } catch (e) {
      throw Exception('Greška pri kreiranju akcije: $e');
    }
  }

  Future<V3VozacAkcija> update(V3VozacAkcija akcija) async {
    try {
      await _collection.doc(akcija.id).update(akcija.toJson());
      return akcija;
    } catch (e) {
      throw Exception('Greška pri ažuriranju akcije: $e');
    }
  }

  Future<Map<String, dynamic>> updateByIdReturning(String id, Map<String, dynamic> data) async {
    try {
      await _collection.doc(id).update(data);
      final updatedDoc = await _collection.doc(id).get();
      if (!updatedDoc.exists) {
        throw Exception('Akcija sa ID $id ne postoji');
      }
      return {...updatedDoc.data()!, 'id': updatedDoc.id};
    } catch (e) {
      throw Exception('Greška pri ažuriranju akcije: $e');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      throw Exception('Greška pri brisanju akcije: $e');
    }
  }

  Stream<List<V3VozacAkcija>> streamByVozacId(String vozacId) {
    return _collection
        .where('vozac_id', isEqualTo: vozacId)
        .orderBy('datum', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => V3VozacAkcija.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<V3VozacAkcija>> streamNaplataByVozacIDan({
    required String vozacId,
    required DateTime dan,
  }) {
    final startOfDay = DateTime(dan.year, dan.month, dan.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return _collection
        .where('vozac_id', isEqualTo: vozacId)
        .where('tip_akcije', isEqualTo: 'naplata')
        .where('datum', isGreaterThanOrEqualTo: startOfDay)
        .where('datum', isLessThan: endOfDay)
        .orderBy('datum', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => V3VozacAkcija.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }
}
