import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_assistant/models/join_request_model.dart';
import 'package:meal_assistant/models/mess_model.dart';
import 'package:meal_assistant/models/user_model.dart';
import 'package:meal_assistant/services/auth_service.dart';
import 'package:meal_assistant/services/database_service.dart';
import '../../core/app_colors.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  UserModel? _admin;
  MessModel? _mess;
  List<UserModel> _members = [];
  List<JoinRequestModel> _joinRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  void _loadAdminData() async {
    String? uid = _authService.currentUid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() => _admin = UserModel.fromMap(doc.data()!));
        _listenToData();
      }
    }
  }

  void _listenToData() {
    if (_admin?.messId != null) {
      _dbService.getMessDetails(_admin!.messId!).listen((mess) {
        if (mounted) setState(() => _mess = mess);
      });

      _dbService.getMessMembers(_admin!.messId!).listen((members) {
        if (mounted) {
          setState(() {
            _members = members;
            _isLoading = false;
          });
        }
      });

      _dbService.getPendingJoinRequests(_admin!.messId!).listen((requests) {
        if (mounted) setState(() => _joinRequests = requests);
      });
    }
  }

  void _toggleRole(UserModel member, bool isManager) async {
    await FirebaseFirestore.instance.collection('users').doc(member.uid).update({
      'role': isManager ? 'manager' : 'member'
    });
    if (isManager && _admin?.messId != null) {
      await _dbService.assignManager(_admin!.messId!, member.uid);
    }
  }

  void _confirmRemove(UserModel member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Member?"),
        content: Text("Are you sure you want to remove ${member.name} from the mess?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _dbService.removeMember(member.uid, _admin!.messId!);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_admin == null || _isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final superAdmins = _members.where((m) => m.role == UserRole.superAdmin).toList();
    final managers = _members.where((m) => m.role == UserRole.manager).toList();
    final ordinaryMembers = _members.where((m) => m.role == UserRole.member).toList();

    String participationHomeName = _admin?.participationRole == UserRole.manager ? "Manager Home" : "Member Home";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_mess != null) _buildMessInfoCard(),
              const SizedBox(height: 16),
              
              // New: Button to go back to participation home
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.home),
                  label: Text("Back to $participationHomeName"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              
              // Join Requests Section (Always Visible)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Join Requests',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (_joinRequests.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)),
                      child: Text('${_joinRequests.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_joinRequests.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(child: Text('No pending requests', style: TextStyle(color: Colors.grey))),
                )
              else
                ..._joinRequests.map((r) => _buildRequestCard(r)),

              const Divider(height: 40),

              Text(
                'Team Management (${_members.length})',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              if (_members.isEmpty)
                _buildEmptyState()
              else ...[
                // Super Admins
                if (superAdmins.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text('Super Admin', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                  ),
                  ...superAdmins.map((m) => _buildMemberCard(m)),
                  const SizedBox(height: 16),
                ],

                // Managers
                if (managers.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text('Managers', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                  ),
                  ...managers.map((m) => _buildMemberCard(m)),
                  const SizedBox(height: 16),
                ],

                // Regular Members
                if (ordinaryMembers.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text('Members', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                  ),
                  ...ordinaryMembers.map((m) => _buildMemberCard(m)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessInfoCard() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              _mess!.name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Join Key: ',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7)),
                ),
                SelectableText(
                  _mess!.joinKey,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _mess!.joinKey));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Join Key copied to clipboard!')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            Icon(Icons.group_add, size: 80, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'No members have joined yet.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share your Join Key with others to get started!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(UserModel member) {
    bool isManager = member.role == UserRole.manager;
    bool isSuperAdmin = member.role == UserRole.superAdmin;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSuperAdmin 
              ? Colors.amber 
              : (isManager ? AppColors.success : Theme.of(context).colorScheme.primary),
          child: Icon(
            isSuperAdmin ? Icons.star : (isManager ? Icons.security : Icons.person),
            color: Colors.white,
          ),
        ),
        title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(isSuperAdmin ? 'Super Admin (${member.participationRole?.toString().split('.').last})' : (isManager ? 'Manager' : 'Member')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: isSuperAdmin ? (member.participationRole == UserRole.manager) : isManager,
              activeThumbColor: AppColors.success,
              activeTrackColor: AppColors.success.withValues(alpha: 0.5),
              onChanged: (value) async {
                if (isSuperAdmin) {
                  await FirebaseFirestore.instance.collection('users').doc(member.uid).update({
                    'participationRole': value ? 'manager' : 'member'
                  });
                } else {
                  _toggleRole(member, value);
                }
              },
            ),
            if (member.uid != _admin?.uid)
              IconButton(
                icon: const Icon(Icons.person_remove, color: AppColors.error),
                onPressed: () => _confirmRemove(member),
                tooltip: 'Remove from mess',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(JoinRequestModel request) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person_add_alt_1),
        ),
        title: Text(request.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Wants to join'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: AppColors.success),
              onPressed: () => _dbService.acceptJoinRequest(request),
              tooltip: 'Accept',
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: AppColors.error),
              onPressed: () => _dbService.rejectJoinRequest(request.id),
              tooltip: 'Reject',
            ),
          ],
        ),
      ),
    );
  }
}
