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
    do {
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
    } on fail error err {
        return error("Failed to get or create Google Spreadsheet", err);
    }
}

isolated function writeToSheet(string targetSpreadsheetId, string name, string[][] data, boolean isFirstSheet) returns error? {
    do {
        sheets:Client googleSheet = check getGoogleSheetClient();
        sheets:Sheet[] existingSheets = check googleSheet->getSheets(targetSpreadsheetId);

        // Check if sheet with this name already exists
        sheets:Sheet? existingSheet = ();
        foreach sheets:Sheet sheet in existingSheets {
            if sheet.properties.title == name {
                existingSheet = sheet;
                break;
            }
        }

        if existingSheet is sheets:Sheet {
            // Sheet exists, clear its contents
            printInfo(string `Sheet '${name}' already exists, clearing contents`);
            _ = check googleSheet->clearAllBySheetName(targetSpreadsheetId, name);
        } else if isFirstSheet && existingSheets.length() > 0 {
            // Rename the default sheet instead of creating a new sheet
            sheets:Sheet defaultSheet = existingSheets[0];
            string currentSheetName = defaultSheet.properties.title;
            _ = check googleSheet->renameSheet(targetSpreadsheetId, currentSheetName, name);
            printInfo(string `Renamed default sheet '${currentSheetName}' to: ${name}`);
        } else {
            // Create a new sheet tab
            sheets:Sheet sheet = check googleSheet->addSheet(targetSpreadsheetId, name);
            printInfo(string `Created sheet tab: ${name} (ID: ${sheet.properties.sheetId})`);
        }

        // Write the data to the sheet
        if data.length() > 0 {
            sheets:Range range = {
                a1Notation: "A1",
                values: data
            };
            // Use USER_ENTERED to interpret formulas (like HYPERLINK)
            _ = check googleSheet->setRange(targetSpreadsheetId, name, range, "USER_ENTERED");
            printSuccess(string `Data written to sheet '${name}' - ${data.length()} rows written`);
        }
    } on fail error err {
        return error(string `Failed to write data to Google Sheet: ${name}`, err);
    }
}
