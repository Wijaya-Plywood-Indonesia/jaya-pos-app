import 'package:flutter/material.dart';

import 'format.dart';
import 'theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.letter, this.size = 40});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}

/// Logo Mawra POS (ikon merah). Jika file gambar belum terpasang, tampil huruf M sebagai cadangan.
class MawraLogo extends StatelessWidget {
  const MawraLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.225),
      child: Image.asset(
        'assets/brand/mawra_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => BrandMark(letter: 'M', size: size),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.owner = false, this.size = 40});

  final String name;
  final bool owner;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: owner ? AppColors.owner : Theme.of(context).colorScheme.primary,
      ),
      child: Text(
        initialOf(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}