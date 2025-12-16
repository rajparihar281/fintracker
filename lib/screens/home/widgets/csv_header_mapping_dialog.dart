import 'package:flutter/material.dart';

class CsvHeaderMappingDialog extends StatefulWidget {
  final List<String> csvHeaders;
  final Function(Map<String, String>) onMappingConfirmed;

  const CsvHeaderMappingDialog({
    Key? key,
    required this.csvHeaders,
    required this.onMappingConfirmed,
  }) : super(key: key);

  @override
  State<CsvHeaderMappingDialog> createState() => _CsvHeaderMappingDialogState();
}

class _CsvHeaderMappingDialogState extends State<CsvHeaderMappingDialog> {
  static const List<String> requiredFields = [
    'date',
    'title',
    'amount_or_debit',
    'amount_or_credit',
  ];

  static const List<String> optionalFields = [
    'description',
    'account_name',
    'account_holder',
    'account_number',
    'category',
  ];

  Map<String, String?> fieldMapping = {};

  @override
  void initState() {
    super.initState();
    _initializeMapping();
  }

  void _initializeMapping() {
    for (var field in [...requiredFields, ...optionalFields]) {
      fieldMapping[field] = null;
    }

    for (var csvHeader in widget.csvHeaders) {
      final lowerHeader = csvHeader.toLowerCase().trim();

      if ((lowerHeader.contains('date') || lowerHeader.contains('time')) &&
          fieldMapping['date'] == null) {
        fieldMapping['date'] = csvHeader;
      } else if ((lowerHeader.contains('title') ||
              lowerHeader.contains('description') ||
              lowerHeader.contains('narration') ||
              lowerHeader.contains('particular') ||
              lowerHeader.contains('details')) &&
          fieldMapping['title'] == null) {
        fieldMapping['title'] = csvHeader;
      } else if ((lowerHeader.contains('debit') ||
              lowerHeader.contains('withdrawal') ||
              lowerHeader == 'dr' ||
              lowerHeader.contains('expense')) &&
          fieldMapping['amount_or_debit'] == null) {
        fieldMapping['amount_or_debit'] = csvHeader;
      } else if ((lowerHeader.contains('credit') ||
              lowerHeader.contains('deposit') ||
              lowerHeader == 'cr' ||
              lowerHeader.contains('income')) &&
          fieldMapping['amount_or_credit'] == null) {
        fieldMapping['amount_or_credit'] = csvHeader;
      } else if (lowerHeader == 'amount' || lowerHeader == 'amt') {
        fieldMapping['amount_or_debit'] ??= csvHeader;
        fieldMapping['amount_or_credit'] ??= csvHeader;
      } else if (lowerHeader.contains('category') &&
          fieldMapping['category'] == null) {
        fieldMapping['category'] = csvHeader;
      } else if (lowerHeader.contains('account') &&
          lowerHeader.contains('name') &&
          fieldMapping['account_name'] == null) {
        fieldMapping['account_name'] = csvHeader;
      } else if (lowerHeader.contains('holder') &&
          fieldMapping['account_holder'] == null) {
        fieldMapping['account_holder'] = csvHeader;
      } else if (lowerHeader.contains('account') &&
          (lowerHeader.contains('number') || lowerHeader.contains('no')) &&
          fieldMapping['account_number'] == null) {
        fieldMapping['account_number'] = csvHeader;
      } else if ((lowerHeader.contains('desc') ||
              lowerHeader.contains('note')) &&
          fieldMapping['description'] == null) {
        fieldMapping['description'] = csvHeader;
      }
    }
  }

  bool _isRequiredFieldsMapped() {
    return fieldMapping['date'] != null &&
        fieldMapping['title'] != null &&
        (fieldMapping['amount_or_debit'] != null ||
            fieldMapping['amount_or_credit'] != null);
  }

  String _getFieldLabel(String field) {
    switch (field) {
      case 'date':
        return 'Date/Time *';
      case 'title':
        return 'Title/Description *';
      case 'amount_or_debit':
        return 'Debit/Expense/Amount *';
      case 'amount_or_credit':
        return 'Credit/Income/Amount *';
      case 'description':
        return 'Description (Optional)';
      case 'account_name':
        return 'Account Name (Optional)';
      case 'account_holder':
        return 'Account Holder (Optional)';
      case 'account_number':
        return 'Account Number (Optional)';
      case 'category':
        return 'Category (Optional)';
      default:
        return field;
    }
  }

  String _getFieldHint(String field) {
    switch (field) {
      case 'date':
        return 'Select column with date/time';
      case 'title':
        return 'Select column with title';
      case 'amount_or_debit':
        return 'Select debit/expense column';
      case 'amount_or_credit':
        return 'Select credit/income column';
      default:
        return 'Select CSV column';
    }
  }

  Widget _buildMappingRow(String field) {
    final isRequired = requiredFields.contains(field);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getFieldLabel(field),
                  style: TextStyle(
                    fontWeight: isRequired ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 14,
                    color: isDarkMode
                        ? (isRequired ? Colors.white : Colors.white70)
                        : (isRequired ? Colors.black87 : Colors.black54),
                  ),
                ),
                if (isRequired)
                  Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade400,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: fieldMapping[field],
              dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isRequired ? Colors.blue : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: fieldMapping[field] != null
                        ? Colors.green.shade300
                        : (isRequired
                            ? Colors.orange.shade300
                            : Colors.grey.shade300),
                  ),
                ),
                filled: true,
                fillColor: fieldMapping[field] != null
                    ? (isDarkMode
                        ? Colors.green.shade900.withOpacity(0.3)
                        : Colors.green.shade50)
                    : (isDarkMode ? Colors.grey[800] : Colors.grey.shade50),
              ),
              hint: Text(
                _getFieldHint(field),
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white60 : Colors.black54,
                ),
              ),
              isExpanded: true,
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    '-- Not mapped --',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white60 : Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ),
                ...widget.csvHeaders.map((header) {
                  return DropdownMenuItem<String>(
                    value: header,
                    child: Text(
                      header,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  fieldMapping[field] = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allFieldsMapped = _isRequiredFieldsMapped();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      title: Row(
        children: [
          const Icon(Icons.table_chart, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            'Map CSV Headers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.blue.shade900.withOpacity(0.3)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.blue.shade700
                        : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Match your CSV columns to the fields below. Required fields are marked with *',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.orange.shade900.withOpacity(0.3)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Required Fields',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...requiredFields.map(_buildMappingRow),
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline,
                        color: isDarkMode ? Colors.white70 : Colors.grey,
                        size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Optional Fields',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...optionalFields.map(_buildMappingRow),
              const SizedBox(height: 20),
              if (!allFieldsMapped)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.orange.shade900.withOpacity(0.3)
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.orange.shade700
                          : Colors.orange.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Please map all required fields (marked with *) before proceeding',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: isDarkMode ? Colors.white70 : Colors.grey.shade700,
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: allFieldsMapped
              ? () {
                  final cleanedMapping = Map<String, String>.fromEntries(
                    fieldMapping.entries
                        .where((entry) => entry.value != null)
                        .map((entry) => MapEntry(entry.key, entry.value!)),
                  );

                  widget.onMappingConfirmed(cleanedMapping);
                  Navigator.pop(context);
                }
              : null,
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Confirm Mapping'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
