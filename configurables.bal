configurable boolean needPackageListFromCentral = true;
configurable boolean needTotalPullCount = false;
configurable boolean needKeywordAnalysis = true;
configurable boolean needCsvExport = true;

# When filtering the keywords, the keyword will be kept if it has at least this many packages.
configurable int minPackagesPerKeyword = 1;

configurable string orgName = ?;
configurable int 'limit = 1000;
configurable int 'offset = 0;
configurable string[] skipPackagePrefixes = [];
configurable string? pullStatStartDate = ();
configurable string? pullStatEndDate = ();

// Google Sheets Configurations
configurable boolean needGoogleSheetExport = false;
configurable GoogleSheetConfig googleSheetAuthConfig = ?;
configurable string? spreadsheetId = ();
