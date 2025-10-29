import ballerinax/googleapis.sheets;

type RetrievePackageListInput record {|
    string orgName;
    int 'limit;
    int 'offset;
|};

type Package record {
    string name;
    string URL;
    string version;
    int? totalPullCount = ();
    int pullCount;
    string[] keywords = [];
    int createdDate;
};

# Data type returned by the Ballerina Central API when retrieving the package list
type PackageListResponse record {|
    # The data received from the Ballerina Central API
    record {|
        record {|
            Package[] packages;
        |} packages;
    |} data;
|};

type TotalPullCountInput record {|
    string orgName;
    string packageName;
    string version;
    string? pullStatStartDate = ();
    string? pullStatEndDate = ();
|};

type TotalPullCountResponse record {|
    record {|
        record {|
            int? totalPullCount;
        |}? package;
    |}? data;
|};

type GoogleSheetConfig record {|
    string clientId;
    string clientSecret;
    string refreshUrl = sheets:REFRESH_URL;
    string refreshToken;
|};

type DataOutput record {|
    Package[] packages;
    map<string[]>? keywords = ();
    map<string[]>? filteredKeywords = ();
    map<string[]>? categorizedKeywords = ();
|};

type PackageWithoutKeywords record {|
    string name;
    string URL;
    string version;
    int? totalPullCount = ();
    int pullCount;
    int createdDate;
    string createdDateFormatted;
|};
