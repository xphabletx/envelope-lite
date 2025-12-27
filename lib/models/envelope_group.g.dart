// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_group.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EnvelopeGroupAdapter extends TypeAdapter<EnvelopeGroup> {
  @override
  final int typeId = 2;

  @override
  EnvelopeGroup read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EnvelopeGroup(
      id: fields[0] as String,
      name: fields[1] as String,
      userId: fields[2] as String,
      emoji: fields[3] as String?,
      iconType: fields[4] as String?,
      iconValue: fields[5] as String?,
      iconColor: fields[6] as int?,
      colorIndex: fields[7] as int,
      payDayEnabled: fields[8] as bool,
      isShared: fields[9] as bool,
      createdAt: fields[10] as DateTime?,
      updatedAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, EnvelopeGroup obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.emoji)
      ..writeByte(4)
      ..write(obj.iconType)
      ..writeByte(5)
      ..write(obj.iconValue)
      ..writeByte(6)
      ..write(obj.iconColor)
      ..writeByte(7)
      ..write(obj.colorIndex)
      ..writeByte(8)
      ..write(obj.payDayEnabled)
      ..writeByte(9)
      ..write(obj.isShared)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvelopeGroupAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
