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

const string GENERATED_FILES_DIR = "results";

final string packageListFilePath = check file:joinPath(GENERATED_FILES_DIR, string `${orgName}-package-list`);
final string keywordsFilePath = check file:joinPath(GENERATED_FILES_DIR, string `${orgName}-keywords`);
final string filteredKeywordsFilePath = check file:joinPath(GENERATED_FILES_DIR, string `${orgName}-filtered-keywords`);
final string categorizedKeywordsFilePath = check file:joinPath(GENERATED_FILES_DIR, string `${orgName}-categorized-keywords`);

configurable boolean needPackageListFromCentral = true;
configurable boolean needTotalPullCount = false;
configurable boolean needKeywordAnalysis = true;
configurable boolean needCsvExport = true;

# When filtering the keywords, the keyword will be kept if it has at least this many packages.
configurable int minPackagesPerKeyword = 1;

configurable string orgName = "ballerinax";
configurable int 'limit = 1000;
configurable int 'offset = 0;
configurable string[] skipPackagePrefixes = [];

configurable string? pullStatStartDate = ();
configurable string? pullStatEndDate = ();

final graphql:Client ballerinaCentral = check new (BALLERINA_CENTRAL_GRAPHQL_URL);

public function main() returns error? {
    printInfo("Starting Ballerina Central package analysis");
    printInfo(string `Target organization: ${orgName}`);
    printInfo(string `Configuration: Package List=${needPackageListFromCentral}, Pull Count=${needTotalPullCount}, Keywords=${needKeywordAnalysis}, CSV Export=${needCsvExport}`);

    Package[] packages = check retrievePackageList();
    printStats(string `Retrieved ${packages.length()} packages from ${orgName}`);

    do {
        if needTotalPullCount {
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
        }
    } on fail error err {
        check writeToFile(packageListFilePath, packages);
        printWarning(string `Failed to retrieve total pull count data. Error: ${err.message()}`);
        printInfo(string `Package list saved to ${packageListFilePath} without pull count data`);
    }

    check writeToFile(packageListFilePath, packages);
    printSuccess(string `Package data exported to ${packageListFilePath}`);

    if needKeywordAnalysis {
        printProgress("Analyzing package keywords and creating categorization");
        [map<string[]>, map<string[]>] [keywordMap, filteredKeywordMap] = analyzeKeywords(packages);
        map<string[]> categorizedKeywordMap = categorizeKeywords(keywordMap);

        printStats(string `Found ${keywordMap.keys().length()} unique keywords across all packages`);
        printStats(string `Filtered to ${filteredKeywordMap.keys().length()} keywords (appearing in ≥${minPackagesPerKeyword} packages)`);

        check writeToFile(keywordsFilePath, keywordMap);
        check writeToFile(filteredKeywordsFilePath, filteredKeywordMap);
        check writeToFile(categorizedKeywordsFilePath, categorizedKeywordMap);

        printSuccess("Keyword analysis completed and exported");
    }

    printSuccess(string `Analysis complete! All data exported to ${GENERATED_FILES_DIR}/ directory`);
    printStats(string `Total packages analyzed: ${packages.length()}`);
}

isolated function retrievePackageList() returns Package[]|error {
    if needPackageListFromCentral {
        return check retrievePackageListFromCentral();
    }
    return check retrievePackageListFromFile();
}

isolated function retrievePackageListFromFile() returns Package[]|error {
    printInfo(string `Loading package list from existing file: ${packageListFilePath}${JSON_FILE_EXTENSION}`);
    return (check io:fileReadJson(string `${packageListFilePath}${JSON_FILE_EXTENSION}`)).fromJsonWithType();
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

    Package[] filteredPackages = [];
    if skipPackagePrefixes.length() > 0 {
        printInfo(string `Filtering out packages with prefixes: ${skipPackagePrefixes.toString()}`);
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

    printInfo("Processing all packages (healthcare packages included)");
    return from Package package in packages
        select {
            name: package.name,
            URL: string `${BALLERINA_CENTRAL_URL}${package.URL}`,
            version: package.version,
            totalPullCount: package.totalPullCount,
            keywords: package.keywords,
            pullCount: package.pullCount
        };
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
