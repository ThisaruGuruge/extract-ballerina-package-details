import ballerina/test;

@test:Config
function testFormatTimestampToDate() {
    // Test Unix timestamp conversion (API returns milliseconds)
    string result = formatTimestampToDate(1585699200000);
    test:assertEquals(result, "2020-4-1", "Should format Unix timestamp correctly");
}

@test:Config
function testFormatTimestampToDateWithZero() {
    // Test epoch time (Jan 1, 1970)
    string result = formatTimestampToDate(0);
    test:assertEquals(result, "1970-1-1", "Should handle epoch time");
}

@test:Config
function testShouldSkipPackageWithMatch() {
    string[] prefixes = ["health.", "test."];
    boolean result = shouldSkipPackage("health.fhir", prefixes);
    test:assertTrue(result, "Should skip package with matching prefix");
}

@test:Config
function testShouldSkipPackageWithoutMatch() {
    string[] prefixes = ["health.", "test."];
    boolean result = shouldSkipPackage("http.client", prefixes);
    test:assertFalse(result, "Should not skip package without matching prefix");
}

@test:Config
function testShouldSkipPackageEmptyPrefixes() {
    string[] prefixes = [];
    boolean result = shouldSkipPackage("any.package", prefixes);
    test:assertFalse(result, "Should not skip any package when no prefixes provided");
}

@test:Config
function testCategorizeKeywordsWithSlash() {
    map<string[]> keywords = {
        "network/http": ["pkg1", "pkg2"],
        "network/tcp": ["pkg1"],
        "database/sql": ["pkg3"],
        "simple": ["pkg4"]
    };

    map<string[]> result = categorizeKeywords(keywords);

    test:assertEquals(result.length(), 2, "Should have 2 parent categories");
    test:assertTrue(result.hasKey("network"), "Should have 'network' parent");
    test:assertTrue(result.hasKey("database"), "Should have 'database' parent");

    string[]? networkChildren = result["network"];
    test:assertTrue(networkChildren is string[], "Network should have children");
    if networkChildren is string[] {
        test:assertEquals(networkChildren.length(), 2, "Network should have 2 children");
        test:assertTrue(networkChildren.indexOf("http") != (), "Should contain 'http'");
        test:assertTrue(networkChildren.indexOf("tcp") != (), "Should contain 'tcp'");
    }
}

@test:Config
function testCategorizeKeywordsEmpty() {
    map<string[]> keywords = {};
    map<string[]> result = categorizeKeywords(keywords);
    test:assertEquals(result.length(), 0, "Should return empty map for empty input");
}

@test:Config
function testCategorizeKeywordsNoSlash() {
    map<string[]> keywords = {
        "http": ["pkg1"],
        "tcp": ["pkg2"]
    };

    map<string[]> result = categorizeKeywords(keywords);
    test:assertEquals(result.length(), 0, "Should return empty map when no keywords have slashes");
}

@test:Config
function testRotateMatrix90DegreesBasic() {
    string[][] matrix = [
        ["a", "b", "c"],
        ["d", "e", "f"]
    ];

    string[][] result = rotateMatrix90Degrees(matrix);

    test:assertEquals(result.length(), 3, "Rotated matrix should have 3 rows");
    test:assertEquals(result[0].length(), 2, "Each row should have 2 columns");

    // 90-degree clockwise rotation:
    // Input:  a b c     Output:  d a
    //         d e f              e b
    //                            f c
    test:assertEquals(result[0][0], "d", "First row, first column");
    test:assertEquals(result[0][1], "a", "First row, second column");
    test:assertEquals(result[1][0], "e", "Second row, first column");
    test:assertEquals(result[1][1], "b", "Second row, second column");
    test:assertEquals(result[2][0], "f", "Third row, first column");
    test:assertEquals(result[2][1], "c", "Third row, second column");
}

@test:Config
function testRotateMatrix90DegreesEmpty() {
    string[][] matrix = [];
    string[][] result = rotateMatrix90Degrees(matrix);
    test:assertEquals(result.length(), 0, "Should return empty matrix for empty input");
}

@test:Config
function testRotateMatrix90DegreesJaggedArray() {
    // Test with rows of different lengths
    string[][] matrix = [
        ["a", "b", "c"],
        ["d", "e"],
        ["f"]
    ];

    string[][] result = rotateMatrix90Degrees(matrix);

    test:assertEquals(result.length(), 3, "Should handle jagged arrays");
    test:assertEquals(result[0].length(), 3, "All rows should have 3 columns");

    // After rotation of jagged array:
    // Input:  a b c     Output:  f d a
    //         d e                  e b
    //         f                      c
    test:assertEquals(result[0][0], "f", "First row, first column");
    test:assertEquals(result[0][1], "d", "First row, second column");
    test:assertEquals(result[0][2], "a", "First row, third column");
    test:assertEquals(result[1][0], "", "Second row, first column (empty padding)");
    test:assertEquals(result[1][1], "e", "Second row, second column");
    test:assertEquals(result[1][2], "b", "Second row, third column");
    test:assertEquals(result[2][0], "", "Third row, first column (empty padding)");
    test:assertEquals(result[2][1], "", "Third row, second column (empty padding)");
    test:assertEquals(result[2][2], "c", "Third row, third column");
}

@test:Config
function testRotateMatrix90DegreesSingleElement() {
    string[][] matrix = [["single"]];
    string[][] result = rotateMatrix90Degrees(matrix);

    test:assertEquals(result.length(), 1, "Should have 1 row");
    test:assertEquals(result[0].length(), 1, "Should have 1 column");
    test:assertEquals(result[0][0], "single", "Element should be preserved");
}

@test:Config
function testTransformPackagesToCsvData() {
    Package[] packages = [
        {
            name: "http",
            URL: "https://central.ballerina.io/ballerina/http",
            version: "2.9.0",
            totalPullCount: 1500000,
            pullCount: 50000,
            createdDate: 1585699200000
        },
        {
            name: "io",
            URL: "https://central.ballerina.io/ballerina/io",
            version: "1.6.0",
            totalPullCount: (),
            pullCount: 25000,
            createdDate: 1557619200000
        }
    ];

    string[][] result = transformPackagesToCsvData(packages);

    test:assertEquals(result.length(), 3, "Should have header + 2 data rows");
    test:assertEquals(result[0], ["name", "URL", "version", "totalPullCount", "pullCount", "createdDate"], "Header should be correct");

    test:assertEquals(result[1][0], "http", "First package name");
    test:assertEquals(result[1][3], "1500000", "First package totalPullCount");
    test:assertEquals(result[1][5], "2020-4-1", "First package formatted date");

    test:assertEquals(result[2][0], "io", "Second package name");
    test:assertEquals(result[2][3], "N/A", "Second package should show N/A for null totalPullCount");
    test:assertEquals(result[2][5], "2019-5-12", "Second package formatted date");
}

@test:Config
function testTransformKeywordsToCsvData() {
    map<string[]> keywords = {
        "http": ["pkg1", "pkg2", "pkg3"],
        "database": ["pkg4", "pkg5"]
    };

    string[][] result = transformKeywordsToCsvData(keywords);

    // Result should be rotated matrix
    test:assertTrue(result.length() > 0, "Should have rows");
    test:assertTrue(result[0].length() == 2, "Should have 2 columns after rotation");
}
