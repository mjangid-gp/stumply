import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../auth/data/auth_repository.dart';
import '../data/subscription_repository.dart';

class ProScreen extends ConsumerStatefulWidget {
  const ProScreen({super.key});

  @override
  ConsumerState<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends ConsumerState<ProScreen> {
  List<Package> _packages = [];
  bool _isPro = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      await ref.read(subscriptionRepositoryProvider).initialize(user.uid);
    }
    final isPro = await ref.read(subscriptionRepositoryProvider).isProUser();
    final packages = await ref.read(subscriptionRepositoryProvider).getOfferings();
    setState(() { _isPro = isPro; _packages = packages; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PRO Club')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.star, size: 64, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text(
                    _isPro ? 'You are a PRO member!' : 'Upgrade to PRO',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text('• Advanced CricInsights analytics\n• Ad-free experience\n• PRO Club community\n• Priority support'),
                  const Spacer(),
                  if (!_isPro && _packages.isEmpty)
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('PRO - Configure RevenueCat'),
                    ),
                  ..._packages.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton(
                      onPressed: () async {
                        final success = await ref.read(subscriptionRepositoryProvider).purchase(p);
                        if (success) _load();
                      },
                      child: Text('${p.storeProduct.title} - ${p.storeProduct.priceString}'),
                    ),
                  )),
                  TextButton(
                    onPressed: () => ref.read(subscriptionRepositoryProvider).restore(),
                    child: const Text('Restore Purchases'),
                  ),
                ],
              ),
            ),
    );
  }
}
