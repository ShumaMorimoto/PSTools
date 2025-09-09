function testAddWorkday() {
  const baseDate = new Date('2025/09/12'); // 金曜日
  const result = addWorkday(baseDate, 3);  // 3営業日後 → 2025/09/17（水）
  Logger.log(`結果: ${Utilities.formatDate(result, 'Asia/Tokyo', 'yyyy/MM/dd')}`);

  Logger.log(getEffectiveWorkday())

}
