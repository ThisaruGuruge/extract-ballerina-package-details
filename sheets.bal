import ballerinax/googleapis.sheets;

sheets:ConnectionConfig spreadsheetConfig = {
    auth: googleSheetAuthConfig
};

final sheets:Client googleSheet = check new (spreadsheetConfig);

final string sheetName = string `[Connector Analysis] ${orgName}-${timestamp}`;

isolated function getOrCreateSpreadsheet() returns string|error {
    // Check if config provides a spreadsheet ID
    string? configSpreadsheetId = spreadsheetId;
    if configSpreadsheetId is string && configSpreadsheetId.trim().length() > 0 {
        // Use existing spreadsheet from config
        printInfo(string `Using existing spreadsheet: https://docs.google.com/spreadsheets/d/${configSpreadsheetId}`);
        return configSpreadsheetId;
    }

    // Create a new spreadsheet
    sheets:Spreadsheet spreadsheet = check googleSheet->createSpreadsheet(sheetName);
    printSuccess(string `Created new Google Spreadsheet: ${spreadsheet.spreadsheetUrl}`);
    return spreadsheet.spreadsheetId;
}

isolated function writeToSheet(string targetSpreadsheetId, string name, string[][] data) returns error? {
    // Create a new sheet tab for this data type
    sheets:Sheet sheet = check googleSheet->addSheet(targetSpreadsheetId, name);
    printInfo(string `Created sheet tab: ${name} (ID: ${sheet.properties.sheetId})`);

    // Write the data to the sheet
    if data.length() > 0 {
        sheets:Range range = {
            a1Notation: "A1",
            values: data
        };
        _ = check googleSheet->setRange(targetSpreadsheetId, name, range, "RAW");
        printSuccess(string `Data written to sheet '${name}' - ${data.length()} rows written`);
    }
}
