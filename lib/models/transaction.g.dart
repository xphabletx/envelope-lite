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
      isSynced: fields[18] as bool?,
      lastUpdated: fields[19] as DateTime?,
      accountId: fields[20] as String?,
      impact: fields[21] as TransactionImpact?,
      direction: fields[22] as TransactionDirection?,
      sourceId: fields[23] as String?,
      sourceType: fields[24] as SourceType?,
      destinationId: fields[25] as String?,
      destinationType: fields[26] as SourceType?,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(27)
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
      ..write(obj.targetOwnerDisplayName)
      ..writeByte(18)
      ..write(obj.isSynced)
      ..writeByte(19)
      ..write(obj.lastUpdated)
      ..writeByte(20)
      ..write(obj.accountId)
      ..writeByte(21)
      ..write(obj.impact)
      ..writeByte(22)
      ..write(obj.direction)
      ..writeByte(23)
      ..write(obj.sourceId)
      ..writeByte(24)
      ..write(obj.sourceType)
      ..writeByte(25)
      ..write(obj.destinationId)
      ..writeByte(26)
      ..write(obj.destinationType);
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

class TransactionImpactAdapter extends TypeAdapter<TransactionImpact> {
  @override
  final int typeId = 105;

  @override
  TransactionImpact read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionImpact.external;
      case 1:
        return TransactionImpact.internal;
      default:
        return TransactionImpact.external;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionImpact obj) {
    switch (obj) {
      case TransactionImpact.external:
        writer.writeByte(0);
        break;
      case TransactionImpact.internal:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionImpactAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransactionDirectionAdapter extends TypeAdapter<TransactionDirection> {
  @override
  final int typeId = 106;

  @override
  TransactionDirection read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionDirection.inflow;
      case 1:
        return TransactionDirection.outflow;
      case 2:
        return TransactionDirection.move;
      default:
        return TransactionDirection.inflow;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionDirection obj) {
    switch (obj) {
      case TransactionDirection.inflow:
        writer.writeByte(0);
        break;
      case TransactionDirection.outflow:
        writer.writeByte(1);
        break;
      case TransactionDirection.move:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionDirectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SourceTypeAdapter extends TypeAdapter<SourceType> {
  @override
  final int typeId = 107;

  @override
  SourceType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SourceType.envelope;
      case 1:
        return SourceType.account;
      case 2:
        return SourceType.external;
      default:
        return SourceType.envelope;
    }
  }

  @override
  void write(BinaryWriter writer, SourceType obj) {
    switch (obj) {
      case SourceType.envelope:
        writer.writeByte(0);
        break;
      case SourceType.account:
        writer.writeByte(1);
        break;
      case SourceType.external:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceTypeAdapter &&
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
