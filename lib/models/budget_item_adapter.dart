import 'package:hive/hive.dart';
import 'budget_item.dart';

class BudgetItemAdapter extends TypeAdapter<BudgetItem> {
  @override
  final int typeId = 1;

  @override
  BudgetItem read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final monthlyAmount = reader.readBool() ? reader.readDouble() : null;
    final oneTimeAmount = reader.readBool() ? reader.readDouble() : null;
    final hasOneTimeMonth = reader.readBool();
    final oneTimeMonth = hasOneTimeMonth ? reader.readString() : null;
    return BudgetItem(
      id: id,
      name: name,
      monthlyAmount: monthlyAmount,
      oneTimeAmount: oneTimeAmount,
      oneTimeMonth: oneTimeMonth,
    );
  }

  @override
  void write(BinaryWriter writer, BudgetItem obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    if (obj.monthlyAmount != null) {
      writer.writeBool(true);
      writer.writeDouble(obj.monthlyAmount!);
    } else {
      writer.writeBool(false);
    }
    if (obj.oneTimeAmount != null) {
      writer.writeBool(true);
      writer.writeDouble(obj.oneTimeAmount!);
    } else {
      writer.writeBool(false);
    }
    if (obj.oneTimeMonth != null) {
      writer.writeBool(true);
      writer.writeString(obj.oneTimeMonth!);
    } else {
      writer.writeBool(false);
    }
  }
}
