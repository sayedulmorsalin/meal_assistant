import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:meal_assistant/services/auth_service.dart';
import 'package:meal_assistant/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_assistant/models/user_model.dart';
import 'package:url_launcher/url_launcher.dart';
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
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: _showPrivacyPolicyDialog,
            ),
            ProfileActionTile(
              icon: Icons.description_outlined,
              title: 'Terms & Conditions',
              onTap: _showTermsConditionsDialog,
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
              icon: Icons.logout,
              title: 'Logout',
              onTap: _showLogoutDialog,
              isDestructive: true,
            ),
            ProfileActionTile(
              icon: Icons.exit_to_app,
              title: 'Leave Mess',
              onTap: _confirmLeaveMess,
              isDestructive: true,
            ),
            ProfileActionTile(
              icon: Icons.delete_forever,
              title: 'Delete Account',
              onTap: _confirmDeleteAccount,
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

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open $urlString")),
        );
      }
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to permanently delete your account? This action cannot be undone and all your profile data will be permanently removed.',
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _launchURL('https://meal-assistant-beta.vercel.app/delete-account'),
              child: const Text(
                'Online Deletion Request: meal-assistant-beta.vercel.app/delete-account',
                style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _launchURL('https://meal-assistant-beta.vercel.app/delete-account'),
            child: const Text('Online Guide'),
          ),
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              setState(() => _isLoading = true);
              String? error = await AuthService().deleteAccount();
              if (mounted) {
                setState(() => _isLoading = false);
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                } else {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• For mess management queries, contact your Mess Manager.'),
            const SizedBox(height: 8),
            const Text('• For technical support, reach out to support@mealassistant.app'),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _launchURL('https://meal-assistant-beta.vercel.app/support'),
              child: const Text(
                '• Visit Support Portal: meal-assistant-beta.vercel.app/support',
                style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _launchURL('https://meal-assistant-beta.vercel.app/support'),
            child: const Text('Open Support Portal'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Privacy Policy for Meal Assistant', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Your privacy is important to us. Meal Assistant collects minimal data required to provide mess management services:'),
              const SizedBox(height: 8),
              const Text('• Personal Info: Name and Email for authentication & identification within your mess group.'),
              const SizedBox(height: 4),
              const Text('• Usage Data: Meal requests, deposits, shopping logs, and group messages.'),
              const SizedBox(height: 4),
              const Text('• Data Protection: We store your data securely in Cloud Firestore and do not share it with third parties.'),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _launchURL('https://meal-assistant-beta.vercel.app/privacy-policy'),
                child: const Text(
                  'Read full policy online at meal-assistant-beta.vercel.app/privacy-policy',
                  style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _launchURL('https://meal-assistant-beta.vercel.app/privacy-policy'),
            child: const Text('Open Online Policy'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showTermsConditionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('By using Meal Assistant, you agree to the following terms:'),
              const SizedBox(height: 8),
              const Text('1. User Conduct: Members must accurately enter meal records and maintain respectful group communication.'),
              const SizedBox(height: 4),
              const Text('2. Mess Management: Deposits and shopping expenditures are managed collectively by your mess members and manager.'),
              const SizedBox(height: 4),
              const Text('3. Account Responsibility: You are responsible for keeping your login credentials confidential.'),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _launchURL('https://meal-assistant-beta.vercel.app/terms'),
                child: const Text(
                  'Read full terms online at meal-assistant-beta.vercel.app/terms',
                  style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _launchURL('https://meal-assistant-beta.vercel.app/terms'),
            child: const Text('Open Online Terms'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Meal Assistant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Meal Assistant v1.0.0'),
            const SizedBox(height: 8),
            const Text('Comprehensive mess management system for automated meal tracking, deposit management, shopping records, and real-time group chat.'),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _launchURL('https://meal-assistant-beta.vercel.app/'),
              child: const Text(
                'Website: meal-assistant-beta.vercel.app',
                style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _launchURL('https://meal-assistant-beta.vercel.app/'),
            child: const Text('Visit Website'),
          ),
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

