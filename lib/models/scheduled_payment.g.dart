// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_payment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScheduledPaymentAdapter extends TypeAdapter<ScheduledPayment> {
  @override
  final int typeId = 4;

  @override
  ScheduledPayment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduledPayment(
      id: fields[0] as String,
      userId: fields[1] as String,
      envelopeId: fields[2] as String?,
      groupId: fields[3] as String?,
      name: fields[4] as String,
      description: fields[5] as String?,
      amount: fields[6] as double,
      startDate: fields[7] as DateTime,
      frequencyValue: fields[8] as int,
      frequencyUnit: fields[9] as PaymentFrequencyUnit,
      colorName: fields[10] as String,
      colorValue: fields[11] as int,
      isAutomatic: fields[12] as bool,
      lastExecuted: fields[13] as DateTime?,
      createdAt: fields[14] as DateTime,
      paymentType: fields[15] as ScheduledPaymentType,
      paymentEnvelopeId: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduledPayment obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.envelopeId)
      ..writeByte(3)
      ..write(obj.groupId)
      ..writeByte(4)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.amount)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.frequencyValue)
      ..writeByte(9)
      ..write(obj.frequencyUnit)
      ..writeByte(10)
      ..write(obj.colorName)
      ..writeByte(11)
      ..write(obj.colorValue)
      ..writeByte(12)
      ..write(obj.isAutomatic)
      ..writeByte(13)
      ..write(obj.lastExecuted)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.paymentType)
      ..writeByte(16)
      ..write(obj.paymentEnvelopeId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduledPaymentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PaymentFrequencyUnitAdapter extends TypeAdapter<PaymentFrequencyUnit> {
  @override
  final int typeId = 102;

  @override
  PaymentFrequencyUnit read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PaymentFrequencyUnit.days;
      case 1:
        return PaymentFrequencyUnit.weeks;
      case 2:
        return PaymentFrequencyUnit.months;
      case 3:
        return PaymentFrequencyUnit.years;
      default:
        return PaymentFrequencyUnit.days;
    }
  }

  @override
  void write(BinaryWriter writer, PaymentFrequencyUnit obj) {
    switch (obj) {
      case PaymentFrequencyUnit.days:
        writer.writeByte(0);
        break;
      case PaymentFrequencyUnit.weeks:
        writer.writeByte(1);
        break;
      case PaymentFrequencyUnit.months:
        writer.writeByte(2);
        break;
      case PaymentFrequencyUnit.years:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentFrequencyUnitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ScheduledPaymentTypeAdapter extends TypeAdapter<ScheduledPaymentType> {
  @override
  final int typeId = 103;

  @override
  ScheduledPaymentType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ScheduledPaymentType.fixedAmount;
      case 1:
        return ScheduledPaymentType.envelopeBalance;
      default:
        return ScheduledPaymentType.fixedAmount;
    }
  }

  @override
  void write(BinaryWriter writer, ScheduledPaymentType obj) {
    switch (obj) {
      case ScheduledPaymentType.fixedAmount:
        writer.writeByte(0);
        break;
      case ScheduledPaymentType.envelopeBalance:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduledPaymentTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
