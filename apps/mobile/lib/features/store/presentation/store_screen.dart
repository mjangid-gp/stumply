import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../data/store_repository.dart';

class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Crick Store')),
      body: StreamBuilder(
        stream: ref.watch(storeRepositoryProvider).watchProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const Center(child: Text('Store coming soon!'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: products.length,
            itemBuilder: (context, i) {
              final p = products[i];
              return Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: p.imageUrl != null
                          ? Image.network(p.imageUrl!, fit: BoxFit.cover)
                          : const Icon(Icons.shopping_bag, size: 48),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                          Text('${p.currency} ${p.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ElevatedButton(
                            onPressed: user == null
                                ? null
                                : () async {
                                    await ref.read(storeRepositoryProvider).createOrder(
                                      userId: user.uid,
                                      items: [{'productId': p.id, 'name': p.name, 'price': p.price}],
                                      total: p.price,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Order placed! Complete payment via Razorpay.')),
                                    );
                                  },
                            child: const Text('Buy'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
