import ballerina/data.jsondata;
import ballerina/io;
import ballerina/lang.array;
import ballerina/time;
import ballerina/file;

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
        // Transform packages to remove keywords field
        PackageWithoutKeywords[] packagesWithoutKeywords = from Package package in data
            select {
                name: package.name,
                URL: package.URL,
                version: package.version,
                totalPullCount: package.totalPullCount,
                pullCount: package.pullCount
            };
        return packagesWithoutKeywords.toJson();
    }
    // For keyword maps, return as-is
    return data.toJson();
}

isolated function writeData(string filePath, Package[]|map<string[]> data, string? googleSpreadsheetId = (), string? sheetName = ()) returns error? {
    string resultDirectory = check file:joinPath(RESULTS_DIR, timestamp, filePath);
    string parentDir = check file:parentPath(string `${resultDirectory}${JSON_FILE_EXTENSION}`);
    check file:createDir(parentDir, file:RECURSIVE);
    printInfo(string `Writing data to ${resultDirectory}`);

    json jsonData = transformToJsonData(data);
    check writeToJsonFile(string `${resultDirectory}${JSON_FILE_EXTENSION}`, jsonData);

    if needCsvExport || needGoogleSheetExport {
        string[][] csvData = transformToCsvData(data);
        if needCsvExport {
            check writeToCsvFile(string `${resultDirectory}${CSV_FILE_EXTENSION}`, csvData);
        }
        if needGoogleSheetExport && googleSpreadsheetId is string {
            string tabName = sheetName is string ? sheetName : filePath;
            check writeToSheet(googleSpreadsheetId, tabName, csvData);
        }
    }
}

isolated function writeDataBatch(DataOutput dataOutput) returns error? {
    // Get or create the spreadsheet once for all writes
    string? googleSpreadsheetId = ();
    if needGoogleSheetExport {
        googleSpreadsheetId = check getOrCreateSpreadsheet();
    }

    check writeData(packageListFilePath, dataOutput.packages, googleSpreadsheetId, "Packages");

    map<string[]>? keywords = dataOutput.keywords;
    if keywords is map<string[]> {
        check writeData(keywordsFilePath, keywords, googleSpreadsheetId, "Keywords");
    }

    map<string[]>? filteredKeywords = dataOutput.filteredKeywords;
    if filteredKeywords is map<string[]> {
        check writeData(filteredKeywordsFilePath, filteredKeywords, googleSpreadsheetId, "Filtered Keywords");
    }

    map<string[]>? categorizedKeywords = dataOutput.categorizedKeywords;
    if categorizedKeywords is map<string[]> {
        check writeData(categorizedKeywordsFilePath, categorizedKeywords, googleSpreadsheetId, "Categorized Keywords");
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

isolated function transformToCsvData(Package[]|map<string[]> data) returns string[][] {
    string[][] csvData = [];
    if data is map<string[]> {
        csvData = transformKeywordsToCsvData(data);
    } else {
        csvData = transformPackagesToCsvData(data);
    }
    return csvData;
}

isolated function transformPackagesToCsvData(Package[] packages) returns string[][] {
    string[][] csvData = [];
    // Add header row (excluding keywords since they have separate sheets)
    csvData.push(["name", "URL", "version", "totalPullCount", "pullCount"]);

    // Add data rows
    foreach Package package in packages {
        int? totalPullCount = package.totalPullCount;
        string totalPullCountStr = totalPullCount is int ? totalPullCount.toString() : "N/A";
        csvData.push([
            package.name,
            package.URL,
            package.version,
            totalPullCountStr,
            package.pullCount.toString()
        ]);
    }
    return csvData;
}

isolated function transformKeywordsToCsvData(map<string[]> data) returns string[][] {
    string[][] csvData = [];
    foreach string keyword in data.keys() {
        string[] packages = data.get(keyword);
        csvData.push([keyword, ...packages]);
    }
    return rotateMatrix90Degrees(csvData.sort(array:DESCENDING));
}

isolated function rotateMatrix90Degrees(string[][] matrix) returns string[][] {
    if matrix.length() == 0 {
        return [];
    }

    int rows = matrix.length();

    // Find the maximum length of any row
    int maxCols = 0;
    foreach string[] row in matrix {
        if row.length() > maxCols {
            maxCols = row.length();
        }
    }

    if maxCols == 0 {
        return [];
    }

    string[][] rotated = [];

    // Initialize the rotated matrix
    foreach int i in 0 ..< maxCols {
        rotated[i] = [];
        foreach int j in 0 ..< rows {
            rotated[i][j] = "";
        }
    }

    // Rotate 90 degrees clockwise, handling variable-length rows
    foreach int i in 0 ..< rows {
        string[] row = matrix[i];
        foreach int j in 0 ..< row.length() {
            rotated[j][rows - 1 - i] = row[j];
        }
    }

    return rotated;
}

isolated function shouldSkipPackage(string packageName, string[] skipPackagePrefixes) returns boolean {
    foreach string skipPackagePrefix in skipPackagePrefixes {
        if packageName.startsWith(skipPackagePrefix) {
            return true;
        }
    }
    return false;
}

isolated function getTimestamp() returns string|error {
    time:Utc now = time:utcNow();
    time:Civil nowCivil = time:utcToCivil(now);
    return string `${nowCivil.year}-${nowCivil.month}-${nowCivil.day}`;
}
