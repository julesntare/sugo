import 'package:hive/hive.dart';
import 'budget.dart';
import 'budget_item.dart';

class BudgetAdapter extends TypeAdapter<Budget> {
  @override
  final int typeId = 2;

  @override
  Budget read(BinaryReader reader) {
    final id = reader.readString();
    final title = reader.readString();
    final amount = reader.readDouble();
    final start = DateTime.parse(reader.readString());
    final end = DateTime.parse(reader.readString());
    final itemsCount = reader.readInt();
    final items = <BudgetItem>[];
    for (var i = 0; i < itemsCount; i++) {
      // read item as map-like sequence
      final itemId = reader.readString();
      final itemName = reader.readString();
      final hasMonthly = reader.readBool();
      final monthly = hasMonthly ? reader.readDouble() : null;
      final hasOneTime = reader.readBool();
      final oneTime = hasOneTime ? reader.readDouble() : null;
      final hasOneTimeMonth = reader.readBool();
      final oneTimeMonth = hasOneTimeMonth ? reader.readString() : null;
      items.add(
        BudgetItem(
          id: itemId,
          name: itemName,
          monthlyAmount: monthly,
          oneTimeAmount: oneTime,
          oneTimeMonth: oneTimeMonth,
        ),
      );
    }
    final checklistCount = reader.readInt();
    final checklist = <String, Map<String, bool>>{};
    for (var i = 0; i < checklistCount; i++) {
      final monthKey = reader.readString();
      final mapCount = reader.readInt();
      final map = <String, bool>{};
      for (var j = 0; j < mapCount; j++) {
        final itemId = reader.readString();
        final checked = reader.readBool();
        map[itemId] = checked;
      }
      checklist[monthKey] = map;
    }
    return Budget(
      id: id,
      title: title,
      amount: amount,
      start: start,
      end: end,
      items: items,
      checklist: checklist,
    );
  }

  @override
  void write(BinaryWriter writer, Budget obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeDouble(obj.amount);
    writer.writeString(obj.start.toIso8601String());
    writer.writeString(obj.end.toIso8601String());
    writer.writeInt(obj.items.length);
    for (final it in obj.items) {
      writer.writeString(it.id);
      writer.writeString(it.name);
      if (it.monthlyAmount != null) {
        writer.writeBool(true);
        writer.writeDouble(it.monthlyAmount!);
      } else {
        writer.writeBool(false);
      }
      if (it.oneTimeAmount != null) {
        writer.writeBool(true);
        writer.writeDouble(it.oneTimeAmount!);
      } else {
        writer.writeBool(false);
      }
      if (it.oneTimeMonth != null) {
        writer.writeBool(true);
        writer.writeString(it.oneTimeMonth!);
      } else {
        writer.writeBool(false);
      }
    }
    writer.writeInt(obj.checklist.length);
    obj.checklist.forEach((month, map) {
      writer.writeString(month);
      writer.writeInt(map.length);
      map.forEach((itemId, checked) {
        writer.writeString(itemId);
        writer.writeBool(checked);
      });
    });
  }
}
