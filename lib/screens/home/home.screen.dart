import 'dart:io';
import 'package:csv/csv.dart';
import 'package:events_emitter/events_emitter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fintracker/bloc/cubit/app_cubit.dart';
import 'package:fintracker/dao/account_dao.dart';
import 'package:fintracker/dao/payment_dao.dart';
import 'package:fintracker/events.dart';
import 'package:fintracker/model/account.model.dart';
import 'package:fintracker/model/category.model.dart';
import 'package:fintracker/model/payment.model.dart';
import 'package:fintracker/screens/home/widgets/date_picker.dart';
import 'package:fintracker/screens/home/widgets/line_chart.dart';
import 'package:fintracker/screens/home/widgets/pie_chart.dart';
import 'package:fintracker/screens/home/widgets/account_slider.dart';
import 'package:fintracker/screens/home/widgets/payment_list_item.dart';
import 'package:fintracker/screens/payment_form.screen.dart';
import 'package:fintracker/theme/colors.dart';
import 'package:fintracker/widgets/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../dao/tag_dao.dart';
import '../../model/tag.model.dart';
import '../../helpers/csv_import_helper.dart';
import '../home/widgets/csv_header_mapping_dialog.dart';

String greeting() {
  var hour = DateTime.now().hour;
  if (hour < 12) {
    return 'Morning';
  }
  if (hour < 17) {
    return 'Afternoon';
  }
  return 'Evening';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PaymentDao _paymentDao = PaymentDao();
  final AccountDao _accountDao = AccountDao();
  EventListener? _accountEventListener;
  EventListener? _categoryEventListener;
  EventListener? _paymentEventListener;
  EventListener? _tagEventListener;

  List<Payment> _payments = [];
  List<Account> _accounts = [];
  double _income = 0;
  double _expense = 0;
  List<double> _monthlyExpenses = List.generate(12, (index) => 0.0);
  Account? _selectedAccount;
  Category? _selectedCategory;

  List<Tag> tags = [];
  List<bool> selectedTags = [];
  final TagDao tagDao = TagDao();
  bool allSelected = true;

  DateTime _focusDate = DateTime.now();

  DateTimeRange _range = DateTimeRange(
      start: DateTime.now().subtract(Duration(days: DateTime.now().day - 1)),
      end: DateTime.now());
  Account? _account;
  Category? _category;
  bool _showingIncomeOnly = false;
  bool _showingExpenseOnly = false;
  String exportFormat = "Amount, Type";

  void openAddPaymentPage(PaymentType type) async {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (builder) => PaymentForm(type: type)));
  }

  void _updateDateRange(DateTimeRange newRange) {
    setState(() {
      _range = newRange;
      _fetchTransactions();
    });
  }

  void handleChooseDateRange() async {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (builder) =>
            CustomCalender(updateDateRange: _updateDateRange)));
  }

  Future<void> _fetchTransactions() async {
    List<Payment> trans;

    List<int> selectedTagIds = [];
    for (int i = 0; i < selectedTags.length; i++) {
      if (selectedTags[i]) {
        selectedTagIds.add(tags[i].id!);
      }
    }

    if (!allSelected && selectedTagIds.isNotEmpty) {
      trans = await _paymentDao.findByTags(
        range: _range,
        tagIds: selectedTagIds,
        account: _selectedAccount ?? _account,
        category: _selectedCategory,
        type: _showingIncomeOnly
            ? PaymentType.debit
            : _showingExpenseOnly
                ? PaymentType.credit
                : null,
      );
    } else {
      if (_selectedCategory == null) {
        trans = await _paymentDao.find(range: _range, category: _category);
      }
      if (_showingIncomeOnly) {
        trans = await _paymentDao.find(
          range: _range,
          type: PaymentType.debit,
          account: _selectedAccount ?? _account,
          category: _selectedCategory,
        );
      } else if (_showingExpenseOnly) {
        trans = await _paymentDao.find(
          range: _range,
          type: PaymentType.credit,
          account: _selectedAccount ?? _account,
          category: _selectedCategory,
        );
      } else {
        if (_selectedCategory != null) {
          trans = await _paymentDao.find(
            range: _range,
            category: _selectedCategory,
          );
        } else if (_selectedAccount != null) {
          trans =
              await _paymentDao.find(range: _range, account: _selectedAccount);
        } else {
          trans = await _paymentDao.find(range: _range, category: _category);
        }
      }
    }

    double income = 0;
    double expense = 0;
    List<double> monthlyExpenses = List.generate(12, (index) => 0.0);
    for (var payment in trans) {
      if (payment.type == PaymentType.credit) income += payment.amount;
      if (payment.type == PaymentType.debit) {
        expense += payment.amount;
        DateTime paymentDate = payment.datetime;
        monthlyExpenses[paymentDate.month - 1] += payment.amount;
      }
    }

    List<Account> accounts = await _accountDao.find(withSummery: true);

    setState(() {
      _payments = trans;
      _income = income;
      _expense = expense;
      _accounts = accounts;
      _monthlyExpenses = monthlyExpenses;
    });
  }

  void onAccountSelected(Account? account) {
    setState(() {
      _selectedAccount = account;
      _fetchTransactions();
    });
  }

  void onCategorySelected(Category? category) {
    setState(() {
      _selectedCategory = category;
      _fetchTransactions();
    });
  }

  Future<void> _fetchTags() async {
    final fetchedTags = await tagDao.findAll();
    setState(() {
      tags = fetchedTags;
      selectedTags = List<bool>.filled(tags.length, false);
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
    _fetchTags();
    _accountEventListener = globalEvent.on("account_update", (data) {
      debugPrint("accounts are changed");
      _fetchTransactions();
    });

    _categoryEventListener = globalEvent.on("category_update", (data) {
      debugPrint("categories are changed");
      _fetchTransactions();
    });

    _paymentEventListener = globalEvent.on("payment_update", (data) {
      debugPrint("payments are changed");
      _fetchTransactions();
      _fetchTags();
    });

    _tagEventListener = globalEvent.on("tag_update", (data) {
      debugPrint("tags are updated");
      _fetchTags();
    });
  }

  @override
  void dispose() {
    _accountEventListener?.cancel();
    _categoryEventListener?.cancel();
    _paymentEventListener?.cancel();
    _tagEventListener?.cancel();
    super.dispose();
  }

  Future<void> _showExportOptions(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Select Export Format"),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text("Amount, Type"),
                      leading: Radio<String>(
                        value: "Amount, Type",
                        groupValue: exportFormat,
                        onChanged: (String? value) {
                          setState(() {
                            exportFormat = value ?? "Amount, Type";
                          });
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text("Debit, Credit"),
                      leading: Radio<String>(
                        value: "Debit, Credit",
                        groupValue: exportFormat,
                        onChanged: (String? value) {
                          setState(() {
                            exportFormat = value ?? "Debit, Credit";
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                exportToCSV(context, exportFormat);
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  Future<void> exportToCSV(BuildContext context, String exportFormat) async {
    try {
      final reversedPayments = List<Payment>.from(_payments.reversed);
      List<List<String>> csvData = [];

      if (exportFormat == "Debit, Credit") {
        csvData.add([
          "ID",
          "Account Name",
          "Account Holder",
          "Account Number",
          "Category",
          "Debit",
          "Credit",
          "Date",
          "Title",
          "Description",
          "Auto Categorization"
        ]);
      } else {
        csvData.add([
          "ID",
          "Account Name",
          "Account Holder",
          "Account Number",
          "Category",
          "Amount",
          "Type",
          "Date",
          "Title",
          "Description",
          "Auto Categorization"
        ]);
      }

      for (var payment in reversedPayments) {
        if (exportFormat == "Debit, Credit") {
          csvData.add([
            payment.id?.toString() ?? '',
            payment.account.name,
            payment.account.holderName,
            payment.account.accountNumber,
            payment.category.name,
            payment.type == PaymentType.debit
                ? '-${payment.amount.toString()}'
                : '',
            payment.type == PaymentType.credit
                ? '+${payment.amount.toString()}'
                : '',
            payment.datetime.toIso8601String(),
            payment.title,
            payment.description,
            payment.autoCategorizationEnabled ? "Enabled" : "Disabled"
          ]);
        } else {
          csvData.add([
            payment.id?.toString() ?? '',
            payment.account.name,
            payment.account.holderName,
            payment.account.accountNumber,
            payment.category.name,
            payment.amount.toString(),
            payment.type.toString().split('.').last,
            payment.datetime.toIso8601String(),
            payment.title,
            payment.description,
            payment.autoCategorizationEnabled ? "Enabled" : "Disabled"
          ]);
        }
      }

      String csv = const ListToCsvConverter().convert(csvData);

      Directory directory = await getApplicationDocumentsDirectory();
      final path =
          "/storage/emulated/0/Download/${reversedPayments[0].datetime.day}payments.csv";
      final file = File(path);
      await file.writeAsString(csv);

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Export Options"),
            content: Column(
              children: [
                Text("New Transactions: ${reversedPayments.length}"),
                const Text("Updated Transactions: 0"),
                const Text("Local-Only Transactions: 0"),
                const SizedBox(height: 20),
                const Text(
                    "Would you like to download the CSV or share it via WhatsApp?"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  final result = await OpenFile.open(file.path);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('CSV saved to: ${file.path}')),
                  );
                },
                child: const Text("Download"),
              ),
              TextButton(
                onPressed: () async {
                  final xfile = XFile(file.path);
                  final result = await Share.shareXFiles([xfile],
                      text: "Here is the CSV file of Payment");
                  if (result.status == ShareResultStatus.success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Shared Successfully')),
                    );
                  }
                  await file.delete();
                  Navigator.of(context).pop();
                },
                child: const Text("Share to WhatsApp"),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("Error while exporting CSV: $e");
    }
  }

  Future<void> importPaymentsFromCSV(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final csvData =
          await CsvImportHelper.parseCsvFile(result.files.single.path!);
      final List<String> headers = List<String>.from(csvData['headers']);
      final List<List<dynamic>> dataRows =
          List<List<dynamic>>.from(csvData['rows']);

      if (headers.isEmpty || dataRows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSV file is empty or invalid'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      Map<String, String>? mapping;
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => CsvHeaderMappingDialog(
            csvHeaders: headers,
            onMappingConfirmed: (confirmedMapping) {
              mapping = confirmedMapping;
            },
          ),
        );
      }

      if (mapping == null) {
        return;
      }

      List<Payment> parsedPayments = [];
      int skippedRows = 0;

      Account defaultAccount = _accounts.firstWhere(
        (acc) => acc.isDefault == true,
        orElse: () => _accounts.isNotEmpty
            ? _accounts.first
            : Account(
                id: null,
                name: "Imported Account",
                holderName: "",
                accountNumber: "",
                icon: Icons.account_balance,
                color: Colors.blue,
                isDefault: false,
                income: 0.0,
                expense: 0.0,
                balance: 0.0,
              ),
      );

      Category defaultCategory = Category(
        id: 10,
        name: "Imported",
        icon: Icons.category,
        color: Colors.grey,
      );

      // REMOVED: nextId generation - let database handle it

      for (var row in dataRows) {
        final parsedRow = CsvImportHelper.parseRow(row, mapping!, headers);

        if (parsedRow == null) {
          skippedRows++;
          continue;
        }

        // FIXED: Create payment with id: null
        final payment = Payment(
          id: null, // Let database auto-generate ID
          account: defaultAccount,
          category: defaultCategory,
          amount: parsedRow['amount'],
          type: parsedRow['type'] == 'debit'
              ? PaymentType.debit
              : PaymentType.credit,
          datetime: parsedRow['date'],
          title: parsedRow['title'],
          description: parsedRow['description'] ?? '',
          autoCategorizationEnabled: false,
          tags: [],
        );

        parsedPayments.add(payment);
      }

      if (parsedPayments.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'No valid transactions found. Skipped $skippedRows rows.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      List<Payment> newTransactions = [];
      List<Payment> updatedTransactions = [];
      List<Payment> localOnlyTransactions = List.from(_payments);

      if (_payments.isEmpty) {
        newTransactions = List.from(parsedPayments);
      } else {
        for (var csvPayment in parsedPayments) {
          Payment? match;
          for (var local in _payments) {
            if (_isSameTransaction(local, csvPayment)) {
              match = local;
              break;
            }
          }

          if (match != null) {
            // Copy the existing ID to the CSV payment for update
            csvPayment = Payment(
              id: match.id, // Use existing ID
              account: csvPayment.account,
              category: csvPayment.category,
              amount: csvPayment.amount,
              type: csvPayment.type,
              datetime: csvPayment.datetime,
              title: csvPayment.title,
              description: csvPayment.description,
              autoCategorizationEnabled: csvPayment.autoCategorizationEnabled,
              tags: csvPayment.tags,
            );
            updatedTransactions.add(csvPayment);
            localOnlyTransactions.remove(match);
          } else {
            newTransactions.add(csvPayment);
          }
        }
      }

      bool? proceed = false;
      if (context.mounted) {
        proceed = await _showImportSummaryDialog(
          context,
          newTransactions: newTransactions,
          updatedTransactions: updatedTransactions,
          localOnlyTransactions: localOnlyTransactions,
          skippedRows: skippedRows,
        );
      }

      if (proceed != true) {
        return;
      }

      // Save new transactions (database will assign IDs)
      for (var payment in newTransactions) {
        await _paymentDao.create(payment);
      }

      // Update existing transactions (already have IDs)
      for (var payment in updatedTransactions) {
        if (payment.id != null) {
          await _paymentDao.update(payment);
        }
      }

      if (localOnlyTransactions.isNotEmpty && context.mounted) {
        bool? deleteLocal = await _confirmDeleteLocalTransactions(
          context,
          localOnlyTransactions.length,
        );

        if (deleteLocal == true) {
          for (var payment in localOnlyTransactions) {
            if (payment.id != null) {
              await _paymentDao.deleteTransaction(payment.id!);
            }
          }
        }
      }

      await _fetchTransactions();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Import completed! ${newTransactions.length} new, ${updatedTransactions.length} updated${skippedRows > 0 ? ", $skippedRows skipped" : ""}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error importing CSV: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing CSV: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  bool _isSameTransaction(Payment local, Payment csvPayment) {
    final amountEqual = (local.amount - csvPayment.amount).abs() < 0.01;
    final sameType = local.type == csvPayment.type;
    final sameTitle = local.title.trim().toLowerCase() ==
        csvPayment.title.trim().toLowerCase();
    final sameDay = local.datetime.year == csvPayment.datetime.year &&
        local.datetime.month == csvPayment.datetime.month &&
        local.datetime.day == csvPayment.datetime.day;

    return amountEqual && sameType && sameTitle && sameDay;
  }

  Future<bool?> _showImportSummaryDialog(
    BuildContext context, {
    required List<Payment> newTransactions,
    required List<Payment> updatedTransactions,
    required List<Payment> localOnlyTransactions,
    required int skippedRows,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.summarize, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              "Import Summary",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow(
              icon: Icons.add_circle,
              color: Colors.green,
              label: "New Transactions",
              count: newTransactions.length,
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              icon: Icons.update,
              color: Colors.blue,
              label: "Updated Transactions",
              count: updatedTransactions.length,
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              icon: Icons.phone_android,
              color: Colors.orange,
              label: "Local-Only Transactions",
              count: localOnlyTransactions.length,
            ),
            if (skippedRows > 0) ...[
              const SizedBox(height: 12),
              _buildSummaryRow(
                icon: Icons.warning_amber,
                color: Colors.red,
                label: "Skipped Rows (Invalid)",
                count: skippedRows,
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "Do you want to proceed with this import?",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text("Proceed"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required Color color,
    required String label,
    required int count,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Future<bool?> _confirmDeleteLocalTransactions(
    BuildContext context,
    int count,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text("Delete Local Transactions?"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "There are $count transaction(s) in your local data that are not present in the CSV file.",
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                "Would you like to delete these local transactions?",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Keep Them"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  List<double> _calculateMonthlyExpenses(List<Payment> payments) {
    final List<double> monthly = List.generate(12, (_) => 0.0);

    for (var p in payments) {
      if (p.type == PaymentType.debit) {
        monthly[p.datetime.month - 1] += p.amount;
      }
    }

    return monthly;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Home",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: const Text(
                'Import CSV File',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Import transactions with flexible column mapping',
                style: TextStyle(fontSize: 12.0, color: Colors.grey),
              ),
              onTap: () async {
                Navigator.pop(context);
                await importPaymentsFromCSV(context);
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildTagsStrip(context),
          Container(
            margin:
                const EdgeInsets.only(left: 15, right: 15, bottom: 15, top: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Hi! Good ${greeting()}"),
                BlocConsumer<AppCubit, AppState>(
                    listener: (context, state) {},
                    builder: (context, state) => Text(
                          state.username ?? "Guest",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ))
              ],
            ),
          ),
          AccountsSlider(
            accounts: _accounts,
            onAccountSelected: onAccountSelected,
          ),
          const SizedBox(
            height: 15,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(children: [
              const Text("Payments",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
              const Expanded(child: SizedBox()),
              MaterialButton(
                onPressed: () {
                  handleChooseDateRange();
                },
                height: double.minPositive,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                child: Row(
                  children: [
                    Text(
                      "${DateFormat("dd MMM").format(_range.start)} - ${DateFormat("dd MMM").format(_range.end)}",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Icon(Icons.arrow_drop_down_outlined)
                  ],
                ),
              ),
            ]),
          ),
          EasyInfiniteDateTimeLine(
            firstDate: DateTime(2023),
            focusDate: _focusDate,
            lastDate: DateTime.now(),
            showTimelineHeader: false,
            onDateChange: (selectedDate) {
              setState(() {
                _focusDate = selectedDate;
                _range = DateTimeRange(start: selectedDate, end: selectedDate);
                _fetchTransactions();
              });
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                    child: InkWell(
                  onTap: () {
                    setState(() {
                      _showingIncomeOnly = !_showingIncomeOnly;
                      _showingExpenseOnly = false;
                      _fetchTransactions();
                    });
                  },
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: ThemeColors.success.withOpacity(0.2),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text.rich(TextSpan(children: [
                              TextSpan(
                                  text: "Income",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ])),
                            const SizedBox(
                              height: 5,
                            ),
                            CurrencyText(
                              _income,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: ThemeColors.success),
                            )
                          ],
                        ),
                      )),
                )),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                    child: InkWell(
                  onTap: () {
                    setState(() {
                      _showingExpenseOnly = !_showingExpenseOnly;
                      _showingIncomeOnly = false;
                      _fetchTransactions();
                    });
                  },
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: ThemeColors.error.withOpacity(0.2),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text.rich(TextSpan(children: [
                              TextSpan(
                                  text: "Expense",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ])),
                            const SizedBox(
                              height: 5,
                            ),
                            CurrencyText(
                              _expense,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: ThemeColors.error),
                            )
                          ],
                        ),
                      )),
                )),
              ],
            ),
          ),
          ExpensePieChart(
            key: ValueKey<DateTimeRange>(_range),
            onCategorySelected: onCategorySelected,
            range: _range,
          ),
          ExpenseLineChart(
            monthlyExpenses: _monthlyExpenses,
          ),
          _payments.isNotEmpty
              ? ListView.separated(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemBuilder: (BuildContext context, index) {
                    return PaymentListItem(
                        payment: _payments[index],
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (builder) => PaymentForm(
                                    type: _payments[index].type,
                                    payment: _payments[index],
                                  )));
                        });
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    return Container(
                      width: double.infinity,
                      color: Colors.grey.withAlpha(25),
                      height: 1,
                      margin: const EdgeInsets.only(left: 75, right: 20),
                    );
                  },
                  itemCount: _payments.length,
                )
              : Container(
                  padding: const EdgeInsets.symmetric(vertical: 25),
                  alignment: Alignment.center,
                  child: const Text("No payments!"),
                ),
        ],
      )),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(width: 10.0),
          FloatingActionButton(
            heroTag: "Share",
            onPressed: () => _showExportOptions(context),
            backgroundColor: ThemeColors.error,
            child: const Icon(Icons.share),
          ),
          const SizedBox(width: 16.0),
          FloatingActionButton(
            heroTag: "income",
            onPressed: () => openAddPaymentPage(PaymentType.debit),
            backgroundColor: ThemeColors.success,
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 10.0),
          FloatingActionButton(
            heroTag: "expense",
            onPressed: () => openAddPaymentPage(PaymentType.debit),
            backgroundColor: ThemeColors.error,
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }

  void toggleAllTags() {
    setState(() {
      allSelected = !allSelected;
      selectedTags = List<bool>.filled(tags.length, allSelected);
      _fetchTransactions();
    });
  }

  void toggleTagSelection(int index, bool value) {
    setState(() {
      selectedTags[index] = value;
      allSelected = selectedTags.every((selected) => selected);
      _fetchTransactions();
    });
  }

  Widget buildTagsStrip(BuildContext context) {
    return tags.isEmpty
        ? const SizedBox()
        : Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black45)),
                      child: Row(
                        children: [
                          InkWell(
                            child: Icon(allSelected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank),
                            onTap: () {
                              toggleAllTags();
                            },
                          ),
                          const Text(
                            'Select All',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: List.generate(tags.length, (index) {
                        final tag = tags[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black45)),
                          child: Row(
                            children: [
                              InkWell(
                                child: Icon(selectedTags[index]
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank),
                                onTap: () {
                                  toggleTagSelection(
                                      index, !selectedTags[index]);
                                },
                              ),
                              Text(
                                tag.name,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 10,
              ),
            ],
          );
  }
}
