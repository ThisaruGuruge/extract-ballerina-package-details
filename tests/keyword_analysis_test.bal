import ballerina/test;

// Test data setup
Package testPackage1 = {
    name: "http",
    URL: "https://central.ballerina.io/ballerina/http",
    version: "2.9.0",
    totalPullCount: 1000,
    pullCount: 100,
    keywords: ["network", "http", "rest"],
    createdDate: 1585699200000
};

Package testPackage2 = {
    name: "graphql",
    URL: "https://central.ballerina.io/ballerina/graphql",
    version: "1.0.0",
    totalPullCount: 500,
    pullCount: 50,
    keywords: ["network", "graphql", "api"],
    createdDate: 1585699200000
};

Package testPackage3 = {
    name: "mysql",
    URL: "https://central.ballerina.io/ballerina/mysql",
    version: "1.5.0",
    totalPullCount: 800,
    pullCount: 80,
    keywords: ["database", "sql"],
    createdDate: 1585699200000
};

Package testPackageNoKeywords = {
    name: "basic",
    URL: "https://central.ballerina.io/ballerina/basic",
    version: "1.0.0",
    totalPullCount: 100,
    pullCount: 10,
    keywords: [],
    createdDate: 1585699200000
};

@test:Config
function testCategorizeKeywords() {
    Package[] packages = [testPackage1, testPackage2, testPackage3];

    map<string[]> result = categorize(packages);

    test:assertEquals(result.length(), 7, "Should have 7 unique keywords");
    test:assertTrue(result.hasKey("network"), "Should have 'network' keyword");
    test:assertTrue(result.hasKey("http"), "Should have 'http' keyword");
    test:assertTrue(result.hasKey("database"), "Should have 'database' keyword");

    string[]? networkPackages = result["network"];
    test:assertTrue(networkPackages is string[], "Network should have packages");
    if networkPackages is string[] {
        test:assertEquals(networkPackages.length(), 2, "Network should appear in 2 packages");
        test:assertTrue(networkPackages.indexOf("http") != (), "Should include http package");
        test:assertTrue(networkPackages.indexOf("graphql") != (), "Should include graphql package");
    }

    string[]? httpPackages = result["http"];
    if httpPackages is string[] {
        test:assertEquals(httpPackages.length(), 1, "HTTP should appear in 1 package");
        test:assertEquals(httpPackages[0], "http", "Should be http package");
    }
}

@test:Config
function testCategorizeKeywordsWithEmpty() {
    Package[] packages = [testPackage1, testPackageNoKeywords];

    map<string[]> result = categorize(packages);

    // Should only include keywords from testPackage1
    test:assertEquals(result.length(), 3, "Should have 3 keywords (from package with keywords)");
}

@test:Config
function testCategorizeKeywordsEmptyPackages() {
    Package[] packages = [];

    map<string[]> result = categorize(packages);

    test:assertEquals(result.length(), 0, "Should return empty map for empty package list");
}

@test:Config
function testFilterKeywordsBasic() {
    map<string[]> keywords = {
        "popular": ["pkg1", "pkg2", "pkg3"],
        "common": ["pkg1", "pkg2"],
        "rare": ["pkg1"]
    };

    // Test with default minPackagesPerKeyword value (configured as 1)
    map<string[]> result = filterKeywords(keywords);

    // With default threshold of 1, all keywords should pass
    test:assertEquals(result.length(), 3, "With threshold 1, all keywords should pass");
}

@test:Config
function testFilterKeywordsEmpty() {
    map<string[]> keywords = {};

    map<string[]> result = filterKeywords(keywords);

    test:assertEquals(result.length(), 0, "Should handle empty keyword map");
}

@test:Config
function testAnalyzeKeywords() {
    Package[] packages = [testPackage1, testPackage2, testPackage3];

    [map<string[]>, map<string[]>] [allKeywords, filteredKeywords] = analyzeKeywords(packages);

    test:assertTrue(allKeywords.length() > 0, "Should have all keywords");
    test:assertTrue(filteredKeywords.length() > 0, "Should have filtered keywords");
    test:assertTrue(filteredKeywords.length() <= allKeywords.length(), "Filtered should be subset of all");
}
