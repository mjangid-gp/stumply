import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  runApp(const CrickAdminApp());
}

class CrickAdminApp extends StatelessWidget {
  const CrickAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crick Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
      ),
      home: const AdminDashboard(),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crick Admin Panel'),
        actions: [
          if (user == null)
            TextButton(onPressed: _signIn, child: const Text('Sign In'))
          else
            TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: Text(user.email ?? 'Admin')),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.article), label: Text('Feed')),
              NavigationRailDestination(icon: Icon(Icons.shopping_bag), label: Text('Products')),
              NavigationRailDestination(icon: Icon(Icons.emoji_events), label: Text('Tournaments')),
              NavigationRailDestination(icon: Icon(Icons.flag), label: Text('Associations')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _buildTab()),
        ],
      ),
    );
  }

  Widget _buildTab() {
    switch (_tab) {
      case 0:
        return const _FeedManager();
      case 1:
        return const _ProductManager();
      case 2:
        return const _TournamentManager();
      case 3:
        return const _AssociationManager();
      default:
        return const SizedBox();
    }
  }

  Future<void> _signIn() async {
    final email = 'admin@crick.app';
    const password = 'admin123456';
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    } catch (_) {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
    }
    setState(() {});
  }
}

class _FeedManager extends StatelessWidget {
  const _FeedManager();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('feedPosts').add({
                'title': 'Welcome to Crick!',
                'body': 'Score your local matches and track your cricket journey.',
                'type': 'article',
                'published': true,
                'createdAt': FieldValue.serverTimestamp(),
              });
            },
            child: const Text('Publish Welcome Post'),
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: FirebaseFirestore.instance.collection('feedPosts').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  return ListTile(
                    title: Text(d['title'] as String? ?? ''),
                    subtitle: Text(d['body'] as String? ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => docs[i].reference.delete(),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductManager extends StatelessWidget {
  const _ProductManager();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('products').add({
                'name': 'Crick Jersey',
                'price': 999,
                'currency': 'INR',
                'category': 'apparel',
                'description': 'Official Crick team jersey',
              });
            },
            child: const Text('Add Sample Product'),
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: FirebaseFirestore.instance.collection('products').snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  return ListTile(
                    title: Text(d['name'] as String? ?? ''),
                    subtitle: Text('${d['currency']} ${d['price']}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TournamentManager extends StatelessWidget {
  const _TournamentManager();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('tournaments').orderBy('startDate', descending: true).snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            return ListTile(
              title: Text(d['name'] as String? ?? ''),
              subtitle: Text('${d['city']} · ${d['status']}'),
              trailing: Switch(
                value: d['featured'] as bool? ?? false,
                onChanged: (v) => docs[i].reference.update({'featured': v}),
              ),
            );
          },
        );
      },
    );
  }
}

class _AssociationManager extends StatelessWidget {
  const _AssociationManager();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('associations').add({
                'name': 'BCCI State Association',
                'type': 'bcci',
                'active': true,
              });
            },
            child: const Text('Add Association'),
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: FirebaseFirestore.instance.collection('associations').snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  return ListTile(
                    title: Text(d['name'] as String? ?? ''),
                    subtitle: Text(d['type'] as String? ?? ''),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
