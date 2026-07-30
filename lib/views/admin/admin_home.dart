import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_management/models/user_model.dart';
import 'package:mess_management/services/auth_service.dart';
import 'package:mess_management/services/database_service.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  UserModel? _admin;
  List<UserModel> _members = [];

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  void _loadAdminData() async {
    String? uid = _authService.currentUid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() => _admin = UserModel.fromMap(doc.data()!));
        _listenToMembers();
      }
    }
  }

  void _listenToMembers() {
    if (_admin?.messId != null) {
      _dbService.getMessMembers(_admin!.messId!).listen((members) {
        if (mounted) setState(() => _members = members);
      });
    }
  }

  void _showRoleEditor() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Manage Roles'),
            content: SizedBox(
              width: double.maxFinite,
              child: _members.isEmpty 
                  ? const Center(child: Text("No members found"))
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final member = _members[index];
                  if (member.role == UserRole.superAdmin) return const SizedBox.shrink();
                  return SwitchListTile(
                    key: Key(member.uid),
                    title: Text(member.name),
                    subtitle: Text(
                      member.role == UserRole.manager ? 'Manager' : 'Member',
                      style: TextStyle(
                        color: member.role == UserRole.manager ? Colors.green : Colors.grey,
                      ),
                    ),
                    value: member.role == UserRole.manager,
                    onChanged: (value) async {
                      await FirebaseFirestore.instance.collection('users').doc(member.uid).update({
                        'role': value ? 'manager' : 'member'
                      });
                      // If making someone manager, update mess too
                      if (value && _admin?.messId != null) {
                        await _dbService.assignManager(_admin!.messId!, member.uid);
                      }
                      setDialogState(() {});
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: Navigator.of(context).pop,
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_admin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showRoleEditor,
            tooltip: 'Edit Roles',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
            },
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
  final UserModel member;

  const _MemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    bool isManager = member.role == UserRole.manager;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        key: Key(member.uid),
        leading: Icon(
          isManager ? Icons.security : Icons.person,
          color: isManager ? Colors.green : Colors.blue,
        ),
        title: Text(member.name),
        subtitle: Text(isManager ? 'Manager' : 'Member'),
      ),
    );
  }
}
