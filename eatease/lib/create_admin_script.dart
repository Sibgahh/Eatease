import 'dart:io';
import 'utils/create_admin.dart';

void main() async {
  print('====== EatEase Admin Creation Utility ======');
  print('This will create the initial admin user in Firebase');
  print('');
  
  print('Would you like to continue? (y/n)');
  String? response = stdin.readLineSync()?.toLowerCase();
  
  if (response == 'y' || response == 'yes') {
    print('Creating admin user...');
    await createInitialAdmin();
    print('Process completed.');
  } else {
    print('Operation cancelled.');
  }
  
  exit(0);
} 