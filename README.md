# Package Count - Ballerina Package Analysis Tool

A Ballerina application that analyzes packages from Ballerina Central, providing insights into package statistics, keyword analysis, and pull count data.

## Overview

This tool connects to the Ballerina Central GraphQL API to retrieve package information and perform various analyses:

- **Package Discovery**: Retrieves packages from specified organizations
- **Pull Count Analysis**: Gathers total pull count statistics for packages
- **Keyword Analysis**: Analyzes and categorizes package keywords
- **Data Export**: Exports results in both JSON and CSV formats
- **Rate Limiting**: Implements proper rate limiting to respect API constraints

## Features

- 🔍 **Package Discovery**: Fetch packages from Ballerina Central with configurable limits
- 📊 **Pull Count Statistics**: Retrieve detailed pull count data for packages
- 🏷️ **Keyword Analysis**: Analyze and categorize package keywords
- 📁 **Multi-format Export**: Export data in JSON and CSV formats
- ⚡ **Rate Limiting**: Built-in rate limiting to avoid API throttling
- 🎯 **Configurable**: Easy configuration for different organizations and analysis needs

## Prerequisites

- [Ballerina](https://ballerina.io/) 2201.12.7 or later
- Access to Ballerina Central API

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd package-count
```

2. Build the project:
```bash
bal build
```

## Configuration

The application can be configured using the following configurable variables in `main.bal`:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `orgName` | string | "ballerinax" | Organization name to analyze |
| `limit` | int | 1000 | Maximum number of packages to retrieve |
| `offset` | int | 0 | Offset for pagination |
| `needPackageList` | boolean | true | Whether to retrieve package list |
| `needTotalPullCount` | boolean | false | Whether to get total pull count |
| `needKeywordAnalysis` | boolean | true | Whether to perform keyword analysis |
| `needCsvExport` | boolean | true | Whether to export CSV files |
| `pullStatStartDate` | string? | () | Start date for pull statistics |
| `pullStatEndDate` | string? | () | End date for pull statistics |

## Usage

### Basic Usage

Run the application with default settings:

```bash
bal run
```

### Custom Configuration

You can override configuration values using environment variables or by modifying the configurable variables in the code.

### Output Files

The application generates several output files in the `resources` directory:

- `{orgName}-package-list.json` - Complete package list with metadata
- `{orgName}-package-list.csv` - Package data in CSV format
- `{orgName}-keywords.json` - Keyword analysis results
- `{orgName}-filtered-keywords.json` - Filtered keywords (appearing in multiple packages)
- `{orgName}-categorized-keywords.json` - Hierarchical keyword categorization
- `{orgName}-keywords.csv` - Keyword analysis in CSV format

## API Rate Limiting

The application respects Ballerina Central's API rate limits:
- **Rate Limit**: 50 requests per minute
- **Sleep Timer**: 1.5 seconds between requests
- **Automatic Handling**: Built-in rate limiting to prevent API throttling

## Project Structure

```
package-count/
├── main.bal              # Main application logic
├── types.bal             # Type definitions
├── queries.bal           # GraphQL queries
├── utils.bal             # Utility functions
├── Ballerina.toml        # Project configuration
├── Dependencies.toml     # Dependencies
└── resources/            # Output directory (generated)
```

## Key Components

### Main Application (`main.bal`)
- Orchestrates the entire analysis workflow
- Manages package retrieval and processing
- Handles error scenarios gracefully

### Types (`types.bal`)
- Defines data structures for packages and API responses
- Includes input/output types for GraphQL operations

### Queries (`queries.bal`)
- Contains GraphQL queries for Ballerina Central API
- Supports package listing and pull count retrieval

### Utilities (`utils.bal`)
- File I/O operations (JSON/CSV export)
- Keyword analysis and categorization
- Matrix operations for data transformation

## Example Output

### Package List
```json
[
  {
    "name": "package-name",
    "URL": "https://central.ballerina.io/package-name",
    "version": "1.0.0",
    "totalPullCount": 150,
    "pullCount": 25,
    "keywords": ["http", "client", "api"]
  }
]
```

### Keyword Analysis
```json
{
  "http": ["package1", "package2", "package3"],
  "client": ["package1", "package4"],
  "api": ["package2", "package5"]
}
```

## Error Handling

The application includes comprehensive error handling:
- **API Failures**: Graceful fallback to file-based operations
- **Rate Limiting**: Automatic retry with exponential backoff
- **File Operations**: Safe file writing with error reporting
- **Data Validation**: Input validation and type safety

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License.

## Support

For issues and questions:
- Create an issue in the repository
- Check the Ballerina documentation
- Review the GraphQL schema for Ballerina Central

## Related Links

- [Ballerina Language](https://ballerina.io/)
- [Ballerina Central](https://central.ballerina.io/)
- [Ballerina GraphQL Module](https://lib.ballerina.io/ballerina/graphql)
- [Ballerina File Module](https://lib.ballerina.io/ballerina/file)
