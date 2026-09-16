import 'dart:convert';

import 'package:flutter/material.dart';

class CricketAvatarOption {
  const CricketAvatarOption({
    required this.id,
    required this.label,
    required this.assetPath,
  });

  final String id;
  final String label;
  final String assetPath;

  String get storageValue => 'avatar:$id';
}

class CricketAvatars {
  static const prefix = 'avatar:';

  static const options = [
    CricketAvatarOption(
      id: 'batsman',
      label: 'Batter',
      assetPath: 'assets/images/avatars/avatar_batter.png',
    ),
    CricketAvatarOption(
      id: 'bowler',
      label: 'Bowler',
      assetPath: 'assets/images/avatars/avatar_bowler.png',
    ),
    CricketAvatarOption(
      id: 'keeper',
      label: 'Keeper',
      assetPath: 'assets/images/avatars/avatar_keeper.png',
    ),
    CricketAvatarOption(
      id: 'allrounder',
      label: 'All-rounder',
      assetPath: 'assets/images/avatars/avatar_allrounder.png',
    ),
    CricketAvatarOption(
      id: 'fielder',
      label: 'Catch',
      assetPath: 'assets/images/avatars/avatar_fielder.png',
    ),
    CricketAvatarOption(
      id: 'six',
      label: 'Six!',
      assetPath: 'assets/images/avatars/avatar_six.png',
    ),
    CricketAvatarOption(
      id: 'umpire',
      label: 'Umpire',
      assetPath: 'assets/images/avatars/avatar_umpire.png',
    ),
    CricketAvatarOption(
      id: 'stumps',
      label: 'Stumps',
      assetPath: 'assets/images/avatars/avatar_stumps.png',
    ),
  ];

  static bool isBuiltIn(String? photoUrl) =>
      photoUrl != null && photoUrl.startsWith(prefix);

  static CricketAvatarOption? byValue(String? photoUrl) {
    if (!isBuiltIn(photoUrl)) return null;
    final id = photoUrl!.substring(prefix.length);
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }
}

class CricketAvatar extends StatelessWidget {
  const CricketAvatar({
    super.key,
    required this.photoUrl,
    this.radius = 36,
    this.name = '',
  });

  final String? photoUrl;
  final double radius;
  final String name;

  @override
  Widget build(BuildContext context) {
    final option = CricketAvatars.byValue(photoUrl);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final size = radius * 2;

    Widget clip(Widget child) {
      return ClipOval(
        child: SizedBox(width: size, height: size, child: child),
      );
    }

    if (option != null) {
      return clip(
        Image.asset(
          option.assetPath,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: const Color(0xFF1B4332),
            child: Icon(Icons.sports_cricket, color: Colors.white, size: radius),
          ),
        ),
      );
    }

    if (photoUrl != null && photoUrl!.startsWith('data:image')) {
      try {
        final comma = photoUrl!.indexOf(',');
        final bytes = base64Decode(photoUrl!.substring(comma + 1));
        return clip(
          Image.memory(bytes, fit: BoxFit.cover, width: size, height: size),
        );
      } catch (_) {
        // Fall through to initials.
      }
    }

    if (photoUrl != null && photoUrl!.startsWith('http')) {
      return clip(
        Image.network(
          photoUrl!,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: const Color(0xFF1B4332),
            child: Center(
              child: Text(initial, style: TextStyle(color: Colors.white, fontSize: radius * 0.75, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF1B4332),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.75,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
