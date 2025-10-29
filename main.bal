import ballerina/file;
import ballerina/graphql;
import ballerina/io;
import ballerina/lang.runtime;

const string BALLERINA_CENTRAL_GRAPHQL_URL = "https://api.central.ballerina.io/2.0/graphql";
const string BALLERINA_CENTRAL_URL = "https://central.ballerina.io";

const string JSON_FILE_EXTENSION = ".json";
const string CSV_FILE_EXTENSION = ".csv";

// Rate limit is 50 requests per minute. Sleep for 1.5 seconds after each request to avoid rate limiting.
const decimal SLEEP_TIMER = 1.5;

const string RESULTS_DIR = "results";

final string packageListFilePath = string `${orgName}-package-list`;
final string keywordsFilePath = string `${orgName}-keywords`;
final string filteredKeywordsFilePath = string `${orgName}-filtered-keywords`;
final string categorizedKeywordsFilePath = string `${orgName}-categorized-keywords`;

final graphql:Client ballerinaCentral = check new (BALLERINA_CENTRAL_GRAPHQL_URL);

final string timestamp = check getTimestamp();

public function main() {
    do {
        check validateConfiguration();
        printInfo("Starting Ballerina Central package analysis");
        printInfo(string `Target organization: ${orgName}`);
        printInfo(string `Configuration: Package List=${needPackageListFromCentral}, Pull Count=${needTotalPullCount}, Keywords=${needKeywordAnalysis}, CSV Export=${needCsvExport}`);

        Package[] packages = check retrieveAndEnrichPackages();
        KeywordAnalysisResult analysis = check performKeywordAnalysis(packages);

        DataOutput dataOutput = {
            packages,
            keywords: analysis.keywords,
            filteredKeywords: analysis.filteredKeywords,
            categorizedKeywords: analysis.categorizedKeywords
        };

        check writeDataBatch(dataOutput);
        printSuccess(string `All data exported to ${RESULTS_DIR}/ directory`);

        printSuccess(string `Analysis complete!`);
        printStats(string `Total packages analyzed: ${packages.length()}`);
    } on fail error err {
        printError(err);
        printWarning("Application terminated due to error");
    }
}

isolated function retrieveAndEnrichPackages() returns Package[]|error {
    Package[] packages = check retrievePackageList();
    printStats(string `Retrieved ${packages.length()} packages from ${orgName}`);

    if needTotalPullCount {
        getPullCount(packages);
    }

    return packages;
}

isolated function performKeywordAnalysis(Package[] packages) returns KeywordAnalysisResult|error {
    if !needKeywordAnalysis {
        return {
            keywords: (),
            filteredKeywords: (),
            categorizedKeywords: ()
        };
    }

    printProgress("Analyzing package keywords and creating categorization");
    [map<string[]>, map<string[]>] [keywordMap, filteredKeywordMap] = analyzeKeywords(packages);
    map<string[]> categorizedKeywordMap = categorizeKeywords(keywordMap);

    printStats(string `Found ${keywordMap.keys().length()} unique keywords across all packages`);
    printStats(string `Filtered to ${filteredKeywordMap.keys().length()} keywords (appearing in ≥${minPackagesPerKeyword} packages)`);

    printSuccess("Keyword analysis completed");

    return {
        keywords: keywordMap,
        filteredKeywords: filteredKeywordMap,
        categorizedKeywords: categorizedKeywordMap
    };
}

isolated function validateConfiguration() returns error? {
    check validateBasicConfig();
    check validateDateConfig();
    check validateGoogleSheetsConfig();
}

isolated function validateBasicConfig() returns error? {
    if orgName.trim().length() == 0 {
        return error("Organization name cannot be empty");
    }

    if 'limit <= 0 {
        return error("Limit must be a positive number");
    }

    if 'offset < 0 {
        return error("Offset must be zero or positive");
    }

    if minPackagesPerKeyword < 1 {
        return error("minPackagesPerKeyword must be at least 1");
    }
}

isolated function validateDateConfig() returns error? {
    string? pullStartDate = pullStatStartDate;
    if pullStartDate is string && 'string:trim(pullStartDate).length() > 0 {
        if !isValidISODate(pullStartDate) {
            return error("pullStatStartDate must be in ISO date format (YYYY-MM-DD)");
        }
    }

    string? pullEndDate = pullStatEndDate;
    if pullEndDate is string && 'string:trim(pullEndDate).length() > 0 {
        if !isValidISODate(pullEndDate) {
            return error("pullStatEndDate must be in ISO date format (YYYY-MM-DD)");
        }
    }
}

isolated function validateGoogleSheetsConfig() returns error? {
    if needGoogleSheetExport {
        GoogleSheetConfig? authConfig = googleSheetAuthConfig;
        if authConfig is () {
            return error("googleSheetAuthConfig must be provided when needGoogleSheetExport is true");
        }
    }
}

isolated function isValidISODate(string dateStr) returns boolean {
    // Basic ISO date format validation (YYYY-MM-DD)
    if dateStr.length() != 10 {
        return false;
    }

    // Check pattern: YYYY-MM-DD
    if dateStr[4] != "-" || dateStr[7] != "-" {
        return false;
    }

    // Check if year, month, day are numeric
    string yearStr = dateStr.substring(0, 4);
    string monthStr = dateStr.substring(5, 7);
    string dayStr = dateStr.substring(8, 10);

    int|error year = int:fromString(yearStr);
    int|error month = int:fromString(monthStr);
    int|error day = int:fromString(dayStr);

    if year is error || month is error || day is error {
        return false;
    }

    // Basic range validation
    return year >= 2000 && year <= 3000 && month >= 1 && month <= 12 && day >= 1 && day <= 31;
}

isolated function retrievePackageList() returns Package[]|error {
    if needPackageListFromCentral {
        return check retrievePackageListFromCentral();
    }
    return check retrievePackageListFromFile();
}

isolated function retrievePackageListFromFile() returns Package[]|error {
    do {
        string latestExistingResultsDirectory = check getLatestExistingResultsDirectory();
        string latestResultsFile = check file:joinPath(latestExistingResultsDirectory, packageListFilePath);
        printInfo(string `Loading package list from existing file: ${latestResultsFile}${JSON_FILE_EXTENSION}`);
        return (check io:fileReadJson(string `${latestResultsFile}${JSON_FILE_EXTENSION}`)).fromJsonWithType();
    } on fail error err {
        return error("Failed to load package list from file", err);
    }
}

isolated function retrievePackageListFromCentral() returns Package[]|error {
    do {
        printProgress(string `Fetching package list from Ballerina Central for organization: ${orgName}`);
        printInfo(string `Requesting packages with limit: ${'limit}, offset: ${offset}`);

        Package[] packages = check fetchPackagesFromAPI();
        printStats(string `Retrieved ${packages.length()} packages from Central API`);

        Package[] transformedPackages = transformPackageURLs(packages);
        Package[] finalPackages = applyPackageFilters(transformedPackages);

        return finalPackages;
    } on fail error err {
        return error("Failed to retrieve package list from Ballerina Central", err);
    }
}

isolated function fetchPackagesFromAPI() returns Package[]|error {
    RetrievePackageListInput input = {orgName, 'limit, offset};
    PackageListResponse response = check ballerinaCentral->execute(GET_PACKAGE_LIST_QUERY, input);
    return response.data.packages.packages;
}

isolated function transformPackageURLs(Package[] packages) returns Package[] {
    return from Package package in packages
        select {
            name: package.name,
            URL: string `${BALLERINA_CENTRAL_URL}${package.URL}`,
            version: package.version,
            totalPullCount: package.totalPullCount,
            keywords: package.keywords,
            pullCount: package.pullCount,
            createdDate: package.createdDate
        };
}

isolated function applyPackageFilters(Package[] packages) returns Package[] {
    if skipPackagePrefixes.length() == 0 {
        printInfo("Processing all packages");
        return packages;
    }

    printInfo(string `Filtering out packages with prefixes: ${skipPackagePrefixes.toString()}`);
    Package[] filteredPackages = [];
    foreach Package package in packages {
        if shouldSkipPackage(package.name, skipPackagePrefixes) {
            printInfo(string `Skipping package: ${package.name}`);
            continue;
        }
        filteredPackages.push(package);
    }
    printStats(string `After filtering: ${filteredPackages.length()} packages (excluded ${packages.length() - filteredPackages.length()} packages)`);
    return filteredPackages;
}

isolated function getTotalPullCount(Package package) returns error? {
    do {
        TotalPullCountInput input = {
            orgName,
            packageName: package.name,
            version: package.version,
            pullStatStartDate,
            pullStatEndDate
        };
        TotalPullCountResponse response = check ballerinaCentral->execute(GET_TOTAL_PULL_COUNT_QUERY, input);
        package.totalPullCount = response?.data?.package?.totalPullCount;
    } on fail error err {
        return error(string `Failed to get pull count for package: ${package.name}`, err);
    }
}

isolated function analyzeKeywords(Package[] packages) returns [map<string[]>, map<string[]>] {
    printProgress("Categorizing keywords by package");
    map<string[]> keywordMap = categorize(packages);

    printProgress("Filtering keywords based on minimum package threshold");
    map<string[]> filteredKeywordMap = filterKeywords(keywordMap);

    return [keywordMap, filteredKeywordMap];
}

isolated function categorize(Package[] packages) returns map<string[]> {
    map<string[]> keywordMap = {};
    int packagesWithKeywords = 0;

    foreach Package package in packages {
        string[] packageKeywords = package.keywords;
        if packageKeywords.length() > 0 {
            packagesWithKeywords += 1;
        }
        foreach string keyword in packageKeywords {
            if keywordMap.hasKey(keyword) {
                keywordMap.get(keyword).push(package.name);
            } else {
                keywordMap[keyword] = [package.name];
            }
        }
    }

    printStats(string `Packages with keywords: ${packagesWithKeywords}/${packages.length()}`);
    return keywordMap;
}

isolated function filterKeywords(map<string[]> keywordMap) returns map<string[]> {
    map<string[]> filteredKeywordMap = {};
    int totalKeywords = keywordMap.keys().length();
    int filteredCount = 0;

    foreach string keyword in keywordMap.keys() {
        if keywordMap.get(keyword).length() >= minPackagesPerKeyword {
            filteredKeywordMap[keyword] = keywordMap.get(keyword);
            filteredCount += 1;
        }
    }

    printStats(string `Keyword filtering: ${filteredCount}/${totalKeywords} keywords meet threshold (≥${minPackagesPerKeyword} packages)`);
    return filteredKeywordMap;
}

isolated function getPullCount(Package[] packages) {
    do {
        printProgress("Fetching total pull count statistics for all packages (optimized batching)");

        // Process in batches of 3 to stay under API rate limit (50 req/min)
        // With 0.5s sleep per request = 2 req/sec = ~120 req/min max (well under limit)
        int batchSize = 3;
        int processedCount = 0;
        int totalPackages = packages.length();

        int i = 0;
        while i < totalPackages {
            // Calculate batch end index
            int endIdx = int:min(i + batchSize, totalPackages);

            // Process batch sequentially with minimal sleep
            int j = i;
            while j < endIdx {
                Package package = packages[j];
                error? result = getTotalPullCount(package);
                if result is error {
                    printWarning(string `Failed to get pull count for ${package.name}: ${result.message()}`);
                }
                j = j + 1;
                // Short sleep between requests within batch
                if j < endIdx {
                    runtime:sleep(0.5);
                }
            }

            processedCount += (endIdx - i);
            if processedCount % 10 == 0 {
                printProgress(string `Processed ${processedCount}/${totalPackages} packages for pull count data`);
            }

            // Longer sleep between batches to maintain rate limiting
            if endIdx < totalPackages {
                runtime:sleep(1.0);
            }

            i = endIdx;
        }
        printSuccess(string `Successfully retrieved pull count data for ${totalPackages} packages`);
    } on fail error err {
        printError(err);
        printWarning("Proceeding with package data without pull count statistics");
    }
}
