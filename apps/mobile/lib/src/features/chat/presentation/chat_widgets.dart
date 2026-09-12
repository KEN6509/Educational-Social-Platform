import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/chat_models.dart';
import '../data/chat_mention.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/unread_badge.dart';

part 'chat_message_bubbles.dart';
part 'chat_message_media.dart';
part 'chat_list_widgets.dart';

const chatNavy = Color(0xFF0B1F3E);
const chatCyan = Color(0xFF4490AD);
const chatBackground = Color(0xFFFAFCFC);
const chatInput = Colors.white;
const chatBorder = Color(0xFFE2E8F0);
const chatDanger = Color(0xFFE11D48);
const chatWhatsappBackground = Color(0xFFECE5DD);
const chatMineBubble = Color(0xFFD9FDD3);
const chatOtherBubble = Colors.white;
const chatSoftGrey = Color(0xFFF8FAFC);
const chatPreviewBackground = Color(0xFFF1F3F5);
const chatMentionAccent = Color(0xFF128C7E);

const chatAppBarTitleStyle = TextStyle(
  color: chatNavy,
  fontSize: 18,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.2,
);

const chatSectionTitleStyle = TextStyle(
  color: chatNavy,
  fontSize: 15,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.1,
);

const _groupColors = [
  Color(0xFF2563EB),
  Color(0xFF0F766E),
  Color(0xFFF97316),
  Color(0xFF7C3AED),
  Color(0xFF059669),
  Color(0xFFDB2777),
];

String _formatBubbleTime(DateTime value) {
  final local = value.toLocal();
  final period = local.hour >= 12 ? 'PM' : 'AM';
  final hourValue = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final hour = hourValue.toString();
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute $period';
}

String _formatPreviewDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year} ${_formatBubbleTime(local)}';
}

String _formatChatTime(DateTime? value) {
  if (value == null) return '';
  final now = DateTime.now();
  final local = value.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final difference = today.difference(date).inDays;
  if (difference == 0) {
    return _formatBubbleTime(local);
  }
  if (difference == 1) return 'Yesterday';
  if (difference > 1 && difference < 7) return _weekdayLabel(local.weekday);
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Mon';
    case DateTime.tuesday:
      return 'Tue';
    case DateTime.wednesday:
      return 'Wed';
    case DateTime.thursday:
      return 'Thu';
    case DateTime.friday:
      return 'Fri';
    case DateTime.saturday:
      return 'Sat';
    default:
      return 'Sun';
  }
}
