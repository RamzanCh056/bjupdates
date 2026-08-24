import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:beatjerky/utils/role_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Shows current role and allows switching to any role.
class RoleSwitcherChip extends StatelessWidget {
  const RoleSwitcherChip({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserStatusProvider>();
    if (provider.roles.isEmpty) return const SizedBox.shrink();
    final effectiveRoles = provider.effectiveRoles;
    final effectiveLabel = effectiveRoles.isNotEmpty
        ? roleDisplayLabel(effectiveRoles.first)
        : 'Role';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showRolePicker(context, provider),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: recntsColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: recntsColor.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_horiz, size: 16, color: recntsColor),
              const SizedBox(width: 6),
              Text(
                effectiveLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: recntsColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showRolePicker(BuildContext context, UserStatusProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1F1F1F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'View as role',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...const [
              RoleKeys.listener,
              RoleKeys.artist,
              RoleKeys.organizer,
              RoleKeys.venue,
            ].map((role) {
              final isActive =
                  provider.effectiveRoles.isNotEmpty &&
                  provider.effectiveRoles.first == role;
              return ListTile(
                title: Text(
                  roleDisplayLabel(role),
                  style: const TextStyle(color: Colors.white),
                ),
                leading: Icon(
                  Icons.person,
                  color: isActive ? recntsColor : Colors.white24,
                ),
                onTap: () async {
                  final ok = await provider.switchRoleAndPersist(role);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!ok) {
                    AppToast.show(
                      'Unable to switch role. Try again.',
                      isError: true,
                    );
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
