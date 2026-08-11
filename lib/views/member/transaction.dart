import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mess_management/models/log_model.dart';
import 'package:mess_management/models/user_model.dart';
import 'package:mess_management/services/auth_service.dart';
import 'package:mess_management/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/app_colors.dart';

class Transaction extends StatefulWidget {
  const Transaction({super.key});

  @override
  State<Transaction> createState() => _TransactionState();
}

class _TransactionState extends State<Transaction> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    String? uid = _authService.currentUid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() => _user = UserModel.fromMap(doc.data()!));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null || _user!.messId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<LogModel>>(
          stream: _dbService.getLogs(_user!.messId!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No transactions found"));
            }

            final logs = snapshot.data!;
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              separatorBuilder: (context, index) => const Divider(height: 32),
              itemBuilder: (context, index) {
                final log = logs[index];
                return ListTile(
                  leading: Icon(
                    Icons.history,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                  title: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: log.message,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: '\n${DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
