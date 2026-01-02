// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EnvelopeAdapter extends TypeAdapter<Envelope> {
  @override
  final int typeId = 0;

  @override
  Envelope read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Envelope(
      id: fields[0] as String,
      name: fields[1] as String,
      userId: fields[2] as String,
      currentAmount: fields[3] as double,
      targetAmount: fields[4] as double?,
      targetDate: fields[5] as DateTime?,
      groupId: fields[6] as String?,
      emoji: fields[7] as String?,
      iconType: fields[8] as String?,
      iconValue: fields[9] as String?,
      iconColor: fields[10] as int?,
      subtitle: fields[11] as String?,
      autoFillEnabled: fields[12] as bool,
      autoFillAmount: fields[13] as double?,
      isShared: fields[14] as bool,
      linkedAccountId: fields[15] as String?,
      isDebtEnvelope: fields[20] as bool,
      startingDebt: fields[21] as double?,
      termStartDate: fields[22] as DateTime?,
      termMonths: fields[23] as int?,
      monthlyPayment: fields[24] as double?,
      isSynced: fields[25] as bool?,
      lastUpdated: fields[26] as DateTime?,
      createdAt: fields[27] as DateTime?,
      targetStartDateType: fields[28] as TargetStartDateType?,
      customTargetStartDate: fields[29] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Envelope obj) {
    writer
      ..writeByte(26)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.currentAmount)
      ..writeByte(4)
      ..write(obj.targetAmount)
      ..writeByte(5)
      ..write(obj.targetDate)
      ..writeByte(6)
      ..write(obj.groupId)
      ..writeByte(7)
      ..write(obj.emoji)
      ..writeByte(8)
      ..write(obj.iconType)
      ..writeByte(9)
      ..write(obj.iconValue)
      ..writeByte(10)
      ..write(obj.iconColor)
      ..writeByte(11)
      ..write(obj.subtitle)
      ..writeByte(12)
      ..write(obj.autoFillEnabled)
      ..writeByte(13)
      ..write(obj.autoFillAmount)
      ..writeByte(14)
      ..write(obj.isShared)
      ..writeByte(15)
      ..write(obj.linkedAccountId)
      ..writeByte(20)
      ..write(obj.isDebtEnvelope)
      ..writeByte(21)
      ..write(obj.startingDebt)
      ..writeByte(22)
      ..write(obj.termStartDate)
      ..writeByte(23)
      ..write(obj.termMonths)
      ..writeByte(24)
      ..write(obj.monthlyPayment)
      ..writeByte(25)
      ..write(obj.isSynced)
      ..writeByte(26)
      ..write(obj.lastUpdated)
      ..writeByte(27)
      ..write(obj.createdAt)
      ..writeByte(28)
      ..write(obj.targetStartDateType)
      ..writeByte(29)
      ..write(obj.customTargetStartDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvelopeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TargetStartDateTypeAdapter extends TypeAdapter<TargetStartDateType> {
  @override
  final int typeId = 7;

  @override
  TargetStartDateType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TargetStartDateType.fromToday;
      case 1:
        return TargetStartDateType.fromEnvelopeCreation;
      case 2:
        return TargetStartDateType.customDate;
      default:
        return TargetStartDateType.fromToday;
    }
  }

  @override
  void write(BinaryWriter writer, TargetStartDateType obj) {
    switch (obj) {
      case TargetStartDateType.fromToday:
        writer.writeByte(0);
        break;
      case TargetStartDateType.fromEnvelopeCreation:
        writer.writeByte(1);
        break;
      case TargetStartDateType.customDate:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TargetStartDateTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
