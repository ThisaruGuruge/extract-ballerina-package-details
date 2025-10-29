const string GET_PACKAGE_LIST_QUERY = string `
query ($orgName: String!, $limit: Int!, $offset: Int!) {
    packages(
        orgName: $orgName,
        limit: $limit,
        offset: $offset,
    ) {
        packages {
            name
            URL
            version
            createdDate
            totalPullCount
            pullCount
            keywords
        }
    }
}
`;

const string GET_TOTAL_PULL_COUNT_QUERY = string `
query getPackageInfo(
    $orgName: String!
    $packageName: String!
    $version: String!
    $pullStatStartDate: String
    $pullStatEndDate: String
) {
    package(
      orgName: $orgName,
      packageName: $packageName,
      version: $version,
      pullStatStartDate: $pullStatStartDate,
      pullStatEndDate: $pullStatEndDate
    ) {
        totalPullCount
    }
}`;
