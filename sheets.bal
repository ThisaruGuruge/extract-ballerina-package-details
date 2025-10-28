import ballerinax/googleapis.sheets;

final string sheetName = string `[Connector Analysis] ${orgName}-${timestamp}`;

isolated function getGoogleSheetClient() returns sheets:Client|error {
    GoogleSheetConfig? authConfig = googleSheetAuthConfig;
    if authConfig is () {
        return error("Google Sheets authentication configuration is not provided");
    }

    sheets:ConnectionConfig spreadsheetConfig = {
        auth: authConfig
    };

    return new (spreadsheetConfig);
}

isolated function getOrCreateSpreadsheet() returns string|error {
    // Check if config provides a spreadsheet ID
    string? configSpreadsheetId = spreadsheetId;
    if configSpreadsheetId is string && configSpreadsheetId.trim().length() > 0 {
        // Use existing spreadsheet from config
        printInfo(string `Using existing spreadsheet: https://docs.google.com/spreadsheets/d/${configSpreadsheetId}`);
        return configSpreadsheetId;
    }

    // Create a new spreadsheet
    sheets:Client googleSheet = check getGoogleSheetClient();
    sheets:Spreadsheet spreadsheet = check googleSheet->createSpreadsheet(sheetName);
    printSuccess(string `Created new Google Spreadsheet: ${spreadsheet.spreadsheetUrl}`);
    return spreadsheet.spreadsheetId;
}

isolated function writeToSheet(string targetSpreadsheetId, string name, string[][] data) returns error? {
    sheets:Client googleSheet = check getGoogleSheetClient();

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
