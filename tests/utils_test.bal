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
    test:assertEquals(result[0], ["Name", "URL", "Version", "Total Pull Count", "Pull Count", "Created Date"], "Header should be correct");

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

    // Should have header + data rows (non-rotated format)
    test:assertEquals(result.length(), 3, "Should have header + 2 data rows");
    test:assertEquals(result[0], ["Keyword", "Package Count", "Packages"], "Should have proper headers");

    // Check that data rows have keyword, count, and packages
    test:assertTrue(result[1].length() >= 3, "Data row should have at least 3 columns (keyword, count, packages)");
    test:assertTrue(result[2].length() >= 3, "Data row should have at least 3 columns (keyword, count, packages)");
}
