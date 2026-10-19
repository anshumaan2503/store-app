import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/src/store_page/domains/models/store_items_model.dart';
import 'package:store_app/src/store_page/domains/models/store_issue_model.dart';
import 'package:store_app/src/store_page/domains/models/store_scrap_model.dart';
import 'package:store_app/src/store/domains/models/store_item_model.dart';

void main() {
  group('Store Module Model Deserialization & Defensive Parsing Verification', () {
    test('1. StoreItemsModel deserializes standard JSON correctly', () {
      final json = {
        '_id': '69c62a769827412ba0bc8d85',
        'itemCode': 'ITEM-001',
        'isScrap': false,
        'itemName': 'Steel Bolt',
        'categoryLabel': 'Fasteners',
        'unit': 'PCS',
        'description': 'M8 Bolt',
        'maxCapacity': 100,
        'totalStockQuantity': 50,
        'stockAvailableQuantity': 30,
        'stockIssueQuantity': 10,
        'stockissueCompleted': 5,
        'stockscrapQuantity': 5,
        'imageUrl': 'http://example.com/img.jpg',
      };

      final model = StoreItemsModel.fromMap(json);
      expect(model.id, equals('69c62a769827412ba0bc8d85'));
      expect(model.totalStockQuantity, equals(50));
    });

    test('2. StoreScrapModel handles itemQuantity as int without TypeError (STORE-004)', () {
      final json = {
        '_id': '69c62a769827412ba0bc8d85',
        'itemId': 'ITEM-1',
        'itemName': 'Steel Pipe',
        'itemCode': 'CODE-1',
        'roomId': 'ROOM-1',
        'roomCode': 'R1',
        'rackId': 'RACK-1',
        'rackCode': 'RK1',
        'itemQuantity': 5, // int returned from backend JSON
        'remark': 'Damaged',
        'createdBy': 'USR1',
        'createdByName': 'John',
        'createdAt': '2026-08-30T07:00:00.000Z',
      };

      final model = StoreScrapModel.fromMap(json);
      expect(model.itemQuantity, equals(5.0));
    });

    test('3. StoreItem.fromMap handles double quantities in JSON without TypeError (STORE-004)', () {
      final json = {
        '_id': '69c62a769827412ba0bc8d85',
        'name': 'Hex Nut',
        'description': 'M6 Nut',
        'category': 'Fasteners',
        'totalStockQuantity': 50.0, // double returned from backend
        'stockAvailableQuantity': 50.0,
        'stockIssueQuantity': 0.0,
        'stockissueCompleted': 0.0,
        'stockscrapQuantity': 0.0,
        'stockPlace': [],
        'unit': 'PCS',
        'imageUrl': '',
        'createdBy': 'USR1',
        'isBag': false,
        'maxQuantity': 100,
        'createdAt': '2026-08-30T07:00:00.000Z',
        'updatedAt': '2026-08-30T07:00:00.000Z',
      };

      final item = StoreItem.fromMap(json);
      expect(item.totalStockQuantity, equals(50));
    });

    test('4. IssueLine.fromJson handles double/string quantities safely (STORE-004)', () {
      final json = {
        'itemId': '69c62a769827412ba0bc8d85',
        'itemName': 'Widget',
        'requestedQty': 10.0, // double
        'approvedQty': "10", // string
        'issuedQty': 0,
        'returnQty': 0,
        'unit': 'PCS',
        'scrapQty': 0,
      };

      final line = IssueLine.fromJson(json);
      expect(line.requestedQty, equals(10));
      expect(line.approvedQty, equals(10));
    });

    test(r'5. StoreItemsModel.fromMap handles nested $oid and id keys safely (STORE-005)', () {
      final jsonNestedOid = {
        '_id': {r'$oid': '69c62a769827412ba0bc8d85'},
        'itemCode': 'ITEM-001',
        'isScrap': false,
        'itemName': 'Steel Bolt',
        'categoryLabel': 'Fasteners',
        'unit': 'PCS',
        'description': 'M8 Bolt',
        'maxCapacity': 100,
        'totalStockQuantity': 50,
        'stockAvailableQuantity': 30,
        'stockIssueQuantity': 10,
        'stockissueCompleted': 5,
        'stockscrapQuantity': 5,
        'imageUrl': 'http://example.com/img.jpg',
      };

      final modelOid = StoreItemsModel.fromMap(jsonNestedOid);
      expect(modelOid.id, equals('69c62a769827412ba0bc8d85'));

      final jsonWithId = {
        'id': '69c62a769827412ba0bc8d85',
        'itemCode': 'ITEM-001',
        'isScrap': false,
        'itemName': 'Steel Bolt',
        'categoryLabel': 'Fasteners',
        'unit': 'PCS',
        'description': 'M8 Bolt',
        'maxCapacity': 100,
        'totalStockQuantity': 50,
        'stockAvailableQuantity': 30,
        'stockIssueQuantity': 10,
        'stockissueCompleted': 5,
        'stockscrapQuantity': 5,
        'imageUrl': 'http://example.com/img.jpg',
      };

      final modelId = StoreItemsModel.fromMap(jsonWithId);
      expect(modelId.id, equals('69c62a769827412ba0bc8d85'));
    });
  });
}
