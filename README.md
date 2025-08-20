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
- 🌈 **Enhanced Logging**: Color-coded, informative log output for better visibility

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

### Core Configuration Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `orgName` | string | "ballerinax" | Organization name to analyze |
| `limit` | int | 1000 | Maximum number of packages to retrieve |
| `offset` | int | 0 | Offset for pagination |
| `needPackageListFromCentral` | boolean | true | Whether to retrieve package list from Central API |
| `needTotalPullCount` | boolean | false | Whether to get total pull count for packages |
| `needKeywordAnalysis` | boolean | true | Whether to perform keyword analysis |
| `needCsvExport` | boolean | true | Whether to export CSV files |
| `skipPackagePrefixes` | string[] | [] | Package prefixes to skip during analysis |
| `minPackagesPerKeyword` | int | 1 | Minimum packages required to keep a keyword |
| `pullStatStartDate` | string? | () | Start date for pull statistics (ISO 8601 format) |
| `pullStatEndDate` | string? | () | End date for pull statistics (ISO 8601 format) |

### Important Constants

The application also uses several constants that control its behavior:

| Constant | Value | Description |
|----------|-------|-------------|
| `BALLERINA_CENTRAL_GRAPHQL_URL` | "https://api.central.ballerina.io/2.0/graphql" | GraphQL API endpoint |
| `BALLERINA_CENTRAL_URL` | "https://central.ballerina.io" | Central website URL |
| `SLEEP_TIMER` | 1.5 | Sleep duration between API requests (seconds) |
| `GENERATED_FILES_DIR` | "results" | Output directory for generated files |
| `HEALTHCARE_PACKAGE_PREFIX` | "health." | Default prefix for healthcare packages |

### Example Config.toml

You can also create a `Config.toml` file in your project root to override the default configuration:

```toml
# Organization to analyze
orgName = "ballerina"

# Analysis options
needPackageListFromCentral = true
needTotalPullCount = true
needKeywordAnalysis = true
needCsvExport = true

# Optional: Package filtering (skip packages with these prefixes)
# skipPackagePrefixes = ["health.", "test.", "internal."]

# Optional: Keyword filtering threshold (keep keywords that appear in at least N packages)
# minPackagesPerKeyword = 2

# Optional: Date range for pull statistics (ISO 8601 format)
# pullStatStartDate = "2024-01-01"
# pullStatEndDate = "2024-12-31"

# Optional: Pagination settings for large organizations
# limit = 500
# offset = 0
```

### Configuration Precedence

The application follows this configuration precedence order:
1. **Config.toml** file (highest priority)
2. **Environment variables** (if supported)
3. **Default values** in `main.bal` (lowest priority)

### Configuration Tips

- **Organization Analysis**: Set `orgName` to analyze different organizations
- **Package Filtering**: Use `skipPackagePrefixes` to exclude specific package types
- **Keyword Analysis**: Adjust `minPackagesPerKeyword` to focus on widely-used keywords
- **API Rate Limiting**: The `SLEEP_TIMER` constant ensures compliance with API limits
- **Output Control**: Use boolean flags to enable/disable specific analysis features

## Enhanced Logging

The application features a comprehensive, color-coded logging system that provides clear visibility into all operations:

### Log Levels

- **🔵 [INFO]**: General information and configuration details
- **🟡 [WARNING]**: Warning messages and non-critical issues
- **🟢 [SUCCESS]**: Successful completion of operations
- **🔵 [PROGRESS]**: Progress updates for long-running tasks
- **🟣 [STATS]**: Statistical information and data summaries

### Log Features

- **Color-coded output** for easy visual identification
- **Progress tracking** for API operations and data processing
- **Statistical summaries** showing package counts and processing results
- **File operation confirmations** with clear success indicators
- **Error context** with detailed recovery information

### Example Log Output

```
[INFO] Starting Ballerina Central package analysis
[INFO] Target organization: ballerina
[INFO] Configuration: Package List=true, Pull Count=true, Keywords=true, CSV Export=true
[PROGRESS] Fetching package list from Ballerina Central for organization: ballerina
[STATS] Retrieved 150 packages from Central API
[PROGRESS] Fetching total pull count statistics for all packages
[SUCCESS] Successfully retrieved pull count data for 150 packages
[SUCCESS] Analysis complete! All data exported to results/ directory
```

## Usage

### Basic Usage

Run the application with default settings:

```bash
bal run
```

### Custom Configuration

You can override configuration values using environment variables or by modifying the configurable variables in the code.

### Output Files

The application generates several output files in the `results` directory:

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
- Enhanced color-coded logging system
- Keyword analysis and categorization
- Matrix operations for data transformation
- Package filtering utilities

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
