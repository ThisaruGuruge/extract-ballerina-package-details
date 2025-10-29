# Ballerina Package Analytics

A comprehensive Ballerina application for analyzing packages from Ballerina Central. This tool retrieves package data via GraphQL API and provides analytics including keyword analysis, pull count statistics, and multi-format exports (JSON, CSV, Google Sheets).

## Features

- **Package Discovery**: Fetch packages from any organization on Ballerina Central
- **Pull Count Analytics**: Retrieve detailed download statistics with date range filtering
- **Keyword Analysis**: Analyze, filter, and categorize package keywords hierarchically
- **Multi-Format Export**: Export data to JSON, CSV, and Google Sheets
- **Smart Hyperlinks**: Google Sheets exports include clickable package name links
- **Human-Readable Dates**: Automatic timestamp to date conversion (YYYY-MM-DD)
- **Flexible Filtering**: Skip packages by prefix, filter keywords by frequency
- **Batch Processing**: Efficient data writing with built-in rate limiting
- **Color-Coded Logging**: Clear, informative console output with progress tracking
- **Robust Error Handling**: Structured error chains with graceful degradation
- **Incremental Updates**: Load from existing data or fetch fresh from Central

## Prerequisites

- **Ballerina**: Version 2201.12.7 or later ([Download](https://ballerina.io/downloads/))
- **Google Sheets API** (Optional): For Google Sheets export functionality
  - OAuth 2.0 credentials
  - Spreadsheet ID (optional, creates new if not provided)

## Quick Start

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd extract-ballerina-package-details

# Build the project
bal build
```

### Basic Configuration

Create a `Config.toml` file in the project root:

```toml
# Required: Organization to analyze
orgName = "ballerina"

# Analysis options (all optional, defaults shown)
needPackageListFromCentral = true
needTotalPullCount = false
needKeywordAnalysis = true
needCsvExport = true
needGoogleSheetExport = false

# Pagination
limit = 1000
offset = 0

# Keyword filtering
minPackagesPerKeyword = 1

# Package filtering (skip packages with these prefixes)
skipPackagePrefixes = []

# Pull count date range (optional, ISO format: YYYY-MM-DD)
# pullStatStartDate = "2024-01-01"
# pullStatEndDate = "2024-12-31"
```

### Run the Application

```bash
bal run
```

## Configuration

### Core Settings

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `orgName` | `string` | **Required** | Organization name to analyze (e.g., "ballerina", "ballerinax") |
| `needPackageListFromCentral` | `boolean` | `true` | Fetch fresh data from Central API (false = load from existing files) |
| `needTotalPullCount` | `boolean` | `false` | Retrieve pull count statistics for each package |
| `needKeywordAnalysis` | `boolean` | `true` | Perform keyword analysis and categorization |
| `needCsvExport` | `boolean` | `true` | Export data to CSV files |
| `needGoogleSheetExport` | `boolean` | `false` | Export data to Google Sheets |

### Pagination & Filtering

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `limit` | `int` | `1000` | Maximum number of packages to retrieve |
| `offset` | `int` | `0` | Offset for pagination (for large organizations) |
| `skipPackagePrefixes` | `string[]` | `[]` | Skip packages starting with these prefixes (e.g., `["health.", "test."]`) |
| `minPackagesPerKeyword` | `int` | `1` | Minimum packages required to keep a keyword in filtered results |

### Pull Count Statistics

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `pullStatStartDate` | `string?` | `()` | Start date for pull statistics (ISO format: YYYY-MM-DD) |
| `pullStatEndDate` | `string?` | `()` | End date for pull statistics (ISO format: YYYY-MM-DD) |

### Google Sheets Configuration

To export to Google Sheets, add the following to your `Config.toml`:

```toml
needGoogleSheetExport = true

# Optional: Provide existing spreadsheet ID to append to
# spreadsheetId = "your-spreadsheet-id-here"

# Required: Sheet ID (worksheet within the spreadsheet)
sheetId = "0"

# OAuth 2.0 Configuration
[googleSheetAuthConfig]
clientId = "your-client-id.apps.googleusercontent.com"
clientSecret = "your-client-secret"
refreshToken = "your-refresh-token"
refreshUrl = "https://oauth2.googleapis.com/token"
```

**Getting Google Sheets Credentials:**

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a project and enable Google Sheets API
3. Create OAuth 2.0 credentials (Desktop application)
4. Use the [OAuth 2.0 Playground](https://developers.google.com/oauthplayground) to get a refresh token

## Output Structure

The application generates timestamped directories in `results/`:

```text
results/
└── 2024-3-15/
    ├── ballerina-package-list.json
    ├── ballerina-package-list.csv
    ├── ballerina-keywords.json
    ├── ballerina-keywords.csv
    ├── ballerina-filtered-keywords.json
    ├── ballerina-filtered-keywords.csv
    ├── ballerina-categorized-keywords.json
    └── ballerina-categorized-keywords.csv
```

### Output Files

| File | Format | Description |
|------|--------|-------------|
| `{org}-package-list.*` | JSON/CSV | Complete package list with metadata (name, version, pull counts, created date) |
| `{org}-keywords.*` | JSON/CSV | All keywords mapped to their packages |
| `{org}-filtered-keywords.*` | JSON/CSV | Keywords appearing in ≥ N packages (configurable threshold) |
| `{org}-categorized-keywords.*` | JSON/CSV | Hierarchical keyword categorization (keywords with "/") |

### Google Sheets Output

When `needGoogleSheetExport = true`, data is written to separate tabs within a single spreadsheet:

| Tab Name | Content |
|----------|---------|
| **Packages** | Package list with hyperlinked names (click to visit Central) |
| **Keywords** | All keywords and associated packages |
| **Filtered Keywords** | Keywords meeting the minimum package threshold |
| **Categorized Keywords** | Hierarchical keyword organization |

**Special Features:**

- Package names are clickable hyperlinks to Ballerina Central
- Dates displayed in human-readable format (YYYY-MM-DD)
- Automatic sheet management (reuses default "Sheet1" for first tab)

## Example Outputs

### Package List (JSON)

```json
[
  {
    "name": "http",
    "URL": "https://central.ballerina.io/ballerina/http",
    "version": "2.9.0",
    "totalPullCount": 1500000,
    "pullCount": 50000,
    "createdDate": 1585699200,
    "createdDateFormatted": "2020-4-1"
  }
]
```

### Keywords Analysis (JSON)

```json
{
  "http": ["http", "http2", "rest"],
  "network/protocol": ["http", "grpc", "tcp"],
  "database": ["mysql", "postgresql", "mongodb"]
}
```

### Google Sheets View

```text
| name (hyperlinked)      | version | totalPullCount | pullCount | createdDate |
|-------------------------|---------|----------------|-----------|-------------|
| http → central link     | 2.9.0   | 1500000        | 50000     | 2020-4-1    |
| io → central link       | 1.6.0   | 2300000        | 75000     | 2019-5-12   |
```

## Logging System

The application features comprehensive, color-coded logging:

### Log Levels

| Level | Color | Usage |
|-------|-------|-------|
| INFO | Blue | General information, configuration details |
| WARNING | Yellow | Non-critical issues, proceeding with degraded functionality |
| ERROR | Red | Errors with full cause chain |
| SUCCESS | Green | Successful operations |
| PROGRESS | Cyan | Progress updates for long-running tasks |
| STATS | Magenta | Statistical summaries |

### Example Console Output

```text
[INFO] Starting Ballerina Central package analysis
[INFO] Target organization: ballerina
[INFO] Configuration: Package List=true, Pull Count=true, Keywords=true, CSV Export=true
[PROGRESS] Fetching package list from Ballerina Central for organization: ballerina
[STATS] Retrieved 150 packages from Central API
[PROGRESS] Analyzing package keywords and creating categorization
[STATS] Found 250 unique keywords across all packages
[STATS] Filtered to 75 keywords (appearing in ≥2 packages)
[SUCCESS] Keyword analysis completed
[INFO] Created new Google Spreadsheet: https://docs.google.com/spreadsheets/d/xyz
[INFO] Renamed default sheet 'Sheet1' to: Packages
[SUCCESS] Data written to sheet 'Packages' - 151 rows written
[SUCCESS] All data exported to results/ directory
[SUCCESS] Analysis complete!
[STATS] Total packages analyzed: 150
```

## Error Handling

The application includes robust error handling with structured error chains:

### Error Chain Example

```text
[ERROR] Failed to write data batch
[ERROR]   Caused by: Failed to write data to Google Sheet: Keywords
[ERROR]   Caused by: Invalid credentials
```

### Graceful Degradation

- **Pull Count Failures**: Application continues without pull count data
- **Google Sheets Errors**: CSV/JSON exports still succeed
- **API Rate Limiting**: Automatic sleep timer (1.5s between requests)
- **Configuration Errors**: Clear validation messages on startup

## Project Structure

```text
extract-ballerina-package-details/
├── main.bal                # Main application logic and workflow orchestration
├── types.bal               # Type definitions (Package, API responses, configs)
├── queries.bal             # GraphQL queries for Ballerina Central API
├── utils.bal               # Utility functions (I/O, transformations, logging)
├── sheets.bal              # Google Sheets integration
├── configurables.bal       # Configurable variables
├── Config.toml             # Configuration file (user-created)
├── Ballerina.toml          # Project metadata
├── Dependencies.toml       # Dependency lock file
├── CLAUDE.md               # AI assistant instructions
└── results/                # Generated output directory
```

### Key Components

| File | Responsibility |
|------|----------------|
| **main.bal** | Workflow orchestration, package retrieval, error handling |
| **types.bal** | Data structures for packages, API responses, Google Sheets config |
| **queries.bal** | GraphQL queries for package list and pull count retrieval |
| **utils.bal** | File I/O, data transformations, keyword analysis, logging |
| **sheets.bal** | Google Sheets client initialization and data writing |
| **configurables.bal** | All configurable parameters with defaults |

## Advanced Usage

### Analyzing Large Organizations

For organizations with many packages, use pagination:

```toml
orgName = "ballerinax"
limit = 500
offset = 0  # Run multiple times with offset = 500, 1000, etc.
```

### Filtering Healthcare Packages

```toml
skipPackagePrefixes = ["health."]
```

### Focused Keyword Analysis

Only keep keywords appearing in 5+ packages:

```toml
minPackagesPerKeyword = 5
```

### Pull Count for Specific Period

```toml
needTotalPullCount = true
pullStatStartDate = "2024-01-01"
pullStatEndDate = "2024-12-31"
```

### Reusing Existing Package Data

To skip API calls and work with existing data:

```toml
needPackageListFromCentral = false
needKeywordAnalysis = true  # Reanalyze keywords from existing data
```

## API Rate Limiting

**Ballerina Central API Limits:**

- Rate: 50 requests/minute
- Built-in sleep: 1.5 seconds between requests
- Automatic compliance: No manual intervention needed

**Pull Count Retrieval:**

- Progress updates every 10 packages
- Errors handled gracefully (analysis continues)

## Contributing

Contributions are welcome. Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with clear commit messages
4. Test thoroughly
5. Submit a pull request

### Code Style

- Follow Ballerina best practices
- Use `isolated` functions where possible
- Add error handling with structured error chains
- Include color-coded logging for user feedback

## License

This project is licensed under the Apache License 2.0.

## Related Links

- [Ballerina Language](https://ballerina.io/)
- [Ballerina Central](https://central.ballerina.io/)
- [Ballerina GraphQL Library](https://central.ballerina.io/ballerina/graphql)
- [Google Sheets API for Ballerina](https://central.ballerina.io/ballerinax/googleapis.sheets)

## Performance Optimization

- Set `needTotalPullCount = false` if you don't need pull statistics (much faster)
- Use existing data mode for keyword re-analysis without API calls
- Adjust `limit` based on your needs (lower = faster for testing)

## Google Sheets Best Practices

- Provide `spreadsheetId` to append to existing spreadsheets
- New spreadsheets are named: `[Connector Analysis] {orgName}-{date}`
- Package name hyperlinks make navigation easier

## Troubleshooting

- **Empty results?** Check `orgName` spelling
- **API errors?** Verify internet connection and API availability
- **Google Sheets fails?** Verify OAuth credentials and permissions
- **Rate limiting?** The app handles this automatically; don't modify `SLEEP_TIMER`

## GitHub Actions Automation

This repository includes a GitHub Actions workflow to run the analysis automatically.

### Manual Execution

1. Go to **Actions** → **Run Package Analysis** → **Run workflow**
2. Configure parameters:
   - **orgName**: Organization to analyze (e.g., `ballerina`, `ballerinax`)
   - **limit**: Maximum packages to retrieve (default: 1000)
   - **needTotalPullCount**: Fetch pull statistics (default: false)
   - **needGoogleSheetExport**: Export to Google Sheets (default: false)
   - **needCsvExport**: Export CSV files (default: true)

### Scheduled Execution

The workflow runs automatically every Sunday at midnight UTC (configurable in `.github/workflows/run-analysis.yml`).

### GitHub Secrets Setup

To enable Google Sheets export, configure these secrets in **Settings → Secrets and variables → Actions**:

| Secret Name | Description |
|-------------|-------------|
| `GOOGLE_CLIENT_ID` | OAuth 2.0 Client ID from Google Cloud Console |
| `GOOGLE_CLIENT_SECRET` | OAuth 2.0 Client Secret |
| `GOOGLE_REFRESH_TOKEN` | Refresh token from OAuth 2.0 Playground |
| `GOOGLE_SPREADSHEET_ID` | (Optional) Existing spreadsheet ID to append to |

### Viewing Results

Analysis results are uploaded as artifacts:
- Navigate to **Actions** → Select workflow run → **Artifacts** section
- Download `analysis-results-{orgName}-{run-number}.zip`
- Results are retained for 30 days

## Support

- **Issues**: [Create an issue](https://github.com/your-repo/issues)
- **Questions**: Check the [Ballerina Documentation](https://ballerina.io/learn/)
- **API Schema**: Review the [Ballerina Central GraphQL API](https://api.central.ballerina.io/2.0/graphql)
