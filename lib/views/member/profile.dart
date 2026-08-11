import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:mess_management/services/auth_service.dart';
import 'package:mess_management/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_management/models/user_model.dart';
import '../settings/settings_page.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    String? uid = AuthService().currentUid;
    if (uid != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
          _nameController.text = _user?.name ?? '';
          _isLoading = false;
        });
      }
    }
  }

  void _showImagePicker() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => _getImage(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => _getImage(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    Navigator.pop(context);
    final XFile? pickedImage = await _picker.pickImage(source: source, imageQuality: 70);
    if (pickedImage != null && _user != null) {
      File file = File(pickedImage.path);
      setState(() {
        _profileImage = file;
        _isLoading = true;
      });
      try {
        String url = await DatabaseService().uploadProfileImage(file, _user!.uid);
        await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
          'profileImage': url,
        });
        setState(() {
          _user = UserModel(
            uid: _user!.uid,
            name: _user!.name,
            email: _user!.email,
            role: _user!.role,
            participationRole: _user!.participationRole,
            messId: _user!.messId,
            profileImage: url,
            status: _user!.status,
            deposit: _user!.deposit,
          );
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to upload profile image: $e")));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showEditDialog(String title, TextEditingController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_user!.uid)
                    .update({'name': _nameController.text});
                setState(() {});
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showImagePicker,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!) as ImageProvider
                    : (_user?.profileImage != null && _user!.profileImage!.isNotEmpty
                        ? NetworkImage(_user!.profileImage!)
                        : null),
                child: (_profileImage == null && (_user?.profileImage == null || _user!.profileImage!.isEmpty))
                    ? Icon(
                        Icons.person,
                        size: 60,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            ProfileInfoTile(
              title: 'Name',
              value: _nameController.text,
              onTap: () => _showEditDialog('Edit Name', _nameController),
            ),
            const SizedBox(height: 30),
            ProfileActionTile(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              ),
            ),
            ProfileActionTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: _showHelpSupportDialog,
            ),
            ProfileActionTile(
              icon: Icons.info_outline,
              title: 'About',
              onTap: _showAboutDialog,
            ),
            const Divider(),
            ProfileActionTile(
              icon: Icons.exit_to_app,
              title: 'Leave Mess',
              onTap: _confirmLeaveMess,
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLeaveMess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Mess?'),
        content: const Text(
          'Are you sure you want to leave this mess? You will no longer see data from this mess, and your current deposit will be reset.',
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_user?.messId != null) {
                await DatabaseService().leaveMess(_user!.uid, _user!.messId!);
                if (mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).popUntil((route) => route.isFirst); // Go back to AuthWrapper
                }
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).popUntil((route) => route.isFirst); // Go back to AuthWrapper
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showHelpSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• For mess management queries, contact your Mess Manager.'),
            SizedBox(height: 8),
            Text('• For technical support, reach out to support@mealassistant.app'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Meal Assistant'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meal Assistant v1.0.0'),
            SizedBox(height: 8),
            Text('Comprehensive mess management system for automated meal tracking, deposit management, shopping records, and real-time group chat.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}

class ProfileInfoTile extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const ProfileInfoTile({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value),
      trailing: const Icon(Icons.edit),
      onTap: onTap,
    );
  }
}

class ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const ProfileActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        size: 30,
        color: isDestructive ? Colors.red : Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: isDestructive ? Colors.red : null,
          fontWeight: isDestructive ? FontWeight.bold : null,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 18),
      onTap: onTap,
    );
  }
}

