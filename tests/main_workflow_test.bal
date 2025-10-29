import ballerina/test;

// Test data
Package testPkg1 = {
    name: "http",
    URL: "/ballerina/http",
    version: "2.9.0",
    totalPullCount: 1000,
    pullCount: 100,
    keywords: ["network"],
    createdDate: 1585699200000
};

Package testPkg2 = {
    name: "health.fhir",
    URL: "/ballerina/health.fhir",
    version: "1.0.0",
    totalPullCount: 500,
    pullCount: 50,
    keywords: ["health"],
    createdDate: 1585699200000
};

@test:Config
function testTransformPackageURLs() {
    Package[] packages = [testPkg1];

    Package[] result = transformPackageURLs(packages);

    test:assertEquals(result.length(), 1, "Should return same number of packages");
    test:assertTrue(result[0].URL.startsWith("https://central.ballerina.io"), "Should prepend base URL");
    test:assertTrue(result[0].URL.includes("/ballerina/http"), "Should include original path");
    test:assertEquals(result[0].name, "http", "Should preserve package name");
}

@test:Config
function testTransformPackageURLsEmpty() {
    Package[] packages = [];

    Package[] result = transformPackageURLs(packages);

    test:assertEquals(result.length(), 0, "Should handle empty package list");
}

@test:Config
function testTransformPackageURLsMultiple() {
    Package[] packages = [testPkg1, testPkg2];

    Package[] result = transformPackageURLs(packages);

    test:assertEquals(result.length(), 2, "Should transform all packages");
    test:assertTrue(result[0].URL.startsWith("https://central.ballerina.io"), "First package URL");
    test:assertTrue(result[1].URL.startsWith("https://central.ballerina.io"), "Second package URL");
}

@test:Config
function testApplyPackageFiltersNoFilters() {
    Package[] packages = [testPkg1, testPkg2];

    Package[] result = applyPackageFilters(packages);

    test:assertEquals(result.length(), 2, "Should not filter when no prefixes provided");
}

@test:Config
function testApplyPackageFiltersWithSkip() {
    Package testPkg3 = {
        name: "io",
        URL: "/ballerina/io",
        version: "1.0.0",
        totalPullCount: 800,
        pullCount: 80,
        keywords: [],
        createdDate: 1585699200000
    };

    Package[] packages = [testPkg1, testPkg2, testPkg3];

    // Note: This test won't work perfectly without being able to mock configurables,
    // but it tests the logic flow
    Package[] result = packages.filter(pkg => !shouldSkipPackage(pkg.name, ["health."]));

    test:assertEquals(result.length(), 2, "Should filter out health packages");
    test:assertFalse(result.some(pkg => pkg.name.startsWith("health.")), "Should not contain health packages");
}

@test:Config
function testCategorizeEmptyPackages() {
    Package[] packages = [];

    map<string[]> result = categorize(packages);

    test:assertEquals(result.length(), 0, "Should return empty map for empty packages");
}

@test:Config
function testCategorizePackagesWithNoKeywords() {
    Package noKeywordPkg = {
        name: "test",
        URL: "/test",
        version: "1.0.0",
        totalPullCount: 100,
        pullCount: 10,
        keywords: [],
        createdDate: 1585699200000
    };

    Package[] packages = [noKeywordPkg];

    map<string[]> result = categorize(packages);

    test:assertEquals(result.length(), 0, "Should return empty map when packages have no keywords");
}

@test:Config
function testCategorizePackagesWithDuplicateKeywords() {
    Package pkg1 = {
        name: "http",
        URL: "/http",
        version: "1.0.0",
        totalPullCount: 100,
        pullCount: 10,
        keywords: ["network", "http"],
        createdDate: 1585699200000
    };

    Package pkg2 = {
        name: "tcp",
        URL: "/tcp",
        version: "1.0.0",
        totalPullCount: 100,
        pullCount: 10,
        keywords: ["network", "tcp"],
        createdDate: 1585699200000
    };

    Package[] packages = [pkg1, pkg2];

    map<string[]> result = categorize(packages);

    test:assertTrue(result.hasKey("network"), "Should have 'network' keyword");

    string[]? networkPackages = result["network"];
    if networkPackages is string[] {
        test:assertEquals(networkPackages.length(), 2, "Network keyword should appear in 2 packages");
        test:assertTrue(networkPackages.indexOf("http") != (), "Should include http");
        test:assertTrue(networkPackages.indexOf("tcp") != (), "Should include tcp");
    }
}

@test:Config
function testFilterKeywordsAllMatch() {
    map<string[]> keywords = {
        "popular1": ["pkg1", "pkg2", "pkg3"],
        "popular2": ["pkg4", "pkg5"]
    };

    // With default minPackagesPerKeyword = 1, all should pass
    map<string[]> result = filterKeywords(keywords);

    test:assertEquals(result.length(), 2, "All keywords should pass with threshold 1");
}

@test:Config
function testFilterKeywordsNoneMatch() {
    map<string[]> keywords = {
        "rare1": [],
        "rare2": []
    };

    map<string[]> result = filterKeywords(keywords);

    // With minPackagesPerKeyword = 1, empty arrays won't match
    test:assertEquals(result.length(), 0, "Empty keyword arrays should not pass");
}

@test:Config
function testAnalyzeKeywordsComplete() {
    Package pkg1 = {
        name: "http",
        URL: "/http",
        version: "1.0.0",
        totalPullCount: 100,
        pullCount: 10,
        keywords: ["network", "http", "rest"],
        createdDate: 1585699200000
    };

    Package pkg2 = {
        name: "grpc",
        URL: "/grpc",
        version: "1.0.0",
        totalPullCount: 100,
        pullCount: 10,
        keywords: ["network", "rpc"],
        createdDate: 1585699200000
    };

    Package[] packages = [pkg1, pkg2];

    [map<string[]>, map<string[]>] [allKeywords, _] = analyzeKeywords(packages);

    test:assertEquals(allKeywords.length(), 4, "Should have 4 unique keywords");
    test:assertTrue(allKeywords.hasKey("network"), "Should have 'network' keyword");
    test:assertTrue(allKeywords.hasKey("http"), "Should have 'http' keyword");
    test:assertTrue(allKeywords.hasKey("rest"), "Should have 'rest' keyword");
    test:assertTrue(allKeywords.hasKey("rpc"), "Should have 'rpc' keyword");
}

@test:Config
function testValidateBasicConfigValidData() {
    // With valid test configuration (orgName = "test-org", limit = 100, etc.)
    // the function should return () (no error)
    error? result = validateBasicConfig();

    test:assertEquals(result, (), "Should return no error with valid config");
}

@test:Config
function testValidateDateConfigValidDates() {
    // With empty date strings in test config, validation should pass
    error? result = validateDateConfig();

    test:assertEquals(result, (), "Should return no error with empty/valid dates");
}

@test:Config
function testIsValidISODateEdgeCases() {
    // Additional edge cases beyond validation_test.bal
    test:assertFalse(isValidISODate("2024-00-01"), "Should reject month 0");
    test:assertFalse(isValidISODate("2024-01-00"), "Should reject day 0");
    test:assertTrue(isValidISODate("2024-12-31"), "Should accept valid year-end date");
    test:assertTrue(isValidISODate("2024-01-01"), "Should accept valid year-start date");
}

@test:Config
function testIsValidISODateFutureDate() {
    test:assertTrue(isValidISODate("2999-12-31"), "Should accept far future date within range");
    test:assertFalse(isValidISODate("3001-01-01"), "Should reject date beyond year 3000");
}

@test:Config
function testIsValidISODatePastDate() {
    test:assertTrue(isValidISODate("2000-01-01"), "Should accept year 2000");
    test:assertFalse(isValidISODate("1999-12-31"), "Should reject year 1999");
}

@test:Config
function testIsValidISODateSpecialCharacters() {
    test:assertFalse(isValidISODate("2024-01-01 "), "Should reject trailing space");
    test:assertFalse(isValidISODate(" 2024-01-01"), "Should reject leading space");
    test:assertFalse(isValidISODate("2024/01/01"), "Should reject slashes");
    test:assertFalse(isValidISODate("2024.01.01"), "Should reject dots");
}

@test:Config
function testPerformKeywordAnalysisDisabled() returns error? {
    Package[] packages = [testPkg1];

    // Test config has needKeywordAnalysis = false
    KeywordAnalysisResult result = check performKeywordAnalysis(packages);

    // When disabled, all keyword fields should be ()
    test:assertEquals(result.keywords, (), "Keywords should be null when analysis disabled");
    test:assertEquals(result.filteredKeywords, (), "Filtered keywords should be null when analysis disabled");
    test:assertEquals(result.categorizedKeywords, (), "Categorized keywords should be null when analysis disabled");
}

@test:Config
function testPerformKeywordAnalysisWithPackages() returns error? {
    Package pkg1 = {
        name: "test",
        URL: "/test",
        version: "1.0.0",
        totalPullCount: 100,
        pullCount: 10,
        keywords: ["testing", "unit-test"],
        createdDate: 1585699200000
    };

    Package[] packages = [pkg1];

    KeywordAnalysisResult result = check performKeywordAnalysis(packages);

    // With test config needKeywordAnalysis = false, keywords should be null
    // If you want to test with analysis enabled, you'd need a different test config
    test:assertEquals(result.keywords, (), "With current test config, keywords should be null");
}
