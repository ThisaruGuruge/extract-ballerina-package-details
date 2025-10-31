import ballerina/lang.array;

// ============================================
// Sorting Functions
// ============================================

isolated function sortPackages(Package[] packages) returns Package[] {
    // Sort by last updated date (descending), then by total pull count (descending)
    return packages.sort(array:DESCENDING, isolated function(Package pkg) returns [int, int] {
        int createdDate = pkg.createdDate;
        int totalPullCount = pkg.totalPullCount ?: 0;
        return [createdDate, totalPullCount];
    });
}

// ============================================
// Data Transformation Functions
// ============================================

isolated function transformToJsonData(Package[]|map<string[]> data) returns json {
    if data is Package[] {
        // Transform packages to add formatted date while preserving all fields including keywords
        PackageWithoutKeywords[] packagesForExport = from Package package in data
            select {
                name: package.name,
                URL: package.URL,
                version: package.version,
                totalPullCount: package.totalPullCount,
                pullCount: package.pullCount,
                keywords: package.keywords,
                createdDate: package.createdDate,
                createdDateFormatted: formatTimestampToDate(package.createdDate)
            };
        return packagesForExport.toJson();
    }
    // For keyword maps, return as-is
    return data.toJson();
}

isolated function transformToCsvData(Package[]|map<string[]> data) returns string[][] {
    if data is map<string[]> {
        // Use same format as Google Sheets for consistency
        return transformKeywordsToCsvData(data);
    } else {
        return transformPackagesToCsvData(data);
    }
}

isolated function transformPackagesToCsvData(Package[] packages) returns string[][] {
    string[][] csvData = [];
    // Add header row with proper titles
    csvData.push(["Name", "URL", "Version", "Total Pull Count", "Pull Count", "Created Date"]);

    // Add data rows
    foreach Package package in packages {
        int? totalPullCount = package.totalPullCount;
        string totalPullCountStr = totalPullCount is int ? totalPullCount.toString() : "N/A";
        string createdDateStr = formatTimestampToDate(package.createdDate);
        csvData.push([
            package.name,
            package.URL,
            package.version,
            totalPullCountStr,
            package.pullCount.toString(),
            createdDateStr
        ]);
    }
    return csvData;
}

isolated function transformPackagesToSheetData(Package[] packages) returns string[][] {
    string[][] sheetData = [];
    // Add header row with proper titles
    sheetData.push(["Name", "Version", "Total Pull Count", "Pull Count", "Created Date"]);

    // Add data rows with hyperlink formula
    foreach Package package in packages {
        int? totalPullCount = package.totalPullCount;
        string totalPullCountStr = totalPullCount is int ? totalPullCount.toString() : "N/A";
        string createdDateStr = formatTimestampToDate(package.createdDate);

        // Create HYPERLINK formula for package name
        string hyperlinkFormula = string `=HYPERLINK("${package.URL}", "${package.name}")`;

        sheetData.push([
            hyperlinkFormula,
            package.version,
            totalPullCountStr,
            package.pullCount.toString(),
            createdDateStr
        ]);
    }
    return sheetData;
}

isolated function transformKeywordsToSheetData(map<string[]> data) returns string[][] {
    string[][] sheetData = [];

    // Add header row
    sheetData.push(["Keyword", "Package Count", "Packages"]);

    // Create rows with keyword, count, and packages spread across cells
    // Sort by package count (descending) for better readability
    string[][] keywordRows = [];
    foreach string keyword in data.keys() {
        string[] packages = data.get(keyword);
        string[] row = [keyword, packages.length().toString()];
        // Add each package in its own cell
        foreach string package in packages {
            row.push(package);
        }
        keywordRows.push(row);
    }

    // Sort by package count (second column) in descending order
    keywordRows = keywordRows.sort(array:DESCENDING, isolated function(string[] row) returns int {
        int|error count = int:fromString(row[1]);
        return count is int ? count : 0;
    });

    // Add sorted rows to sheet data
    foreach string[] row in keywordRows {
        sheetData.push(row);
    }

    return sheetData;
}

isolated function transformPackagesToConnectorSummary(Package[] packages) returns string[][] {
    string[][] summaryData = [];

    // Add header row
    summaryData.push(["Connector Name", "Latest Version", "Total Pull Count", "Last Updated", "Area/Category", "Vendor", "API Version"]);

    // Add data rows
    foreach Package package in packages {
        string connectorName = package.name;
        string latestVersion = package.version;
        string lastUpdated = formatTimestampToDate(package.createdDate);

        // Get total pull count
        int? totalPullCount = package.totalPullCount;
        string totalPullCountStr = totalPullCount is int ? totalPullCount.toString() : "N/A";

        // Extract Area/Category from keywords using predefined mapping
        string areaCategory = extractAreaCategory(package.keywords);

        // Extract Vendor from keywords first, then package name pattern
        string vendor = extractVendor(connectorName, package.keywords);

        // API Version is not available in current data
        string apiVersion = "N/A";

        // Create HYPERLINK formula for the connector name
        string connectorNameFormula = string `=HYPERLINK("${package.URL}", "${connectorName}")`;

        summaryData.push([
            connectorNameFormula,
            latestVersion,
            totalPullCountStr,
            lastUpdated,
            areaCategory,
            vendor,
            apiVersion
        ]);
    }

    return summaryData;
}

isolated function transformKeywordsToCsvData(map<string[]> data) returns string[][] {
    // Use the same non-rotated format as Google Sheets for consistency
    string[][] csvData = [];

    // Add header row
    csvData.push(["Keyword", "Package Count", "Packages"]);

    // Create rows with keyword, count, and packages spread across cells
    string[][] keywordRows = [];
    foreach string keyword in data.keys() {
        string[] packages = data.get(keyword);
        string[] row = [keyword, packages.length().toString()];
        // Add each package in its own cell
        foreach string package in packages {
            row.push(package);
        }
        keywordRows.push(row);
    }

    // Sort by package count (second column) in descending order
    keywordRows = keywordRows.sort(array:DESCENDING, isolated function(string[] row) returns int {
        int|error count = int:fromString(row[1]);
        return count is int ? count : 0;
    });

    // Add sorted rows to CSV data
    foreach string[] row in keywordRows {
        csvData.push(row);
    }

    return csvData;
}

// ============================================
// Extraction Functions
// ============================================

isolated function extractVendor(string packageName, string[] keywords) returns string {
    // First, check for Vendor/<name> or vendor/<name> keyword
    foreach string keyword in keywords {
        if keyword.startsWith("Vendor/") || keyword.startsWith("vendor/") {
            int? slashIndex = keyword.indexOf("/");
            if slashIndex is int {
                return keyword.substring(slashIndex + 1);
            }
        }
    }

    // Then check package name pattern: ballerinax/<vendor>.<name> or <vendor>.<api_category>.<api_name>
    // If package has a dot, the part before the dot is usually the vendor
    // e.g., "twilio.sms" -> "twilio", "googleapis.sheets" -> "googleapis"
    int? dotIndex = packageName.indexOf(".");
    if dotIndex is int && dotIndex > 0 {
        return packageName.substring(0, dotIndex);
    }

    // Default to the connector name itself
    return packageName;
}

isolated function extractAreaCategory(string[] keywords) returns string {
    // Define valid categories
    string[] validCategories = [
        "Observability",
        "eCommerce",
        "Communication",
        "File Management",
        "Databases",
        "Security & Identity",
        "Social Media",
        "Social Media Marketing",
        "Project Management",
        "CRM",
        "Customer Support",
        "HRMS",
        "Finance",
        "ERP",
        "Analytics",
        "Documents"
    ];

    // First, check for Area/<area> or Category/<category> keywords
    foreach string keyword in keywords {
        if keyword.startsWith("Area/") || keyword.startsWith("Category/") {
            int? slashIndex = keyword.indexOf("/");
            if slashIndex is int {
                string extractedCategory = keyword.substring(slashIndex + 1);

                // Check if extracted category matches any valid category (case-insensitive)
                foreach string validCategory in validCategories {
                    if extractedCategory.toLowerAscii() == validCategory.toLowerAscii() {
                        return validCategory;
                    }
                }
            }
        }
    }

    // Second, check all keywords directly against valid categories
    foreach string keyword in keywords {
        foreach string validCategory in validCategories {
            if keyword.toLowerAscii() == validCategory.toLowerAscii() {
                return validCategory;
            }
        }
    }

    // Default to "Other" if no match found
    return "Other";
}

// ============================================
// Categorization Functions
// ============================================

isolated function categorizeKeywords(map<string[]> keywords) returns map<string[]> {
    map<string[]> parentKeywords = {};
    foreach string keyword in keywords.keys() {
        if keyword.includes("/") {
            int? slashIndex = keyword.indexOf("/");
            if slashIndex is int {
                string parentKeyword = keyword.substring(0, slashIndex);
                string childKeyword = keyword.substring(slashIndex + 1);
                if parentKeywords.hasKey(parentKeyword) {
                    parentKeywords.get(parentKeyword).push(childKeyword);
                } else {
                    parentKeywords[parentKeyword] = [childKeyword];
                }
            }
        }
    }
    return parentKeywords;
}
