import 'package:flutter/material.dart';

class CyanZoneWordmark extends StatelessWidget {
  const CyanZoneWordmark({
    this.color = const Color(0xFF0B1F3E),
    this.fontSize = 28,
    this.textAlign,
    super.key,
  });

  final Color color;
  final double fontSize;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      'CyanZone',
      textAlign: textAlign,
      style: TextStyle(
        color: color,
        fontFamily: 'Pacifico',
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        height: 1.2,
      ),
    );
  }
}
