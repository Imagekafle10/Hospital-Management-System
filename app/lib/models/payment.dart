class Payment {
  final int id;
  final int appointmentId;
  final int patientId;
  final double amount;
  final String method;
  final String status;
  final String transactionUuid;
  final String? gatewayReference;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? patientName;
  final String? doctorName;

  Payment({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.amount,
    required this.method,
    required this.status,
    required this.transactionUuid,
    this.gatewayReference,
    required this.createdAt,
    this.paidAt,
    this.patientName,
    this.doctorName,
  });

  bool get isPaid => status == 'Success';

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as int,
        appointmentId: json['appointmentId'] as int,
        patientId: json['patientId'] as int,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        method: json['method'] as String? ?? '',
        status: json['status'] as String? ?? 'Pending',
        transactionUuid: json['transactionUuid'] as String? ?? '',
        gatewayReference: json['gatewayReference'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        paidAt: json['paidAt'] != null
            ? DateTime.tryParse(json['paidAt'] as String)
            : null,
        patientName: json['patientName'] as String?,
        doctorName: json['doctorName'] as String?,
      );
}
