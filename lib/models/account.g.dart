// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AccountAdapter extends TypeAdapter<Account> {
  @override
  final int typeId = 1;

  @override
  Account read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Account(
      id: fields[0] as String,
      name: fields[1] as String,
      currentBalance: fields[2] as double,
      userId: fields[3] as String,
      emoji: fields[4] as String?,
      colorName: fields[5] as String?,
      createdAt: fields[6] as DateTime,
      lastUpdated: fields[7] as DateTime,
      isDefault: fields[8] as bool,
      isShared: fields[9] as bool,
      workspaceId: fields[10] as String?,
      iconType: fields[11] as String?,
      iconValue: fields[12] as String?,
      iconColor: fields[13] as int?,
      accountType: fields[14] as AccountType,
      creditLimit: fields[15] as double?,
      payDayAutoFillAmount: fields[17] as double?,
      isSynced: fields[18] as bool?,
      sourceAccountId: fields[19] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Account obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.currentBalance)
      ..writeByte(3)
      ..write(obj.userId)
      ..writeByte(4)
      ..write(obj.emoji)
      ..writeByte(5)
      ..write(obj.colorName)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.lastUpdated)
      ..writeByte(8)
      ..write(obj.isDefault)
      ..writeByte(9)
      ..write(obj.isShared)
      ..writeByte(10)
      ..write(obj.workspaceId)
      ..writeByte(11)
      ..write(obj.iconType)
      ..writeByte(12)
      ..write(obj.iconValue)
      ..writeByte(13)
      ..write(obj.iconColor)
      ..writeByte(14)
      ..write(obj.accountType)
      ..writeByte(15)
      ..write(obj.creditLimit)
      ..writeByte(16)
      ..write(obj._payDayAutoFillEnabled)
      ..writeByte(17)
      ..write(obj.payDayAutoFillAmount)
      ..writeByte(18)
      ..write(obj.isSynced)
      ..writeByte(19)
      ..write(obj.sourceAccountId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AccountTypeAdapter extends TypeAdapter<AccountType> {
  @override
  final int typeId = 101;

  @override
  AccountType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AccountType.bankAccount;
      case 1:
        return AccountType.creditCard;
      default:
        return AccountType.bankAccount;
    }
  }

  @override
  void write(BinaryWriter writer, AccountType obj) {
    switch (obj) {
      case AccountType.bankAccount:
        writer.writeByte(0);
        break;
      case AccountType.creditCard:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
