// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 3;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: fields[0] as String,
      envelopeId: fields[1] as String,
      type: fields[2] as TransactionType,
      amount: fields[3] as double,
      date: fields[4] as DateTime,
      description: fields[5] as String,
      userId: fields[6] as String,
      transferPeerEnvelopeId: fields[8] as String?,
      transferLinkId: fields[9] as String?,
      transferDirection: fields[10] as TransferDirection?,
      ownerId: fields[11] as String?,
      sourceOwnerId: fields[12] as String?,
      targetOwnerId: fields[13] as String?,
      sourceEnvelopeName: fields[14] as String?,
      targetEnvelopeName: fields[15] as String?,
      sourceOwnerDisplayName: fields[16] as String?,
      targetOwnerDisplayName: fields[17] as String?,
      isFuture: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.envelopeId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.userId)
      ..writeByte(7)
      ..write(obj.isFuture)
      ..writeByte(8)
      ..write(obj.transferPeerEnvelopeId)
      ..writeByte(9)
      ..write(obj.transferLinkId)
      ..writeByte(10)
      ..write(obj.transferDirection)
      ..writeByte(11)
      ..write(obj.ownerId)
      ..writeByte(12)
      ..write(obj.sourceOwnerId)
      ..writeByte(13)
      ..write(obj.targetOwnerId)
      ..writeByte(14)
      ..write(obj.sourceEnvelopeName)
      ..writeByte(15)
      ..write(obj.targetEnvelopeName)
      ..writeByte(16)
      ..write(obj.sourceOwnerDisplayName)
      ..writeByte(17)
      ..write(obj.targetOwnerDisplayName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransactionTypeAdapter extends TypeAdapter<TransactionType> {
  @override
  final int typeId = 100;

  @override
  TransactionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionType.deposit;
      case 1:
        return TransactionType.withdrawal;
      case 2:
        return TransactionType.transfer;
      case 3:
        return TransactionType.scheduledPayment;
      default:
        return TransactionType.deposit;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionType obj) {
    switch (obj) {
      case TransactionType.deposit:
        writer.writeByte(0);
        break;
      case TransactionType.withdrawal:
        writer.writeByte(1);
        break;
      case TransactionType.transfer:
        writer.writeByte(2);
        break;
      case TransactionType.scheduledPayment:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransferDirectionAdapter extends TypeAdapter<TransferDirection> {
  @override
  final int typeId = 104;

  @override
  TransferDirection read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransferDirection.in_;
      case 1:
        return TransferDirection.out_;
      default:
        return TransferDirection.in_;
    }
  }

  @override
  void write(BinaryWriter writer, TransferDirection obj) {
    switch (obj) {
      case TransferDirection.in_:
        writer.writeByte(0);
        break;
      case TransferDirection.out_:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransferDirectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
