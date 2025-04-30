extension StringExtension on String {
  String charAt(int index) {
    if (index < 0 || index >= this.length) {
      return '';
    }
    return this[index];
  }
} 