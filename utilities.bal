import ballerina/file;
import ballerina/io;
import ballerina/lang.array;
import ballerina/time;

// ============================================
// ANSI Color Codes
// ============================================

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

// ============================================
// Print Functions
// ============================================

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

// ============================================
// Date Utilities
// ============================================

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

// ============================================
// File System Utilities
// ============================================

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

// ============================================
// Filtering Utilities
// ============================================

isolated function shouldSkipPackage(string packageName, string[] skipPackagePrefixes) returns boolean {
    foreach string skipPackagePrefix in skipPackagePrefixes {
        if packageName.startsWith(skipPackagePrefix) {
            return true;
        }
    }
    return false;
}
