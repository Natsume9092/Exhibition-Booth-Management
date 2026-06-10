import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _search = '';
  UserRole? _filterRole;
  final _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final fmt = DateFormat('dd MMM yyyy');

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search users by name or email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear),
                    onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                : null,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              FilterChip(label: const Text('All'), selected: _filterRole == null,
                onSelected: (_) => setState(() => _filterRole = null)),
              const SizedBox(width: 8),
              ...UserRole.values.where((r) => r != UserRole.guest).map((r) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(r.name[0].toUpperCase() + r.name.substring(1)),
                  selected: _filterRole == r,
                  onSelected: (_) => setState(() => _filterRole = _filterRole == r ? null : r),
                ),
              )),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: usersAsync.when(
          loading: () => const LoadingWidget(),
          error: (e, _) => ErrorWidget2(message: e.toString()),
          data: (users) {
            var filtered = users.where((u) {
              if (_filterRole != null && u.role != _filterRole) return false;
              if (_search.isNotEmpty) {
                return u.displayName.toLowerCase().contains(_search.toLowerCase()) ||
                  u.email.toLowerCase().contains(_search.toLowerCase()) ||
                  (u.companyName?.toLowerCase().contains(_search.toLowerCase()) ?? false);
              }
              return true;
            }).toList();

            // Stats
            final total = users.length;
            final exhibitors = users.where((u) => u.role == UserRole.exhibitor).length;
            final organizers = users.where((u) => u.role == UserRole.organizer).length;

            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  _UserStat(label: 'Total', count: total, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  _UserStat(label: 'Exhibitors', count: exhibitors, color: AppTheme.accentColor),
                  const SizedBox(width: 8),
                  _UserStat(label: 'Organizers', count: organizers, color: AppTheme.secondaryColor),
                ]),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                  ? const EmptyState(message: 'No users found', icon: Icons.person_search)
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final user = filtered[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _roleColor(user.role).withOpacity(0.15),
                              child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                                style: TextStyle(color: _roleColor(user.role), fontWeight: FontWeight.bold)),
                            ),
                            title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(user.email, style: const TextStyle(fontSize: 12)),
                              if (user.companyName != null)
                                Text(user.companyName!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ]),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              StatusChip(
                                label: user.role.name[0].toUpperCase() + user.role.name.substring(1),
                                color: _roleColor(user.role),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (action) {
                                  if (action == 'toggle') _toggleActive(ref, user);
                                  if (action == 'delete') _deleteUser(context, ref, user);
                                  if (action == 'role') _changeRole(context, ref, user);
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'toggle',
                                    child: Text(user.isActive ? 'Deactivate' : 'Activate')),
                                  const PopupMenuItem(value: 'role', child: Text('Change Role')),
                                  const PopupMenuItem(value: 'delete',
                                    child: Text('Delete', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            ]),
                            isThreeLine: user.companyName != null,
                          ),
                        );
                      },
                    ),
              ),
            ]);
          },
        ),
      ),
    ]);
  }

  Color _roleColor(UserRole role) => switch (role) {
    UserRole.admin => const Color(0xFF1A237E),
    UserRole.organizer => AppTheme.secondaryColor,
    UserRole.exhibitor => AppTheme.accentColor,
    UserRole.guest => Colors.grey,
  };

  Future<void> _toggleActive(WidgetRef ref, UserModel user) async {
    final updated = user.copyWith(isActive: !user.isActive);
    await ref.read(dbProvider).updateUser(updated);
    ref.invalidate(allUsersProvider);
  }

  Future<void> _deleteUser(BuildContext context, WidgetRef ref, UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Delete User',
        message: 'Permanently delete ${user.displayName}?',
        confirmLabel: 'Delete',
        confirmColor: Colors.red,
      ),
    );
    if (confirm != true) return;
    await ref.read(dbProvider).deleteUser(user.id);
    ref.invalidate(allUsersProvider);
  }

  Future<void> _changeRole(BuildContext context, WidgetRef ref, UserModel user) async {
    UserRole? newRole = user.role;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Change User Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: UserRole.values.where((r) => r != UserRole.guest).map((r) => RadioListTile<UserRole>(
              title: Text(r.name[0].toUpperCase() + r.name.substring(1)),
              value: r, groupValue: newRole,
              onChanged: (v) => setState(() => newRole = v),
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (newRole != null && newRole != user.role) {
                  await ref.read(dbProvider).updateUser(user.copyWith(role: newRole));
                  ref.invalidate(allUsersProvider);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _UserStat({required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ]),
    ),
  );
}
