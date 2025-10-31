import ballerina/test;
import ballerina/time;

// Test edge cases and boundary conditions

@test:Config
function testPackageWithVeryLongName() {
    Package pkg = {
        name: "very.long.package.name.with.many.segments.that.goes.on.and.on",
        URL: "https://central.ballerina.io/org/pkg",
        version: "1.0.0",
        totalPullCount: 100,
        pullCount: 10,
        keywords: ["test"],
        createdDate: 1585699200000
    };

    Package[] packages = [pkg];
    string[][] csvData = transformPackagesToCsvData(packages);

    test:assertEquals(csvData.length(), 2, "Should handle long package names");
    test:assertTrue(csvData[1][0].length() > 50, "Package name should be preserved");
}

@test:Config
function testPackageWithSpecialCharacters() {
    Package pkg = {
        name: "test-pkg_v2",
        URL: "https://central.ballerina.io/org/test-pkg_v2",
        version: "2.0.0-beta.1",
        totalPullCount: 100,
        pullCount: 10,
        keywords: ["test-keyword", "special_chars"],
        createdDate: 1585699200000
    };

    Package[] packages = [pkg];
    map<string[]> keywords = categorize(packages);

    test:assertTrue(keywords.hasKey("test-keyword"), "Should handle hyphens in keywords");
    test:assertTrue(keywords.hasKey("special_chars"), "Should handle underscores in keywords");
}

@test:Config
function testPackageWithZeroPullCount() {
    Package pkg = {
        name: "unpopular",
        URL: "https://central.ballerina.io/org/unpopular",
        version: "0.1.0",
        totalPullCount: 0,
        pullCount: 0,
        keywords: [],
        createdDate: 1585699200000
    };

    Package[] packages = [pkg];
    string[][] csvData = transformPackagesToCsvData(packages);

    test:assertEquals(csvData[1][3], "0", "Should handle zero totalPullCount");
    test:assertEquals(csvData[1][4], "0", "Should handle zero pullCount");
}

@test:Config
function testPackageWithVeryHighPullCount() {
    Package pkg = {
        name: "popular",
        URL: "https://central.ballerina.io/org/popular",
        version: "5.0.0",
        totalPullCount: 999999999,
        pullCount: 888888888,
        keywords: [],
        createdDate: 1585699200000
    };

    Package[] packages = [pkg];
    string[][] csvData = transformPackagesToCsvData(packages);

    test:assertEquals(csvData[1][3], "999999999", "Should handle large totalPullCount");
    test:assertEquals(csvData[1][4], "888888888", "Should handle large pullCount");
}

@test:Config
function testPackageWithManyKeywords() {
    string[] manyKeywords = [
        "k1",
        "k2",
        "k3",
        "k4",
        "k5",
        "k6",
        "k7",
        "k8",
        "k9",
        "k10",
        "k11",
        "k12",
        "k13",
        "k14",
        "k15",
        "k16",
        "k17",
        "k18",
        "k19",
        "k20"
    ];

    Package pkg = {
        name: "feature-rich",
        URL: "https://central.ballerina.io/org/feature-rich",
        version: "1.0.0",
        totalPullCount: 100,
        pullCount: 10,
        keywords: manyKeywords,
        createdDate: 1585699200000
    };

    Package[] packages = [pkg];
    map<string[]> keywords = categorize(packages);

    test:assertEquals(keywords.length(), 20, "Should handle packages with many keywords");
}

@test:Config
function testTransformPackagesToCsvDataWithNullValues() {
    Package pkg1 = {
        name: "pkg1",
        URL: "url1",
        version: "1.0.0",
        totalPullCount: (),
        pullCount: 100,
        createdDate: 1585699200000
    };

    Package pkg2 = {
        name: "pkg2",
        URL: "url2",
        version: "2.0.0",
        totalPullCount: 500,
        pullCount: 200,
        createdDate: 1585699200000
    };

    Package[] packages = [pkg1, pkg2];
    string[][] csvData = transformPackagesToCsvData(packages);

    test:assertEquals(csvData[1][3], "N/A", "First package should have N/A for null totalPullCount");
    test:assertEquals(csvData[2][3], "500", "Second package should have actual totalPullCount");
}

@test:Config
function testShouldSkipPackageMultiplePrefixes() {
    string[] prefixes = ["health.", "internal.", "test."];

    test:assertTrue(shouldSkipPackage("health.fhir", prefixes), "Should skip health prefix");
    test:assertTrue(shouldSkipPackage("internal.util", prefixes), "Should skip internal prefix");
    test:assertTrue(shouldSkipPackage("test.mock", prefixes), "Should skip test prefix");
    test:assertFalse(shouldSkipPackage("http", prefixes), "Should not skip non-matching package");
}

@test:Config
function testShouldSkipPackagePartialMatch() {
    string[] prefixes = ["health."];

    test:assertTrue(shouldSkipPackage("health.fhir.r4", prefixes), "Should skip with longer match");
    test:assertFalse(shouldSkipPackage("healthcare", prefixes), "Should not skip partial word match");
}

@test:Config
function testCategorizeKeywordsDeepNesting() {
    map<string[]> keywords = {
        "cloud/aws/s3": ["pkg1"],
        "cloud/aws/ec2": ["pkg2"],
        "cloud/azure": ["pkg3"]
    };

    map<string[]> result = categorizeKeywords(keywords);

    // Function only extracts first level parent
    test:assertTrue(result.hasKey("cloud"), "Should extract 'cloud' parent");

    string[]? cloudChildren = result["cloud"];
    if cloudChildren is string[] {
        test:assertEquals(cloudChildren.length(), 3, "Should have 3 cloud children");
        test:assertTrue(cloudChildren.indexOf("aws/s3") != (), "Should include 'aws/s3'");
        test:assertTrue(cloudChildren.indexOf("aws/ec2") != (), "Should include 'aws/ec2'");
        test:assertTrue(cloudChildren.indexOf("azure") != (), "Should include 'azure'");
    }
}

@test:Config
function testFormatTimestampToDateEpoch() {
    // Test Unix epoch (0 milliseconds)
    string result = formatTimestampToDate(0);

    test:assertEquals(result, "1970-1-1", "Should handle Unix epoch");
}

@test:Config
function testFormatTimestampToDateRecentDate() {
    // January 1, 2024 00:00:00 UTC = 1704067200 seconds = 1704067200000 milliseconds
    string result = formatTimestampToDate(1704067200000);

    test:assertEquals(result, "2024-1-1", "Should format 2024-01-01 correctly");
}

@test:Config
function testFormatTimestampToDateLeapYear() {
    // February 29, 2024 (leap year) = 1709251200 seconds = 1709251200000 milliseconds
    string result = formatTimestampToDate(1709251200000);

    test:assertTrue(result.includes("2024"), "Should handle leap year dates");
}

@test:Config
function testTransformKeywordsToCsvDataSingleKeyword() {
    map<string[]> keywords = {
        "singleton": ["pkg1"]
    };

    string[][] result = transformKeywordsToCsvData(keywords);

    // Non-rotated format: header + 1 data row
    test:assertEquals(result.length(), 2, "Should have header + 1 data row");
    test:assertEquals(result[0], ["Keyword", "Package Count", "Packages"], "Should have proper headers");
    test:assertEquals(result[1][0], "singleton", "First column should be keyword");
    test:assertEquals(result[1][1], "1", "Second column should be package count");
    test:assertEquals(result[1][2], "pkg1", "Third column should be package");
}

@test:Config
function testTransformKeywordsToCsvDataManyPackages() {
    string[] manyPackages = [];
    int i = 0;
    while i < 100 {
        manyPackages.push(string `pkg${i}`);
        i = i + 1;
    }

    map<string[]> keywords = {
        "popular": manyPackages
    };

    string[][] result = transformKeywordsToCsvData(keywords);

    // Non-rotated format: header + 1 data row with all packages in separate columns
    test:assertEquals(result.length(), 2, "Should have header + 1 data row");
    test:assertEquals(result[0], ["Keyword", "Package Count", "Packages"], "Should have proper headers");
    test:assertEquals(result[1][0], "popular", "First column should be keyword");
    test:assertEquals(result[1][1], "100", "Second column should be package count");
    test:assertEquals(result[1].length(), 102, "Should have 102 columns (keyword + count + 100 packages)");
}

@test:Config
function testFilterKeywordsMixedThreshold() {
    map<string[]> keywords = {
        "very-popular": ["p1", "p2", "p3", "p4", "p5"],
        "popular": ["p1", "p2", "p3"],
        "common": ["p1", "p2"],
        "rare": ["p1"]
    };

    // With default threshold of 1, all should pass
    map<string[]> result = filterKeywords(keywords);

    test:assertEquals(result.length(), 4, "With threshold 1, all keywords should pass");
    test:assertTrue(result.hasKey("very-popular"), "Should include very-popular");
    test:assertTrue(result.hasKey("rare"), "Should include rare with threshold 1");
}

@test:Config
function testTransformPackagesToSheetDataWithLongURL() {
    Package pkg = {
        name: "very-long-package-name",
        URL: "https://central.ballerina.io/org/very-long-package-name/versions/v1.2.3-alpha.1",
        version: "1.2.3-alpha.1",
        totalPullCount: 100,
        pullCount: 10,
        keywords: [],
        createdDate: 1585699200000
    };

    Package[] packages = [pkg];
    string[][] result = transformPackagesToSheetData(packages);

    // Check that hyperlink formula is properly formed
    test:assertTrue(result[1][0].startsWith("=HYPERLINK(\""), "Should start with HYPERLINK formula");
    test:assertTrue(result[1][0].includes("very-long-package-name"), "Should include package name");
}

@test:Config
function testTransformPackagesToSheetDataWithQuotesInName() {
    Package pkg = {
        name: "normal-package",
        URL: "https://central.ballerina.io/org/package",
        version: "1.0.0",
        totalPullCount: 100,
        pullCount: 10,
        keywords: [],
        createdDate: 1585699200000
    };

    Package[] packages = [pkg];
    string[][] result = transformPackagesToSheetData(packages);

    test:assertTrue(result[1][0].includes("normal-package"), "Should handle normal package names");
}

@test:Config
function testFormatCivilToDateLeapYear() {
    time:Civil civil = {
        year: 2024,
        month: 2,
        day: 29,
        hour: 0,
        minute: 0,
        second: 0
    };

    string result = formatCivilToDate(civil);

    test:assertEquals(result, "2024-2-29", "Should format leap year date");
}

@test:Config
function testFormatCivilToDateDecember() {
    time:Civil civil = {
        year: 2023,
        month: 12,
        day: 31,
        hour: 23,
        minute: 59,
        second: 59
    };

    string result = formatCivilToDate(civil);

    test:assertEquals(result, "2023-12-31", "Should format year-end date");
}
