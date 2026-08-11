import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../core/app_colors.dart';

class MealRequestsScreen extends StatefulWidget {
  const MealRequestsScreen({super.key});

  @override
  State<MealRequestsScreen> createState() => _MealRequestsScreenState();
}

class _MealRequestsScreenState extends State<MealRequestsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  List<RequestModel> _allRequests = [];
  bool _isLoading = true;
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Accepted', 'Rejected'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    String? uid = _authService.currentUid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() => _currentUser = UserModel.fromMap(doc.data()!));
        _listenToRequests();
      }
    }
  }

  void _listenToRequests() {
    if (_currentUser == null || _currentUser!.messId == null) return;

    _dbService.getAllMealRequests(_currentUser!.messId!).listen((requests) {
      if (mounted) {
        setState(() {
          _allRequests = requests;
          _isLoading = false;
        });
      }
    });
  }

  List<RequestModel> get _filteredRequests {
    if (_selectedFilter == 'Pending') {
      return _allRequests.where((r) => r.status == RequestStatus.pending).toList();
    } else if (_selectedFilter == 'Accepted') {
      return _allRequests.where((r) => r.status == RequestStatus.accepted).toList();
    } else if (_selectedFilter == 'Rejected') {
      return _allRequests.where((r) => r.status == RequestStatus.rejected).toList();
    }
    return _allRequests;
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.accepted:
        return AppColors.success;
      case RequestStatus.rejected:
        return AppColors.error;
      case RequestStatus.pending:
        return AppColors.warning;
    }
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = label);
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isManager = _currentUser?.role == UserRole.manager || _currentUser?.role == UserRole.superAdmin;
    final requests = _filteredRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Requests History'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Accepted'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rejected'),
                ],
              ),
            ),
          ),
          Expanded(
            child: requests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          "No $_selectedFilter meal requests found",
                          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      final statusColor = _getStatusColor(req.status);

                      List<String> mealChanges = [];
                      req.mealsRequested.forEach((meal, isOn) {
                        mealChanges.add("${meal[0].toUpperCase()}${meal.substring(1)}: ${isOn ? 'ON' : 'OFF'}");
                      });
                      if (req.guestMealsRequested != null) {
                        req.guestMealsRequested!.forEach((meal, mealCount) {
                          if (mealCount > 0) {
                            mealChanges.add("Guest ${meal[0].toUpperCase()}${meal.substring(1)}: $mealCount");
                          }
                        });
                      }

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                        child: Text(
                                          req.userName.isNotEmpty ? req.userName[0].toUpperCase() : 'M',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            req.userName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Text(
                                            "Target Date: ${req.date.day}/${req.date.month}/${req.date.year}",
                                            style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: statusColor),
                                    ),
                                    child: Text(
                                      req.status.name.toUpperCase(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              const Text(
                                "Requested Changes:",
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: mealChanges.map((change) {
                                  return Chip(
                                    label: Text(change, style: const TextStyle(fontSize: 12)),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Submitted: ${req.timestamp.day}/${req.timestamp.month} ${req.timestamp.hour}:${req.timestamp.minute.toString().padLeft(2, '0')}",
                                    style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 11),
                                  ),
                                  if (isManager && req.status == RequestStatus.pending)
                                    Row(
                                      children: [
                                        OutlinedButton(
                                          onPressed: () async {
                                            await _dbService.rejectRequest(req.id, _currentUser!.uid);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Request Rejected")),
                                              );
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            side: const BorderSide(color: AppColors.error),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          child: const Text("Reject"),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () async {
                                            await _dbService.approveRequest(req.id, _currentUser!.uid);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Request Accepted & Meals Updated")),
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.success,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          child: const Text("Accept"),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
