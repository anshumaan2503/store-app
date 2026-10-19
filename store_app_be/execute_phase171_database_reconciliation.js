const mongoose = require('mongoose');

async function reconcileDatabaseAndSyncIndexes() {
  console.log('====================================================');
  console.log(' PHASE 17.1 DATABASE RECONCILIATION & INDEX SYNC   ');
  console.log('====================================================\n');

  const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/store_app_live';
  await mongoose.connect(MONGO_URI);
  console.log(`[+] Connected to MongoDB: ${MONGO_URI}\n`);

  const db = mongoose.connection.db;

  // 1. SYNC MONGO INDEXES FOR IDEMPOTENCY AND INTEGRITY
  console.log('[1/2] Syncing Unique Indexes in MongoDB...');

  try {
    await db.collection('storereceives').createIndex(
      { requestId: 1 },
      { unique: true, partialFilterExpression: { requestId: { $gt: '' } } }
    );
    await db.collection('storereceives').createIndex(
      { recNo: 1 },
      { unique: true, partialFilterExpression: { recNo: { $gt: '' } } }
    );
    console.log('  [✓] storereceives indexes synced');

    await db.collection('storeitemscraps').createIndex(
      { requestId: 1 },
      { unique: true, partialFilterExpression: { requestId: { $gt: '' } } }
    );
    console.log('  [✓] storeitemscraps indexes synced');

    // Deduplicate any existing duplicate issNo in itemissues
    const duplicates = await db.collection('itemissues').aggregate([
      { $match: { issNo: { $gt: '' } } },
      { $group: { _id: '$issNo', ids: { $push: '$_id' }, count: { $sum: 1 } } },
      { $match: { count: { $gt: 1 } } }
    ]).toArray();

    for (const dup of duplicates) {
      const [keepId, ...deleteIds] = dup.ids;
      await db.collection('itemissues').deleteMany({ _id: { $in: deleteIds } });
      console.log(`  [Deduplicated] Removed ${deleteIds.length} duplicate itemissues records for issNo=${dup._id}`);
    }

    await db.collection('itemissues').createIndex(
      { requestId: 1 },
      { unique: true, partialFilterExpression: { requestId: { $gt: '' } } }
    );
    await db.collection('itemissues').createIndex(
      { issNo: 1 },
      { unique: true, partialFilterExpression: { issNo: { $gt: '' } } }
    );
    console.log('  [✓] itemissues indexes synced');

    await db.collection('itemrackqties').createIndex(
      { rackId: 1, itemId: 1 },
      { unique: true }
    );
    console.log('  [✓] itemrackqties unique index synced');
  } catch (indexErr) {
    console.error('  [!] Index creation warning:', indexErr.message);
  }


  // 2. RECONCILE ITEM STOCK LEDGERS FROM RACK QUANTITIES
  console.log('\n[2/2] Reconciling StoreItem Stock Ledgers...');

  const rackQties = await db.collection('itemrackqties').find({}).toArray();

  // Normalize IRQ internal equations and fix negative values
  for (const irq of rackQties) {
    let modified = false;
    const total = Math.max(0, irq.totalStockQuantity ?? 0);
    const issue = Math.max(0, irq.stockIssueQuantity ?? 0);
    const scrap = Math.max(0, irq.stockscrapQuantity ?? 0);
    const avail = Math.max(0, total - issue - scrap);

    const update = {};
    if ((irq.totalStockQuantity ?? 0) !== total) { update.totalStockQuantity = total; modified = true; }
    if ((irq.stockIssueQuantity ?? 0) !== issue) { update.stockIssueQuantity = issue; modified = true; }
    if ((irq.stockscrapQuantity ?? 0) !== scrap) { update.stockscrapQuantity = scrap; modified = true; }
    if ((irq.stockAvailableQuantity ?? 0) !== avail) { update.stockAvailableQuantity = avail; modified = true; }

    if (modified) {
      await db.collection('itemrackqties').updateOne({ _id: irq._id }, { $set: update });
      console.log(`  [Normalized IRQ ${irq._id}] total=${total}, avail=${avail}, issue=${issue}, scrap=${scrap}`);
    }
  }

  // Re-fetch clean rackQties
  const cleanRackQties = await db.collection('itemrackqties').find({}).toArray();
  const rackMap = {};
  for (const irq of cleanRackQties) {
    const itemId = String(irq.itemId);
    if (!rackMap[itemId]) {
      rackMap[itemId] = { total: 0, avail: 0, issue: 0, scrap: 0 };
    }
    rackMap[itemId].total += (irq.totalStockQuantity ?? 0);
    rackMap[itemId].avail += (irq.stockAvailableQuantity ?? 0);
    rackMap[itemId].issue += (irq.stockIssueQuantity ?? 0);
    rackMap[itemId].scrap += (irq.stockscrapQuantity ?? 0);
  }

  const items = await db.collection('storenewitems').find({}).toArray();
  let reconciledCount = 0;
  for (const item of items) {
    const itemId = String(item._id);
    const rackStats = rackMap[itemId] || { total: 0, avail: 0, issue: 0, scrap: 0 };

    const totalMismatch = (item.totalStockQuantity ?? 0) !== rackStats.total;
    const availMismatch = (item.stockAvailableQuantity ?? 0) !== rackStats.avail;
    const issueMismatch = (item.stockIssueQuantity ?? 0) !== rackStats.issue;
    const scrapMismatch = (item.stockscrapQuantity ?? 0) !== rackStats.scrap;

    if (totalMismatch || availMismatch || issueMismatch || scrapMismatch) {
      console.log(`  [Reconciling Item ${itemId} (${item.itemCode})]`);
      console.log(`    Before: total=${item.totalStockQuantity}, avail=${item.stockAvailableQuantity}, issue=${item.stockIssueQuantity}, scrap=${item.stockscrapQuantity}`);
      console.log(`    After:  total=${rackStats.total}, avail=${rackStats.avail}, issue=${rackStats.issue}, scrap=${rackStats.scrap}`);

      await db.collection('storenewitems').updateOne(
        { _id: item._id },
        {
          $set: {
            totalStockQuantity: rackStats.total,
            stockAvailableQuantity: rackStats.avail,
            stockIssueQuantity: rackStats.issue,
            stockscrapQuantity: rackStats.scrap,
          },
        }
      );
      reconciledCount++;
    }
  }


  console.log(`\n[✓] Reconciliation Complete! ${reconciledCount} store item ledgers aligned to authoritative rack inventory.`);
  await mongoose.disconnect();
}

reconcileDatabaseAndSyncIndexes().catch(err => {
  console.error('Fatal error in reconciliation:', err);
  process.exit(1);
});
