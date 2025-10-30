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
