import ballerina/test;
import ballerina/time;

// Test data
Package samplePackage1 = {
    name: "kafka",
    URL: "https://central.ballerina.io/ballerina/kafka",
    version: "3.5.0",
    totalPullCount: 25000,
    pullCount: 1500,
    keywords: ["messaging", "stream"],
    createdDate: 1609459200000
};

Package samplePackage2 = {
    name: "grpc",
    URL: "https://central.ballerina.io/ballerina/grpc",
    version: "2.1.0",
    totalPullCount: (),
    pullCount: 800,
    keywords: ["rpc", "network"],
    createdDate: 1622505600000
};

@test:Config
function testTransformToJsonDataWithPackages() {
    Package[] packages = [samplePackage1];

    json result = transformToJsonData(packages);
    json[] resultArray = <json[]>result;

    test:assertEquals(resultArray.length(), 1, "Should have 1 package");
    json firstPackage = resultArray[0];
    test:assertEquals(firstPackage.name, "kafka", "Package name should be preserved");
    test:assertEquals(firstPackage.version, "3.5.0", "Version should be preserved");
    test:assertTrue(firstPackage.createdDateFormatted is json, "Should have formatted date field");
}

@test:Config
function testTransformToJsonDataWithKeywords() {
    map<string[]> keywords = {
        "messaging": ["kafka", "rabbitmq"],
        "database": ["mysql", "postgresql"]
    };

    json result = transformToJsonData(keywords);
    map<json> resultMap = <map<json>>result;

    test:assertEquals(resultMap.keys().length(), 2, "Should have 2 keywords");
    test:assertTrue(resultMap.hasKey("messaging"), "Should contain messaging keyword");
    test:assertTrue(resultMap.hasKey("database"), "Should contain database keyword");
}

@test:Config
function testTransformToJsonDataEmptyPackages() {
    Package[] packages = [];

    json result = transformToJsonData(packages);
    json[] resultArray = <json[]>result;

    test:assertEquals(resultArray.length(), 0, "Empty package array should produce empty JSON array");
}

@test:Config
function testTransformPackagesToSheetData() {
    Package[] packages = [samplePackage1, samplePackage2];

    string[][] result = transformPackagesToSheetData(packages);

    test:assertEquals(result.length(), 3, "Should have header + 2 data rows");
    test:assertEquals(result[0], ["Name", "Version", "Total Pull Count", "Pull Count", "Created Date"], "Header should be correct");

    // First package
    test:assertTrue(result[1][0].includes("HYPERLINK"), "First row should have hyperlink formula");
    test:assertTrue(result[1][0].includes("kafka"), "First row should include package name");
    test:assertEquals(result[1][1], "3.5.0", "First package version");
    test:assertEquals(result[1][2], "25000", "First package totalPullCount");

    // Second package (null totalPullCount)
    test:assertTrue(result[2][0].includes("HYPERLINK"), "Second row should have hyperlink formula");
    test:assertTrue(result[2][0].includes("grpc"), "Second row should include package name");
    test:assertEquals(result[2][2], "N/A", "Second package should show N/A for null totalPullCount");
}

@test:Config
function testTransformPackagesToSheetDataEmpty() {
    Package[] packages = [];

    string[][] result = transformPackagesToSheetData(packages);

    test:assertEquals(result.length(), 1, "Should only have header row");
    test:assertEquals(result[0], ["Name", "Version", "Total Pull Count", "Pull Count", "Created Date"], "Header should be present");
}

@test:Config
function testTransformToCsvDataWithPackages() {
    Package[] packages = [samplePackage1];

    string[][] result = transformToCsvData(packages);

    test:assertEquals(result.length(), 2, "Should have header + 1 data row");
    test:assertEquals(result[0], ["Name", "URL", "Version", "Total Pull Count", "Pull Count", "Created Date"], "Should have package headers");
    test:assertEquals(result[1][0], "kafka", "Should have correct package name in data row");
    test:assertEquals(result[1][2], "3.5.0", "Should have correct version");
}

@test:Config
function testTransformToCsvDataWithKeywords() {
    map<string[]> keywords = {
        "test": ["pkg1", "pkg2", "pkg3"]
    };

    string[][] result = transformToCsvData(keywords);

    test:assertTrue(result.length() > 0, "Should have at least one row after transformation");
    test:assertTrue(result[0].length() > 0, "First row should have at least one column");
    // After rotation, the keyword should appear in a column
    test:assertTrue(result.some(row => row.some(cell => cell == "test")), "Should contain 'test' keyword after rotation");
}

@test:Config
function testFormatCivilToDate() {
    // Create a civil time record
    time:Civil civil = {
        year: 2024,
        month: 3,
        day: 15,
        hour: 12,
        minute: 30,
        second: 0
    };

    string result = formatCivilToDate(civil);

    test:assertEquals(result, "2024-3-15", "Should format civil time to date string");
}

@test:Config
function testFormatCivilToDateWithSingleDigits() {
    time:Civil civil = {
        year: 2024,
        month: 1,
        day: 5,
        hour: 0,
        minute: 0,
        second: 0
    };

    string result = formatCivilToDate(civil);

    test:assertEquals(result, "2024-1-5", "Should handle single digit month and day");
}

@test:Config
function testCategorizeKeywordsMultipleLevels() {
    map<string[]> keywords = {
        "data/sql": ["mysql", "postgresql"],
        "data/nosql": ["mongodb", "redis"],
        "network/http": ["express", "nginx"],
        "network/tcp": ["netcat"],
        "standalone": ["tool1"]
    };

    map<string[]> result = categorizeKeywords(keywords);

    test:assertEquals(result.length(), 2, "Should have 2 parent categories (data and network)");
    test:assertTrue(result.hasKey("data"), "Should have 'data' parent");
    test:assertTrue(result.hasKey("network"), "Should have 'network' parent");

    string[]? dataChildren = result["data"];
    if dataChildren is string[] {
        test:assertEquals(dataChildren.length(), 2, "Data should have 2 children");
        test:assertTrue(dataChildren.indexOf("sql") != (), "Should contain 'sql'");
        test:assertTrue(dataChildren.indexOf("nosql") != (), "Should contain 'nosql'");
    }

    string[]? networkChildren = result["network"];
    if networkChildren is string[] {
        test:assertEquals(networkChildren.length(), 2, "Network should have 2 children");
        test:assertTrue(networkChildren.indexOf("http") != (), "Should contain 'http'");
        test:assertTrue(networkChildren.indexOf("tcp") != (), "Should contain 'tcp'");
    }
}
