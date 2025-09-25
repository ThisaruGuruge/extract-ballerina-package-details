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
