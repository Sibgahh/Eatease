import 'package:flutter/material.dart';
import 'profile_screen.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../services/auth/auth_service.dart';

class ProfileNavigation extends StatelessWidget {
  const ProfileNavigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('[PROFILE_NAV] Building ProfileNavigation widget');
    return const CustomerProfileScreen();
  }
} 