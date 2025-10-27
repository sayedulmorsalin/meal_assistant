import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: AdminHome()));

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  // Initial list of members
  List<Member> _members = [
    Member(id: '1', name: 'Morsalin', isManager: true),
    Member(id: '2', name: 'John Doe', isManager: false),
    Member(id: '3', name: 'Jane Smith', isManager: false),
    Member(id: '4', name: 'Alice Johnson', isManager: true),
  ];

  void _showRoleEditor() {
    // Create a copy of the current members to edit locally
    final workingMembers = _members.map((m) => m.copyWith()).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Manage Roles'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: workingMembers.length,
                itemBuilder: (context, index) {
                  final member = workingMembers[index];
                  return SwitchListTile(
                    key: Key(member.id),
                    title: Text(member.name),
                    subtitle: Text(
                      member.isManager ? 'Manager' : 'Member',
                      style: TextStyle(
                        color: member.isManager ? Colors.green : Colors.grey,
                      ),
                    ),
                    value: member.isManager,
                    onChanged: (value) => setDialogState(() {
                      workingMembers[index] = member.copyWith(isManager: value ?? false);
                    }),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: Navigator.of(context).pop,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Update the main list with the edited values
                  setState(() {
                    _members = List.from(workingMembers); // Efficient copy
                    print('Updated Members: $_members'); // Debug
                  });

                  // Optional: Show a success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Roles updated successfully')),
                  );

                  Navigator.pop(context); // Close dialog
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showRoleEditor,
            tooltip: 'Edit Roles',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView.builder(
          itemCount: _members.length,
          itemBuilder: (context, index) => _MemberCard(member: _members[index]),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Member member;

  const _MemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        key: Key(member.id),
        leading: Icon(
          member.isManager ? Icons.security : Icons.person,
          color: member.isManager ? Colors.green : Colors.blue,
        ),
        title: Text(member.name),
        subtitle: Text(member.isManager ? 'Manager' : 'Member'),
      ),
    );
  }
}

@immutable
class Member {
  final String id;
  final String name;
  final bool isManager;

  const Member({
    required this.id,
    required this.name,
    required this.isManager,
  });

  Member copyWith({
    String? id,
    String? name,
    bool? isManager,
  }) =>
      Member(
        id: id ?? this.id,
        name: name ?? this.name,
        isManager: isManager ?? this.isManager,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Member &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              name == other.name &&
              isManager == other.isManager;

  @override
  int get hashCode => Object.hash(id, name, isManager);

  @override
  String toString() => 'Member(id: $id, name: $name, isManager: $isManager)';
}