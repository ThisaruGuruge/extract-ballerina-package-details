import ballerina/data.jsondata;
import ballerina/file;
import ballerina/io;
import ballerina/lang.array;
import ballerina/time;

// ANSI Color codes for terminal output
const string ESC = "\u{001B}";
const string RESET = ESC + "[0m";
const string BOLD = ESC + "[1m";

// Colors
const string RED = ESC + "[31m";
const string GREEN = ESC + "[32m";
const string YELLOW = ESC + "[33m";
const string BLUE = ESC + "[34m";
const string MAGENTA = ESC + "[35m";
const string CYAN = ESC + "[36m";
const string WHITE = ESC + "[37m";

// Bright colors
const string BRIGHT_RED = ESC + "[91m";
const string BRIGHT_GREEN = ESC + "[92m";
const string BRIGHT_YELLOW = ESC + "[93m";
const string BRIGHT_BLUE = ESC + "[94m";
const string BRIGHT_MAGENTA = ESC + "[95m";
const string BRIGHT_CYAN = ESC + "[96m";

isolated function printInfo(string message) {
    io:println(string `${BLUE}${BOLD}[INFO]${RESET} ${message}`);
}

isolated function printWarning(string message) {
    io:println(string `${YELLOW}${BOLD}[WARNING]${RESET} ${YELLOW}${message}${RESET}`);
}

isolated function printError(error err) {
    string errorMessage = err.message();
    error? cause = err.cause();

    io:println(string `${RED}${BOLD}[ERROR]${RESET} ${RED}${errorMessage}${RESET}`);

    // Print cause chain if exists
    while cause is error {
        io:println(string `${RED}${BOLD}[ERROR]${RESET} ${RED}  Caused by: ${cause.message()}${RESET}`);
        cause = cause.cause();
    }
}

isolated function printSuccess(string message) {
    io:println(string `${GREEN}${BOLD}[SUCCESS]${RESET} ${GREEN}${message}${RESET}`);
}

isolated function printProgress(string message) {
    io:println(string `${CYAN}${BOLD}[PROGRESS]${RESET} ${CYAN}${message}${RESET}`);
}

isolated function printStats(string message) {
    io:println(string `${MAGENTA}${BOLD}[STATS]${RESET} ${MAGENTA}${message}${RESET}`);
}

isolated function categorizeKeywords(map<string[]> keywords) returns map<string[]> {
    map<string[]> parentKeywords = {};
    foreach string keyword in keywords.keys() {
        if keyword.includes("/") {
            int? slashIndex = keyword.indexOf("/");
            if slashIndex is int {
                string parentKeyword = keyword.substring(0, slashIndex);
                string childKeyword = keyword.substring(slashIndex + 1);
                if parentKeywords.hasKey(parentKeyword) {
                    parentKeywords.get(parentKeyword).push(childKeyword);
                } else {
                    parentKeywords[parentKeyword] = [childKeyword];
                }
            }
        }
    }
    return parentKeywords;
}

isolated function transformToJsonData(Package[]|map<string[]> data) returns json {
    if data is Package[] {
        // Transform packages to add formatted date while preserving all fields including keywords
        PackageWithoutKeywords[] packagesForExport = from Package package in data
            select {
                name: package.name,
                URL: package.URL,
                version: package.version,
                totalPullCount: package.totalPullCount,
                pullCount: package.pullCount,
                keywords: package.keywords,
                createdDate: package.createdDate,
                createdDateFormatted: formatTimestampToDate(package.createdDate)
            };
        return packagesForExport.toJson();
    }
    // For keyword maps, return as-is
    return data.toJson();
}

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

isolated function getLatestExistingResultsDirectory() returns string|error {
    file:MetaData[] resultDirectories = check file:readDir(RESULTS_DIR);
    if resultDirectories.length() == 0 {
        return error("No existing results found. Set 'needPackageListFromCentral' to 'true' and rerun the application to generate the results.");
    }
    resultDirectories = resultDirectories.sort(array:DESCENDING, key = getModifiedTime);
    return resultDirectories[0].absPath;
}

isolated function getModifiedTime(file:MetaData dir) returns time:Utc {
    return dir.modifiedTime;
}

isolated function writeToJsonFile(string filePath, json data) returns error? {
    string dataPrettified = jsondata:prettify(data);
    check io:fileWriteString(filePath, dataPrettified);
    printSuccess(string `JSON data written to ${filePath}`);
}

isolated function writeToCsvFile(string filePath, Package[]|string[][] data) returns error? {
    check io:fileWriteCsv(filePath, data);
    printSuccess(string `CSV data written to ${filePath}`);
}

// ============================================
// Data Transformation Functions
// ============================================

isolated function transformToCsvData(Package[]|map<string[]> data) returns string[][] {
    if data is map<string[]> {
        // Use same format as Google Sheets for consistency
        return transformKeywordsToCsvData(data);
    } else {
        return transformPackagesToCsvData(data);
    }
}

isolated function transformPackagesToCsvData(Package[] packages) returns string[][] {
    string[][] csvData = [];
    // Add header row with proper titles
    csvData.push(["Name", "URL", "Version", "Total Pull Count", "Pull Count", "Created Date"]);

    // Add data rows
    foreach Package package in packages {
        int? totalPullCount = package.totalPullCount;
        string totalPullCountStr = totalPullCount is int ? totalPullCount.toString() : "N/A";
        string createdDateStr = formatTimestampToDate(package.createdDate);
        csvData.push([
            package.name,
            package.URL,
            package.version,
            totalPullCountStr,
            package.pullCount.toString(),
            createdDateStr
        ]);
    }
    return csvData;
}

isolated function transformPackagesToSheetData(Package[] packages) returns string[][] {
    string[][] sheetData = [];
    // Add header row with proper titles
    sheetData.push(["Name", "Version", "Total Pull Count", "Pull Count", "Created Date"]);

    // Add data rows with hyperlink formula
    foreach Package package in packages {
        int? totalPullCount = package.totalPullCount;
        string totalPullCountStr = totalPullCount is int ? totalPullCount.toString() : "N/A";
        string createdDateStr = formatTimestampToDate(package.createdDate);

        // Create HYPERLINK formula for package name
        string hyperlinkFormula = string `=HYPERLINK("${package.URL}", "${package.name}")`;

        sheetData.push([
            hyperlinkFormula,
            package.version,
            totalPullCountStr,
            package.pullCount.toString(),
            createdDateStr
        ]);
    }
    return sheetData;
}

isolated function transformKeywordsToSheetData(map<string[]> data) returns string[][] {
    string[][] sheetData = [];

    // Add header row
    sheetData.push(["Keyword", "Package Count", "Packages"]);

    // Create rows with keyword, count, and packages spread across cells
    // Sort by package count (descending) for better readability
    string[][] keywordRows = [];
    foreach string keyword in data.keys() {
        string[] packages = data.get(keyword);
        string[] row = [keyword, packages.length().toString()];
        // Add each package in its own cell
        foreach string package in packages {
            row.push(package);
        }
        keywordRows.push(row);
    }

    // Sort by package count (second column) in descending order
    keywordRows = keywordRows.sort(array:DESCENDING, isolated function(string[] row) returns int {
        int|error count = int:fromString(row[1]);
        return count is int ? count : 0;
    });

    // Add sorted rows to sheet data
    foreach string[] row in keywordRows {
        sheetData.push(row);
    }

    return sheetData;
}

isolated function transformKeywordsToCsvData(map<string[]> data) returns string[][] {
    // Use the same non-rotated format as Google Sheets for consistency
    string[][] csvData = [];

    // Add header row
    csvData.push(["Keyword", "Package Count", "Packages"]);

    // Create rows with keyword, count, and packages spread across cells
    string[][] keywordRows = [];
    foreach string keyword in data.keys() {
        string[] packages = data.get(keyword);
        string[] row = [keyword, packages.length().toString()];
        // Add each package in its own cell
        foreach string package in packages {
            row.push(package);
        }
        keywordRows.push(row);
    }

    // Sort by package count (second column) in descending order
    keywordRows = keywordRows.sort(array:DESCENDING, isolated function(string[] row) returns int {
        int|error count = int:fromString(row[1]);
        return count is int ? count : 0;
    });

    // Add sorted rows to CSV data
    foreach string[] row in keywordRows {
        csvData.push(row);
    }

    return csvData;
}

// ============================================
// Utility Functions
// ============================================

isolated function shouldSkipPackage(string packageName, string[] skipPackagePrefixes) returns boolean {
    foreach string skipPackagePrefix in skipPackagePrefixes {
        if packageName.startsWith(skipPackagePrefix) {
            return true;
        }
    }
    return false;
}

isolated function formatCivilToDate(time:Civil civil) returns string {
    // Format as YYYY-MM-DD
    return string `${civil.year}-${civil.month}-${civil.day}`;
}

isolated function getTimestamp() returns string|error {
    time:Utc now = time:utcNow();
    time:Civil nowCivil = time:utcToCivil(now);
    return formatCivilToDate(nowCivil);
}

isolated function formatTimestampToDate(int timestamp) returns string {
    // API returns timestamps in milliseconds, convert to seconds
    // Divide by 1000 to convert milliseconds to seconds
    time:Utc utc = [timestamp / 1000, 0.0d];
    time:Civil civil = time:utcToCivil(utc);
    return formatCivilToDate(civil);
}
