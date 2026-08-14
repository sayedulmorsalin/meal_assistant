import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_assistant/models/join_request_model.dart';
import 'package:meal_assistant/models/mess_model.dart';
import 'package:meal_assistant/models/user_model.dart';
import 'package:meal_assistant/services/auth_service.dart';
import 'package:meal_assistant/services/database_service.dart';
import '../landing/landpage.dart';
import '../manager/manager_home.dart';
import '../member/user_home.dart';
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
      FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((doc) {
        if (doc.exists && mounted) {
          setState(() => _admin = UserModel.fromMap(doc.data()!));
          if (_mess == null && _admin?.messId != null) {
            _listenToData();
          }
        }
      });
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

  void _confirmDeleteMess() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
                  SizedBox(width: 8),
                  Text("Delete Mess?", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Are you sure you want to permanently delete '${_mess?.name ?? 'this mess'}'?",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "This action CANNOT be undone. All data will be permanently deleted:\n"
                    "• All daily meals & member records\n"
                    "• All shopping expenses & deposits\n"
                    "• All meal change & join requests\n"
                    "• Mess chat history & meal plans\n"
                    "• All members will be removed from this mess",
                    style: TextStyle(fontSize: 13, color: Colors.redAccent),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton.icon(
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete_forever, size: 18),
                  label: Text(isDeleting ? "Deleting..." : "Delete Mess Permanently"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          setDialogState(() => isDeleting = true);
                          if (_mess?.id != null) {
                            await _dbService.deleteMess(_mess!.id);
                          }
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          nav.pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const Landpage()),
                            (route) => false,
                          );
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text("Mess and all associated data have been permanently deleted."),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        },
                ),
              ],
            );
          },
        );
      },
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
              
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Widget targetHome = _admin?.participationRole == UserRole.manager
                        ? const ManagerHome()
                        : const UserHome();
                    if (Navigator.canPop(context)) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => targetHome),
                      );
                    } else {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => targetHome),
                        (route) => false,
                      );
                    }
                  },
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

              const Divider(height: 40),

              // Danger Zone Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
                        SizedBox(width: 8),
                        Text(
                          "Danger Zone",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Permanently delete this mess and all associated records for all members.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text("Delete Mess & All Info", style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _confirmDeleteMess,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMessNameDialog() {
    if (_mess == null) return;
    final controller = TextEditingController(text: _mess!.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text("Edit Mess Name", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: "Mess Name",
                    hintText: "Enter new mess name",
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "Mess name cannot be empty";
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final newName = controller.text.trim();
                          if (newName == _mess!.name) {
                            Navigator.pop(dialogContext);
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _dbService.updateMessName(_mess!.id, newName, _admin!.uid);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text("Mess name updated successfully!"),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text("Failed to update mess name: $e"),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }

                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMessInfoCard() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _mess!.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Edit Mess Name',
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  onPressed: _showEditMessNameDialog,
                ),
              ],
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
