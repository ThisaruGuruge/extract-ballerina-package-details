import ballerina/file;
import ballerina/graphql;
import ballerina/io;
import ballerina/lang.'string;
import ballerina/lang.runtime;

const string BALLERINA_CENTRAL_GRAPHQL_URL = "https://api.central.ballerina.io/2.0/graphql";
const string BALLERINA_CENTRAL_URL = "https://central.ballerina.io";

// Rate limit is 50 requests per minute. Sleep for 1.5 seconds after each request to avoid rate limiting.
const decimal SLEEP_TIMER = 1.5;

const string HEALTHCARE_PACKAGE_PREFIX = "health.";

final string packageListFilePath = check file:joinPath("resources", string `${orgName}-package-list`);
final string keywordsFilePath = check file:joinPath("resources", string `${orgName}-keywords`);
final string filteredKeywordsFilePath = check file:joinPath("resources", string `${orgName}-filtered-keywords`);
final string categorizedKeywordsFilePath = check file:joinPath("resources", string `${orgName}-categorized-keywords`);

configurable boolean needPackageList = true;
configurable boolean needTotalPullCount = false;
configurable boolean needKeywordAnalysis = true;
configurable boolean needCsvExport = true;
configurable boolean skipHealthcarePackages = true;

configurable string orgName = "ballerinax";
configurable int 'limit = 1000;
configurable int 'offset = 0;

configurable string? pullStatStartDate = ();
configurable string? pullStatEndDate = ();

final graphql:Client ballerinaCentral = check new (BALLERINA_CENTRAL_GRAPHQL_URL);

public function main() returns error? {
    Package[] packages = check retrievePackageList();
    do {
        if needTotalPullCount {
            printInfo("Getting total pull count for packages");
            foreach Package package in packages {
                check getTotalPullCount(package);
                runtime:sleep(SLEEP_TIMER); // To avoid rate limiting
            }
        }
    } on fail error err {
        check writeToFile(packageListFilePath, packages);
        printWarning(string `Failed to get total pull count for packages, saved package list to "${packageListFilePath}" without total pull count. Error: ${err.message()}`);
    }
    check writeToFile(packageListFilePath, packages);
    if needKeywordAnalysis {
        printInfo("Analyzing keywords");
        [map<string[]>, map<string[]>] [keywordMap, filteredKeywordMap] = analyzeKeywords(packages);
        map<string[]> categorizedKeywordMap = categorizeKeywords(keywordMap);
        check writeToFile(keywordsFilePath, keywordMap);
        check writeToFile(filteredKeywordsFilePath, filteredKeywordMap);
        check writeToFile(categorizedKeywordsFilePath, categorizedKeywordMap);
    }

    io:println(string `Package list retrieved and saved to ${packageListFilePath}`);
}

isolated function retrievePackageList() returns Package[]|error {
    if needPackageList {
        return check retrievePackageListFromCentral();
    }
    return check retrievePackageListFromFile();
}

isolated function retrievePackageListFromFile() returns Package[]|error {
    printInfo("Retrieving package list from file");
    return (check io:fileReadJson(string `${packageListFilePath}${JSON_FILE_EXTENSION}`)).fromJsonWithType();
}

isolated function retrievePackageListFromCentral() returns Package[]|error {
    printInfo("Retrieving package list from Central");
    RetrievePackageListInput input = {
        orgName,
        'limit,
        offset
    };
    PackageListResponse packageListResponse = check ballerinaCentral->execute(GET_PACKAGE_LIST_QUERY, input);
    Package[] packages = packageListResponse.data.packages.packages;
    if skipHealthcarePackages {
        printInfo("Skipping healthcare packages");
        return from Package package in packages
            where !'string:startsWith(package.name, HEALTHCARE_PACKAGE_PREFIX)
            select {
                name: package.name,
                URL: string `${BALLERINA_CENTRAL_URL}${package.URL}`,
                version: package.version,
                totalPullCount: package.totalPullCount,
                keywords: package.keywords,
                pullCount: package.pullCount
            };
    }
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
    map<string[]> keywordMap = categorize(packages);
    map<string[]> filteredKeywordMap = filterKeywords(keywordMap);
    return [keywordMap, filteredKeywordMap];
}

isolated function categorize(Package[] packages) returns map<string[]> {
    map<string[]> keywordMap = {};
    foreach Package package in packages {
        string[] packageKeywords = package.keywords;
        foreach string keyword in packageKeywords {
            if keywordMap.hasKey(keyword) {
                keywordMap.get(keyword).push(package.name);
            } else {
                keywordMap[keyword] = [package.name];
            }
        }
    }
    return keywordMap;
}

isolated function filterKeywords(map<string[]> keywordMap) returns map<string[]> {
    map<string[]> filteredKeywordMap = {};

    foreach string keyword in keywordMap.keys() {
        if keywordMap.get(keyword).length() > 1 {
            filteredKeywordMap[keyword] = keywordMap.get(keyword);
        }
    }
    return filteredKeywordMap;
}
