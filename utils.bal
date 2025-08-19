import ballerina/data.jsondata;
import ballerina/io;
import ballerina/lang.array;

const string JSON_FILE_EXTENSION = ".json";
const string CSV_FILE_EXTENSION = ".csv";

isolated function printInfo(string message) {
    io:println(string `[INFO] ${message}`);
}

isolated function printWarning(string message) {
    io:println(string `[WARNING] ${message}`);
}

isolated function categorizeKeywords(map<string[]> keywords) returns map<string[]> {
    map<string[]> parentKeywords = {};
    foreach string keyword in keywords.keys() {
        if re `/`.split(keyword).length() > 1 {
            string[] keywordParts = re `/`.split(keyword);
            string parentKeyword = keywordParts[0];
            string childKeyword = keywordParts[1];
            if parentKeywords.hasKey(parentKeyword) {
                parentKeywords.get(parentKeyword).push(childKeyword);
            } else {
                parentKeywords[parentKeyword] = [childKeyword];
            }
        }
    }
    return parentKeywords;
}

isolated function writeToFile(string filePath, Package[]|map<string[]> data) returns error? {
    check writeToJsonFile(string `${filePath}${JSON_FILE_EXTENSION}`, data);
    if needCsvExport {
        if data is map<string[]> {
            check writeToCsvFile(string `${filePath}${CSV_FILE_EXTENSION}`, transformKeywordsToCsvData(data));
        } else {
            check writeToCsvFile(string `${filePath}${CSV_FILE_EXTENSION}`, data);
        }
    }
}

isolated function writeToJsonFile(string filePath, json data) returns error? {
    string dataPrettified = jsondata:prettify(data);
    check io:fileWriteString(filePath, dataPrettified);
}

isolated function writeToCsvFile(string filePath, Package[]|string[][] data) returns error? {
    check io:fileWriteCsv(filePath, data);
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
