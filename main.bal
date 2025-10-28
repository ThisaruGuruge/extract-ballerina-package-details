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

public function main() returns error? {
    check validateConfiguration();
    printInfo("Starting Ballerina Central package analysis");
    printInfo(string `Target organization: ${orgName}`);
    printInfo(string `Configuration: Package List=${needPackageListFromCentral}, Pull Count=${needTotalPullCount}, Keywords=${needKeywordAnalysis}, CSV Export=${needCsvExport}`);

    Package[] packages = check retrievePackageList();
    printStats(string `Retrieved ${packages.length()} packages from ${orgName}`);

    if needTotalPullCount {
        getPullCount(packages);
    }

    // Prepare data output
    DataOutput dataOutput = {
        packages: packages
    };

    if needKeywordAnalysis {
        printProgress("Analyzing package keywords and creating categorization");
        [map<string[]>, map<string[]>] [keywordMap, filteredKeywordMap] = analyzeKeywords(packages);
        map<string[]> categorizedKeywordMap = categorizeKeywords(keywordMap);

        printStats(string `Found ${keywordMap.keys().length()} unique keywords across all packages`);
        printStats(string `Filtered to ${filteredKeywordMap.keys().length()} keywords (appearing in ≥${minPackagesPerKeyword} packages)`);

        dataOutput.keywords = keywordMap;
        dataOutput.filteredKeywords = filteredKeywordMap;
        dataOutput.categorizedKeywords = categorizedKeywordMap;

        printSuccess("Keyword analysis completed");
    }

    // Write all data in batch
    check writeDataBatch(dataOutput);
    printSuccess(string `All data exported to ${RESULTS_DIR}/ directory`);

    printSuccess(string `Analysis complete!`);
    printStats(string `Total packages analyzed: ${packages.length()}`);
}

isolated function validateConfiguration() returns error? {
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

    // Validate date formats if provided
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
    string latestExistingResultsDirectory = check getLatestExistingResultsDirectory();
    string latestResultsFile = check file:joinPath(latestExistingResultsDirectory, packageListFilePath);
    printInfo(string `Loading package list from existing file: ${latestResultsFile}${JSON_FILE_EXTENSION}`);
    return (check io:fileReadJson(string `${latestResultsFile}${JSON_FILE_EXTENSION}`)).fromJsonWithType();
}

isolated function retrievePackageListFromCentral() returns Package[]|error {
    printProgress(string `Fetching package list from Ballerina Central for organization: ${orgName}`);
    printInfo(string `Requesting packages with limit: ${'limit}, offset: ${offset}`);

    RetrievePackageListInput input = {
        orgName,
        'limit,
        offset
    };
    PackageListResponse packageListResponse = check ballerinaCentral->execute(GET_PACKAGE_LIST_QUERY, input);
    Package[] packages = packageListResponse.data.packages.packages;

    printStats(string `Retrieved ${packages.length()} packages from Central API`);

    Package[] transformedPackages = from Package package in packages
        select {
            name: package.name,
            URL: string `${BALLERINA_CENTRAL_URL}${package.URL}`,
            version: package.version,
            totalPullCount: package.totalPullCount,
            keywords: package.keywords,
            pullCount: package.pullCount
        };

    if skipPackagePrefixes.length() > 0 {
        printInfo(string `Filtering out packages with prefixes: ${skipPackagePrefixes.toString()}`);
        Package[] filteredPackages = [];
        foreach Package package in transformedPackages {
            if shouldSkipPackage(package.name, skipPackagePrefixes) {
                printInfo(string `Skipping package: ${package.name}`);
                continue;
            }
            filteredPackages.push(package);
        }
        printStats(string `After filtering: ${filteredPackages.length()} packages (excluded ${transformedPackages.length() - filteredPackages.length()} packages)`);
        return filteredPackages;
    }

    printInfo("Processing all packages");
    return transformedPackages;
}

isolated function getTotalPullCount(Package package) returns error? {
    TotalPullCountInput input = {
        orgName,
        packageName: package.name,
        version: package.version,
        pullStatStartDate,
        pullStatEndDate
    };
    TotalPullCountResponse response = check ballerinaCentral->execute(GET_TOTAL_PULL_COUNT_QUERY, input);
    package.totalPullCount = response?.data?.package?.totalPullCount;
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
        printProgress("Fetching total pull count statistics for all packages");
        int processedCount = 0;
        foreach Package package in packages {
            check getTotalPullCount(package);
            processedCount += 1;
            if processedCount % 10 == 0 {
                printProgress(string `Processed ${processedCount}/${packages.length()} packages for pull count data`);
            }
            runtime:sleep(SLEEP_TIMER); // To avoid rate limiting
        }
        printSuccess(string `Successfully retrieved pull count data for ${packages.length()} packages`);
    } on fail error err {
        printWarning(string `Failed to retrieve total pull count data. Error: ${err.message()}`);
        printInfo("Proceeding with package data without pull count statistics");
    }
}
