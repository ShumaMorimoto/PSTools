function LoadTable(sheetName, rangeA1) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(sheetName);
  const range = sheet.getRange(rangeA1);
  const values = range.getValues();

  const headers = values[0];
  const startRow = range.getRow();
  const startCol = range.getColumn();
  const numCols = headers.length;

  const rows = values.slice(1).map((row, i) => {
    const obj = {};
    headers.forEach((key, j) => {
      let val = row[j];
      if (typeof val === 'string' && val.match(/^\d{1,3}(,\d{3})*$/)) {
        val = val.replace(/,/g, '');
      }
      obj[key] = val;
    });

    const rowIndex = startRow + 1 + i;
    const startColLetter = columnToLetter(startCol);
    const endColLetter = columnToLetter(startCol + numCols - 1);
    obj._range = `${startColLetter}${rowIndex}:${endColLetter}${rowIndex}`;

    return obj;
  });

  return {
    sheetName: sheetName,
    range: rangeA1,
    header: headers,
    rows: rows
  };
}
function ReloadTable(table) {
  return LoadTable(table.sheetName, table.range);
}
function UpdateRow(table, record) {
  if (!record._range) return;

  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(table.sheetName);
  const range = sheet.getRange(record._range);

  const rowValues = table.header.map(key => record[key] ?? "");
  range.setValues([rowValues]);
}
function columnToLetter(col) {
  let letter = '';
  while (col > 0) {
    const mod = (col - 1) % 26;
    letter = String.fromCharCode(65 + mod) + letter;
    col = Math.floor((col - mod - 1) / 26);
  }
  return letter;
}
