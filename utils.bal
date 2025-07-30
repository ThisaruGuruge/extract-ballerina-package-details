import ballerina/data.jsondata;
import ballerina/io;

const string JSON_FILE_EXTENSION = ".json";
const string CSV_FILE_EXTENSION = ".csv";

isolated function printInfo(string message) {
    io:println(string `[INFO] ${message}`);
}

isolated function printWarning(string message) {
    io:println(string `[WARNING] ${message}`);
}

isolated function writeToFile(string filePath, Package[]|map<string[]> data) returns error? {
    check writeToJsonFile(string `${filePath}${JSON_FILE_EXTENSION}`, data);
    if needCsvExport {
        check writeToCsvFile(string `${filePath}${CSV_FILE_EXTENSION}`, data);
    }
}

isolated function writeToJsonFile(string filePath, json data) returns error? {
    string dataPrettified = jsondata:prettify(data);
    check io:fileWriteString(filePath, dataPrettified);
}

isolated function writeToCsvFile(string filePath, Package[]|map<string[]> data) returns error? {
    if data is Package[] {
        check io:fileWriteCsv(filePath, data);
        return;
    }
    string[][] csvData = [];
    foreach string keyword in data.keys() {
        string[] packages = data.get(keyword);
        csvData.push([keyword, ...packages]);
    }
    csvData = csvData.sort();
    check io:fileWriteCsv(filePath, csvData);
}
