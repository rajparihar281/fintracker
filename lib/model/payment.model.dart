import 'package:fintracker/model/account.model.dart';
import 'package:fintracker/model/category.model.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

enum PaymentType { debit, credit }

class Payment {
  int? id;
  Account account;
  Category category;
  double amount;
  PaymentType type;
  DateTime datetime;
  String title;
  String description;
  bool autoCategorizationEnabled;
  List<int> tags;
  List<String> imagePaths;

  Payment({
    this.id,
    required this.account,
    required this.category,
    required this.amount,
    required this.type,
    required this.datetime,
    required this.title,
    required this.description,
    required this.autoCategorizationEnabled,
    this.tags = const [],
    this.imagePaths = const [],
  });

  factory Payment.fromJson(Map<String, dynamic> data) {
    List<String> imagePathsList = [];
    if (data["imagePaths"] != null && data["imagePaths"].isNotEmpty) {
      try {
        imagePathsList = List<String>.from(jsonDecode(data["imagePaths"]));
      } catch (e) {
        imagePathsList = [];
      }
    }
    
    return Payment(
      id: data["id"],
      title: data["title"] ?? "",
      description: data["description"] ?? "",
      account: Account.fromJson(data["account"]),
      category: Category.fromJson(data["category"]),
      amount: data["amount"],
      type: data["type"] == "CR" ? PaymentType.credit : PaymentType.debit,
      datetime: DateTime.parse(data["datetime"]),
      autoCategorizationEnabled: data["autoCategorizationEnabled"],
      tags: List<int>.from(data["tags"] ?? []),
      imagePaths: imagePathsList,
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "description": description,
    "account": account.id,
    "category": category.id,
    "amount": amount,
    "datetime": DateFormat('yyyy-MM-dd kk:mm:ss').format(datetime),
    "type": type == PaymentType.credit ? "CR" : "DR",
    "autoCategorizationEnabled": autoCategorizationEnabled,
    "tags": tags,
    "imagePaths": imagePaths.isNotEmpty ? jsonEncode(imagePaths) : null,
  };
}

