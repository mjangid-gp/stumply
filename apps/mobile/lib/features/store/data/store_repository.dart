import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(firestore: FirebaseFirestore.instance);
});

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    this.imageUrl,
    this.description = '',
    this.category = 'apparel',
  });

  final String id;
  final String name;
  final double price;
  final String currency;
  final String? imageUrl;
  final String description;
  final String category;

  factory Product.fromMap(String id, Map<String, dynamic> data) => Product(
    id: id,
    name: data['name'] as String? ?? '',
    price: (data['price'] as num?)?.toDouble() ?? 0,
    currency: data['currency'] as String? ?? 'INR',
    imageUrl: data['imageUrl'] as String?,
    description: data['description'] as String? ?? '',
    category: data['category'] as String? ?? 'apparel',
  );
}

class StoreRepository {
  StoreRepository({required this._firestore});
  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  Stream<List<Product>> watchProducts({String? category}) {
    Query<Map<String, dynamic>> query = _firestore.collection('products');
    if (category != null) query = query.where('category', isEqualTo: category);
    return query.snapshots().map(
      (snap) => snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList(),
    );
  }

  Future<String> createOrder({
    required String userId,
    required List<Map<String, dynamic>> items,
    required double total,
  }) async {
    final id = _uuid.v4();
    await _firestore.collection('orders').doc(id).set({
      'userId': userId,
      'items': items,
      'total': total,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }
}
