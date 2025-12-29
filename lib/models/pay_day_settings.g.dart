// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pay_day_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PayDaySettingsAdapter extends TypeAdapter<PayDaySettings> {
  @override
  final int typeId = 5;

  @override
  PayDaySettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PayDaySettings(
      userId: fields[0] as String,
      lastPayAmount: fields[1] as double?,
      payFrequency: fields[2] as String,
      payDayOfMonth: fields[3] as int?,
      payDayOfWeek: fields[4] as int?,
      lastPayDate: fields[5] as DateTime?,
      defaultAccountId: fields[6] as String?,
      nextPayDate: fields[7] as DateTime?,
      expectedPayAmount: fields[8] as double?,
      adjustForWeekends: fields[9] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, PayDaySettings obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.lastPayAmount)
      ..writeByte(2)
      ..write(obj.payFrequency)
      ..writeByte(3)
      ..write(obj.payDayOfMonth)
      ..writeByte(4)
      ..write(obj.payDayOfWeek)
      ..writeByte(5)
      ..write(obj.lastPayDate)
      ..writeByte(6)
      ..write(obj.defaultAccountId)
      ..writeByte(7)
      ..write(obj.nextPayDate)
      ..writeByte(8)
      ..write(obj.expectedPayAmount)
      ..writeByte(9)
      ..write(obj.adjustForWeekends);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayDaySettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
