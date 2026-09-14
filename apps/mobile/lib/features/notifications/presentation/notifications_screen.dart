import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Scaffold(body: Center(child: Text('Login required')));

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .doc(user.uid)
            .collection('items')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data?.docs ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No notifications'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final data = items[i].data();
              return ListTile(
                leading: Icon(_iconForType(data['type'] as String?)),
                title: Text(data['title'] as String? ?? ''),
                subtitle: Text(data['body'] as String? ?? ''),
                trailing: data['read'] == true ? null : const Icon(Icons.circle, size: 8, color: Colors.blue),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'match': return Icons.sports_cricket;
      case 'tournament': return Icons.emoji_events;
      case 'follow': return Icons.person_add;
      default: return Icons.notifications;
    }
  }
}
