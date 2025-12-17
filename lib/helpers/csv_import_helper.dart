import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CsvImportHelper {
  static Future<Map<String, dynamic>> parseCsvFile(String filePath) async {
    try {
      final file = File(filePath);
      final input = await file.readAsString();

      final csvData = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
        textDelimiter: '"',
      ).convert(input);

      if (csvData.isEmpty) {
        throw Exception('CSV file is empty');
      }

      final headers = csvData[0]
          .map((e) => e.toString().trim())
          .where((h) => h.isNotEmpty)
          .toList();

      final dataRows = csvData.sublist(1);

      return {
        'headers': headers,
        'rows': dataRows,
        'filePath': filePath,
      };
    } catch (e) {
      throw Exception('Error parsing CSV: $e');
    }
  }

  static Map<String, dynamic>? parseRow(
    List<dynamic> row,
    Map<String, String> mapping,
    List<String> headers,
  ) {
    try {
      final rowData = <String, dynamic>{};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        rowData[headers[i]] = row[i];
      }

      final date = _parseDate(rowData[mapping['date']]);
      if (date == null) return null;

      final title = rowData[mapping['title']]?.toString().trim() ?? '';
      if (title.isEmpty) return null;

      double? debitAmount;
      double? creditAmount;

      final debitColumn = mapping['amount_or_debit'];
      final creditColumn = mapping['amount_or_credit'];

      if (debitColumn != null) {
        final debitStr = rowData[debitColumn]?.toString() ?? '';
        debitAmount = _parseAmount(debitStr);
      }

      if (creditColumn != null) {
        final creditStr = rowData[creditColumn]?.toString() ?? '';
        creditAmount = _parseAmount(creditStr);
      }

      String type;
      double amount;

      if (debitColumn == creditColumn && debitColumn != null) {
        final rawAmount = debitAmount ?? 0.0;
        amount = rawAmount.abs();

        if (rawAmount < 0) {
          type = 'debit';
        } else if (rawAmount > 0) {
          type = 'credit';
        } else {
          return null;
        }
      } else {
        if (debitAmount != null && debitAmount > 0) {
          type = 'debit';
          amount = debitAmount;
        } else if (creditAmount != null && creditAmount > 0) {
          type = 'credit';
          amount = creditAmount;
        } else {
          return null;
        }
      }

      final description = mapping['description'] != null
          ? rowData[mapping['description']]?.toString().trim() ?? ''
          : '';

      final accountName = mapping['account_name'] != null
          ? rowData[mapping['account_name']]?.toString().trim() ?? ''
          : '';

      final accountHolder = mapping['account_holder'] != null
          ? rowData[mapping['account_holder']]?.toString().trim() ?? ''
          : '';

      final accountNumber = mapping['account_number'] != null
          ? rowData[mapping['account_number']]?.toString().trim() ?? ''
          : '';

      final category = mapping['category'] != null
          ? rowData[mapping['category']]?.toString().trim() ?? ''
          : '';

      return {
        'date': date,
        'title': title,
        'amount': amount,
        'type': type,
        'description': description,
        'account_name': accountName,
        'account_holder': accountHolder,
        'account_number': accountNumber,
        'category': category,
      };
    } catch (e) {
      debugPrint('Error parsing row: $e');
      return null;
    }
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;

    String s = raw.toString().replaceAll('"', '').trim();

    if (s.isEmpty) return null;

    final monthMap = {
      'JAN': 'Jan',
      'JANUARY': 'Jan',
      'FEB': 'Feb',
      'FEBRUARY': 'Feb',
      'MAR': 'Mar',
      'MARCH': 'Mar',
      'APR': 'Apr',
      'APRIL': 'Apr',
      'MAY': 'May',
      'JUN': 'Jun',
      'JUNE': 'Jun',
      'JUL': 'Jul',
      'JULY': 'Jul',
      'AUG': 'Aug',
      'AUGUST': 'Aug',
      'SEP': 'Sep',
      'SEPTEMBER': 'Sep',
      'OCT': 'Oct',
      'OCTOBER': 'Oct',
      'NOV': 'Nov',
      'NOVEMBER': 'Nov',
      'DEC': 'Dec',
      'DECEMBER': 'Dec',
    };

    s = s.replaceAllMapped(RegExp(r'-(\w{3,9})-', caseSensitive: false), (m) {
      final monthStr = m.group(1)!.toUpperCase();
      return '-${monthMap[monthStr] ?? m.group(1)}-';
    });

    final formats = <DateFormat>[
      DateFormat("dd-MMM-yyyy HH:mm:ss", "en_US"),
      DateFormat("dd-MMM-yyyy HH:mm", "en_US"),
      DateFormat("dd-MM-yyyy HH:mm:ss"),
      DateFormat("dd-MM-yyyy HH:mm"),
      DateFormat("dd/MM/yyyy HH:mm:ss"),
      DateFormat("dd/MM/yyyy HH:mm"),
      DateFormat("yyyy-MM-dd HH:mm:ss"),
      DateFormat("yyyy-MM-dd HH:mm"),
      DateFormat("MM/dd/yyyy HH:mm:ss"),
      DateFormat("MM/dd/yyyy HH:mm"),
      DateFormat("dd-MMM-yyyy", "en_US"),
      DateFormat("dd-MM-yyyy"),
      DateFormat("dd/MM/yyyy"),
      DateFormat("yyyy-MM-dd"),
      DateFormat("MM/dd/yyyy"),
      DateFormat("MM-dd-yyyy"),
      DateFormat("d-MMM-yyyy", "en_US"),
      DateFormat("d/M/yyyy"),
    ];

    for (var format in formats) {
      try {
        return format.parseStrict(s);
      } catch (_) {}
    }

    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static double _parseAmount(String? raw) {
    if (raw == null || raw.isEmpty) return 0.0;

    String s = raw.toString().replaceAll('"', '').trim();

    s = s.replaceAll(RegExp(r'[₹$€£¥,\s]'), '');

    final isNegative =
        s.startsWith('-') || s.startsWith('(') || s.endsWith(')');
    s = s.replaceAll(RegExp(r'[-()]'), '');

    final amount = double.tryParse(s) ?? 0.0;

    return isNegative ? -amount.abs() : amount;
  }
}
