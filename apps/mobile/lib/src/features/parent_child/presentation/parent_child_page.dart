import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/parent_child_repository.dart';

class ParentChildPage extends StatefulWidget {
  const ParentChildPage({super.key});

  @override
  State<ParentChildPage> createState() => _ParentChildPageState();
}

class _ParentChildPageState extends State<ParentChildPage> {
  late final ParentChildRepository _repository;
  late Future<List<Map<String, dynamic>>> _linksFuture;

  @override
  void initState() {
    super.initState();
    _repository = ParentChildRepository(Supabase.instance.client);
    _linksFuture = _repository.fetchLinks();
  }

  void _refresh() {
    setState(() {
      _linksFuture = _repository.fetchLinks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Family Connection',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _linksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final links = snapshot.data ?? [];

          if (links.isEmpty) {
            return _EmptyState(onAdd: () {});
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SafetyCard(onSOS: () => _showSOSDialog(context)),
              const SizedBox(height: 24),
              Text(
                'Linked Family Members',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              ...links.map((link) => _FamilyLinkCard(link: link)),
            ],
          );
        },
      ),
    );
  }

  void _showSOSDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send SOS Alert?'),
        content: const Text(
          'This will immediately notify your linked parents that you need help.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _repository.createSOS('Emergency SOS triggered');
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('SOS Alert Sent!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.family_restroom_rounded,
              size: 64,
              color: Color(0xFF4490AD),
            ),
            const SizedBox(height: 20),
            const Text(
              'No family links yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Connect with your parents or children to enable safety features, screen time tracking, and SOS alerts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Family Member'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4490AD),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.onSOS});

  final VoidCallback onSOS;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1F3E), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_rounded, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text(
                'Safety Center',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'In case of emergency, use the SOS button to alert your family immediately.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSOS,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'TRIGGER SOS ALERT',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyLinkCard extends StatelessWidget {
  const _FamilyLinkCard({required this.link});

  final Map<String, dynamic> link;

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isParent = link['parent_id'] == currentUserId;
    final other = isParent ? link['child'] : link['parent'];
    final status = link['status'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE2E8F0),
          backgroundImage: other['avatar_url'] != null
              ? NetworkImage(other['avatar_url'])
              : null,
          child: other['avatar_url'] == null
              ? const Icon(Icons.person_rounded, color: Color(0xFF64748B))
              : null,
        ),
        title: Text(
          other['name'] ?? 'Family Member',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          isParent ? 'Child' : 'Parent',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: status == 'active'
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFFEF9C3),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: status == 'active'
                  ? const Color(0xFF166534)
                  : const Color(0xFF854D0E),
            ),
          ),
        ),
      ),
    );
  }
}
