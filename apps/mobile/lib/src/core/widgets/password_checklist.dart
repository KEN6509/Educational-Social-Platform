import 'package:flutter/material.dart';

import '../security/password_policy.dart';

class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({required this.status, super.key});

  final PasswordPolicyResult status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _PasswordRule(
            label: 'At least 12 characters',
            isMet: status.hasMinimumLength,
          ),
          _PasswordRule(
            label: 'Contains an uppercase letter',
            isMet: status.hasUppercase,
          ),
          _PasswordRule(
            label: 'Contains a lowercase letter',
            isMet: status.hasLowercase,
          ),
          _PasswordRule(
            label: 'Contains a number',
            isMet: status.hasNumber,
          ),
          _PasswordRule(
            label: 'Contains a symbol such as !, @, #, \$, %, or &',
            isMet: status.hasSymbol,
          ),
        ],
      ),
    );
  }
}

class _PasswordRule extends StatelessWidget {
  const _PasswordRule({required this.label, required this.isMet});

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final color = isMet ? const Color(0xFF15803D) : const Color(0xFF94A3B8);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
