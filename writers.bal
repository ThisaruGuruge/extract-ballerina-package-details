import ballerina/data.jsondata;
import ballerina/file;
import ballerina/io;

// ============================================
// Write Orchestration Functions
// ============================================

isolated function writeData(string filePath, Package[]|map<string[]> data, string? googleSpreadsheetId = (), string? sheetName = (), boolean isFirstSheet = false) returns error? {
    string resultDirectory = check file:joinPath(RESULTS_DIR, timestamp, filePath);
    string parentDir = check file:parentPath(string `${resultDirectory}${JSON_FILE_EXTENSION}`);
    check file:createDir(parentDir, file:RECURSIVE);
    printInfo(string `Writing data to ${resultDirectory}`);

    json jsonData = transformToJsonData(data);
    check writeToJsonFile(string `${resultDirectory}${JSON_FILE_EXTENSION}`, jsonData);

    if needCsvExport {
        string[][] csvData = transformToCsvData(data);
        check writeToCsvFile(string `${resultDirectory}${CSV_FILE_EXTENSION}`, csvData);
    }

    if needGoogleSheetExport && googleSpreadsheetId is string {
        string tabName = sheetName is string ? sheetName : filePath;
        // Use sheet-specific transformations with better formatting
        string[][] sheetData = [];
        if data is Package[] {
            sheetData = transformPackagesToSheetData(data);
        } else {
            // For keyword maps, use spread format (one item per cell)
            sheetData = transformKeywordsToSheetData(data);
        }
        printInfo(string `Transformed ${tabName}: ${sheetData.length()} rows`);
        check writeToSheet(googleSpreadsheetId, tabName, sheetData, isFirstSheet);
    }
}

isolated function writeDataBatch(DataOutput dataOutput) returns error? {
    do {
        // Get or create the spreadsheet once for all writes
        string? googleSpreadsheetId = ();
        if needGoogleSheetExport {
            googleSpreadsheetId = check getOrCreateSpreadsheet();
        }

        // Write packages first (this will rename the default sheet)
        check writeData(packageListFilePath, dataOutput.packages, googleSpreadsheetId, "Packages", true);

        // Write connector summary sheet (Google Sheets only - different view of packages)
        if needGoogleSheetExport && googleSpreadsheetId is string {
            string[][] connectorSummaryData = transformPackagesToConnectorSummary(dataOutput.packages);
            printInfo(string `Transformed Connector Summary: ${connectorSummaryData.length()} rows`);
            check writeToSheet(googleSpreadsheetId, "Connector Summary", connectorSummaryData, false);
        }

        // Write unfiltered keywords to JSON/CSV only (not to Google Sheets - redundant with Filtered Keywords)
        map<string[]>? keywords = dataOutput.keywords;
        if keywords is map<string[]> {
            check writeData(keywordsFilePath, keywords, (), "Keywords", false);
        }

        // Write filtered keywords to all outputs including Google Sheets
        map<string[]>? filteredKeywords = dataOutput.filteredKeywords;
        if filteredKeywords is map<string[]> {
            check writeData(filteredKeywordsFilePath, filteredKeywords, googleSpreadsheetId, "Filtered Keywords", false);
        }

        // Write categorized keywords to all outputs including Google Sheets
        map<string[]>? categorizedKeywords = dataOutput.categorizedKeywords;
        if categorizedKeywords is map<string[]> {
            check writeData(categorizedKeywordsFilePath, categorizedKeywords, googleSpreadsheetId, "Categorized Keywords", false);
        }
    } on fail error err {
        return error("Failed to write data batch", err);
    }
}

// ============================================
// File Writer Functions
// ============================================

isolated function writeToJsonFile(string filePath, json data) returns error? {
    string dataPrettified = jsondata:prettify(data);
    check io:fileWriteString(filePath, dataPrettified);
    printSuccess(string `JSON data written to ${filePath}`);
}

isolated function writeToCsvFile(string filePath, Package[]|string[][] data) returns error? {
    check io:fileWriteCsv(filePath, data);
    printSuccess(string `CSV data written to ${filePath}`);
}
