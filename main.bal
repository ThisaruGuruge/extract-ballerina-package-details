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
        check getPullCount(packages);
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

isolated function getPullCount(Package[] packages) returns error? {
    printProgress("Fetching total pull count statistics for all packages (batched)");

    // Batch packages to reduce API calls (10 packages per request)
    // Rate limit: 50 req/min with 1.5s sleep = 40 req/min
    // 10 packages per batch = 10x fewer API calls
    int batchSize = 10;
    int totalPackages = packages.length();
    int processedCount = 0;

    int i = 0;
    while i < totalPackages {
        int endIdx = int:min(i + batchSize, totalPackages);
        Package[] batch = packages.slice(i, endIdx);

        // Fetch pull counts for entire batch with retry logic
        check getBatchedPullCountsWithRetry(batch, i, endIdx, totalPackages);

        processedCount += batch.length();
        printProgress(string `Processed ${processedCount}/${totalPackages} packages for pull count data`);

        // Sleep to respect rate limiting
        // Add extra delay every 50 batches to prevent connection issues
        if endIdx < totalPackages {
            decimal sleepTime = SLEEP_TIMER;
            if processedCount / batchSize % 50 == 0 {
                sleepTime = 5.0; // Longer pause every 50 batches
                printInfo(string `Taking extended break after ${processedCount} packages to prevent rate limiting`);
            }
            runtime:sleep(sleepTime);
        }

        i = endIdx;
    }

    printSuccess(string `Successfully retrieved pull count data for ${totalPackages} packages in ${(totalPackages + batchSize - 1) / batchSize} batched requests`);
}

isolated function getBatchedPullCountsWithRetry(Package[] packages, int startIdx, int endIdx, int totalPackages) returns error? {
    int maxRetries = 3;
    int attempt = 0;

    while attempt < maxRetries {
        error? result = getBatchedPullCounts(packages);

        if result is () {
            // Success
            return;
        }

        // Failed, decide whether to retry
        attempt += 1;
        if attempt < maxRetries {
            decimal backoffTime = 3.0 * <decimal>attempt; // 3s, 6s, 9s
            printWarning(string `Batch ${startIdx}-${endIdx} failed (attempt ${attempt}/${maxRetries}): ${result.message()}`);
            printInfo(string `Retrying in ${backoffTime} seconds...`);
            runtime:sleep(backoffTime);
        } else {
            // All retries exhausted
            string errorMsg = string `Batch processing failed at packages ${startIdx}-${endIdx} (total: ${totalPackages}). Exiting to prevent partial data.`;
            error batchError = error(errorMsg, result);
            printError(batchError);
            return batchError;
        }
    }
}

isolated function getBatchedPullCounts(Package[] packages) returns error? {
    // Build a batched GraphQL query with aliases for each package
    string query = buildBatchedPullCountQuery(packages);

    do {
        // Execute the batched query
        BatchedPullCountResponse response = check ballerinaCentral->execute(query);

        // Extract pull counts from response and assign to packages
        int idx = 0;
        foreach Package package in packages {
            string alias = string `pkg_${idx}`;
            json? packageData = response.data[alias];

            if packageData is map<json> {
                json? pullCountValue = packageData["totalPullCount"];
                if pullCountValue is int {
                    package.totalPullCount = pullCountValue;
                }
            }
            idx += 1;
        }
    } on fail error err {
        return error(string `Failed to get batched pull counts: ${err.message()}`, err);
    }
}

isolated function buildBatchedPullCountQuery(Package[] packages) returns string {
    // Build a GraphQL query with multiple aliased package queries
    string[] queryParts = [];
    int idx = 0;

    foreach Package package in packages {
        string alias = string `pkg_${idx}`;

        // Build date parameters if configured
        string dateStartParam = "";
        string? startDate = pullStatStartDate;
        if startDate is string {
            dateStartParam = string `, pullStatStartDate: "${startDate}"`;
        }

        string dateEndParam = "";
        string? endDate = pullStatEndDate;
        if endDate is string {
            dateEndParam = string `, pullStatEndDate: "${endDate}"`;
        }

        string packageQuery = string `
            ${alias}: package(
                orgName: "${orgName}",
                packageName: "${package.name}",
                version: "${package.version}"${dateStartParam}${dateEndParam}
            ) {
                totalPullCount
            }`;

        queryParts.push(packageQuery);
        idx += 1;
    }

    return string `query { ${string:'join(" ", ...queryParts)} }`;
}
