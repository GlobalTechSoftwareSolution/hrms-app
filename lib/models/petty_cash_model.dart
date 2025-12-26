class PettyCashTransaction {
  final int id;
  final String email;
  final DateTime date;
  final String description;
  final String category;
  final String transactionType; // "Credit" or "Debit"
  final String amount;
  final String balance;
  final String? voucherNo;
  final String status;
  final String? remarks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;
  final String? approvedBy;

  PettyCashTransaction({
    required this.id,
    required this.email,
    required this.date,
    required this.description,
    required this.category,
    required this.transactionType,
    required this.amount,
    required this.balance,
    required this.status,
    this.voucherNo,
    this.remarks,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    this.approvedBy,
  });

  factory PettyCashTransaction.fromJson(Map<String, dynamic> json) {
    return PettyCashTransaction(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      transactionType: json['transaction_type'] ?? 'Debit',
      amount: json['amount'] ?? '0',
      balance: json['balance'] ?? '0',
      voucherNo: json['voucher_no'],
      status: json['status'] ?? 'pending',
      remarks: json['remarks'],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'])
          : null,
      approvedBy: json['approved_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'date': date.toIso8601String().split('T')[0],
      'description': description,
      'category': category,
      'transaction_type': transactionType,
      'amount': amount,
      'balance': balance,
      'voucher_no': voucherNo,
      'status': status,
      'remarks': remarks,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by': approvedBy,
    };
  }
}

class PettyCashMonthlyFund {
  final String month;
  final int year;
  final double allocatedAmount;
  final double spentAmount;
  final double remainingAmount;

  PettyCashMonthlyFund({
    required this.month,
    required this.year,
    required this.allocatedAmount,
    required this.spentAmount,
    required this.remainingAmount,
  });

  double get totalCredits => allocatedAmount;
  double get totalDebits => spentAmount;
  double get currentBalance => remainingAmount;
}
