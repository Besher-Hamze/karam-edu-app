import 'package:flutter/material.dart';

class Validators {
  static FormFieldValidator<String> required(String message) {
    return (value) {
      if (value == null || value.isEmpty) {
        return message;
      }
      return null;
    };
  }

  static FormFieldValidator<String> email(String message) {
    return (value) {
      if (value == null || value.isEmpty) {
        return 'البريد الإلكتروني مطلوب';
      }

      final bool isValid = RegExp(
        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
      ).hasMatch(value);

      if (!isValid) {
        return message;
      }
      return null;
    };
  }

  static FormFieldValidator<String> minLength(int length, String message) {
    return (value) {
      if (value == null || value.isEmpty) {
        return 'هذا الحقل مطلوب';
      }

      if (value.length < length) {
        return message;
      }
      return null;
    };
  }
}

