# Ballerina Package Analytics

Analyze packages from Ballerina Central organizations using GraphQL API. Export package data, keywords, and statistics to JSON, CSV, and Google Sheets.

## Features

- **Retrieve Packages**: Fetch all packages from any Ballerina Central organization
- **Keyword Analysis**: Extract and categorize package keywords with filtering options
- **Package Summary**: Generate comprehensive summaries including pull counts and metadata
- **Multi-Format Export**:
  - **Local Files**: JSON and CSV exports with formatted dates
  - **Google Sheets**: Interactive sheets with hyperlinked package names and multiple analysis tabs

## Setup

### Basic Setup

```bash
# Build and run
bal build
bal run
```

### Google Sheets Integration

To enable Google Sheets export, you need OAuth 2.0 credentials:

1. **Create Google Cloud Project**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project
   - Enable the Google Sheets API

2. **Create OAuth 2.0 Credentials**
   - Navigate to **APIs & Services → Credentials**
   - Create **OAuth 2.0 Client ID** (Desktop application)
   - Download the credentials

3. **Get Refresh Token**
   - Visit [OAuth 2.0 Playground](https://developers.google.com/oauthplayground)
   - Configure it to use your own OAuth credentials (gear icon)
   - Select **Google Sheets API v4** scopes
   - Authorize and exchange authorization code for tokens
   - Copy the **refresh token**

4. **Configure in Config.toml**
   ```toml
   needGoogleSheetExport = true

   [googleSheetAuthConfig]
   clientId = "your-client-id.apps.googleusercontent.com"
   clientSecret = "your-client-secret"
   refreshToken = "your-refresh-token"
   refreshUrl = "https://oauth2.googleapis.com/token"

   # Optional: Use existing spreadsheet (creates new if omitted)
   # spreadsheetId = "your-spreadsheet-id"
   ```

## Configuration

### Required Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `orgName` | Organization to analyze | `"ballerina"`, `"ballerinax"` |

### Optional Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| **Data Source** |||
| `needPackageListFromCentral` | `true` | Fetch fresh data from Central API. Set to `false` to reuse existing local data |
| `needTotalPullCount` | `false` | Retrieve pull count statistics (slower, batched API calls) |
| **Analysis** |||
| `needKeywordAnalysis` | `true` | Perform keyword extraction and categorization |
| `minPackagesPerKeyword` | `1` | Minimum packages required for a keyword to appear in filtered results |
| **Export** |||
| `needCsvExport` | `true` | Export data to CSV files |
| `needGoogleSheetExport` | `false` | Export data to Google Sheets (requires auth config) |
| **Filtering** |||
| `limit` | `1000` | Maximum packages to retrieve per request |
| `offset` | `0` | Starting offset for pagination |
| `skipPackagePrefixes` | `[]` | Skip packages with these prefixes (e.g., `["health.", "test."]`) |
| **Pull Count Statistics** |||
| `pullStatStartDate` | `()` | Start date for pull statistics (ISO: `"2024-01-01"`) |
| `pullStatEndDate` | `()` | End date for pull statistics (ISO: `"2024-12-31"`) |
| **Google Sheets** |||
| `googleSheetAuthConfig` | `()` | OAuth credentials (required if `needGoogleSheetExport = true`) |
| `spreadsheetId` | `()` | Existing spreadsheet ID (creates new if omitted) |

### Example Config.toml

```toml
orgName = "ballerina"
limit = 1000
offset = 0

needPackageListFromCentral = true
needTotalPullCount = false
needKeywordAnalysis = true
needCsvExport = true
needGoogleSheetExport = false

minPackagesPerKeyword = 2
skipPackagePrefixes = ["health."]

# Optional: Pull count date filtering
# pullStatStartDate = "2024-01-01"
# pullStatEndDate = "2024-12-31"
```

## Output Data

### Local Files

Files are saved in `results/{YYYY-MM-DD}/`:

| File | Description | Format |
|------|-------------|--------|
| **`{org}-package-list.*`** | All packages with metadata | JSON/CSV |
| **`{org}-keywords.*`** | All keywords → packages mapping | JSON/CSV |
| **`{org}-filtered-keywords.*`** | Keywords appearing in ≥ N packages | JSON/CSV |
| **`{org}-categorized-keywords.*`** | Hierarchical keywords (parent/child) | JSON/CSV |

#### Package List Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Package name (e.g., `"http"`) |
| `URL` | string | Full Central URL |
| `version` | string | Latest version (e.g., `"2.9.0"`) |
| `totalPullCount` | int? | Total downloads (if `needTotalPullCount = true`) |
| `pullCount` | int | Pull count in specified date range |
| `createdDate` | int | Unix timestamp (milliseconds) |
| `createdDateFormatted` | string | Human-readable date (`"2020-4-1"`) |
| `keywords` | string[] | Package keywords |

#### Keywords Files Structure

CSV/JSON format with sorted data (by package count, descending):

| Column | Description |
|--------|-------------|
| `Keyword` | Keyword name |
| `Package Count` | Number of packages using this keyword |
| `Packages` | Package names (spread across columns in CSV/Sheets) |

**Example:**
```csv
Keyword,Package Count,Packages
http,25,http,graphql,websocket,...
database,12,mysql,postgresql,mongodb,...
```

### Google Sheets Tabs

When `needGoogleSheetExport = true`, creates these tabs:

| Tab Name | Description | Columns |
|----------|-------------|---------|
| **Packages** | Package list with hyperlinks | Name (clickable), Version, Total Pull Count, Pull Count, Created Date |
| **Connector Summary** | Categorized package view | Connector Name (clickable), Latest Version, Total Pull Count, Last Updated, Area/Category, Vendor, API Version |
| **Filtered Keywords** | Keywords meeting threshold | Keyword, Package Count, Packages (spread across cells) |
| **Categorized Keywords** | Hierarchical keywords (e.g., `Area/Finance`) | Parent Category, Child Categories (spread across cells) |

**Note:** The unfiltered `keywords` data is only exported to local files (JSON/CSV), not to Google Sheets.

#### Connector Summary Fields

| Field | Description | Extraction Logic |
|-------|-------------|------------------|
| `Connector Name` | Hyperlinked package name | Package name with URL |
| `Latest Version` | Current version | From package metadata |
| `Total Pull Count` | Total downloads | From API (if enabled) |
| `Last Updated` | Last update date | Formatted `createdDate` |
| `Area/Category` | Domain category | Extracted from keywords (`Area/`, `Category/`) or predefined list |
| `Vendor` | Vendor/provider | Extracted from `Vendor/` keyword or package name pattern (e.g., `googleapis.sheets` → `googleapis`) |
| `API Version` | API version | Currently `"N/A"` (not available in API) |

**Category Extraction:**
- Looks for keywords like `Area/Finance`, `Category/Observability`
- Falls back to direct keyword matching against predefined categories
- Defaults to `"Other"` if no match found

**Predefined Categories:**
AI, Observability, eCommerce, Communication, File Management, Databases, Security & Identity, Social Media, Social Media Marketing, Project Management, CRM, Customer Support, HRMS, Finance, ERP, Analytics, Documents

## Example Usage

### Analyze ballerina organization with pull counts

```toml
orgName = "ballerina"
needTotalPullCount = true
pullStatStartDate = "2024-01-01"
pullStatEndDate = "2024-12-31"
```

### Export to Google Sheets only (no CSV)

```toml
orgName = "ballerinax"
needCsvExport = false
needGoogleSheetExport = true

[googleSheetAuthConfig]
clientId = "..."
clientSecret = "..."
refreshToken = "..."
```

### Filter keywords and skip test packages

```toml
orgName = "ballerina"
minPackagesPerKeyword = 5
skipPackagePrefixes = ["test.", "experimental."]
```

### Reanalyze existing data without API calls

```toml
orgName = "ballerina"
needPackageListFromCentral = false
needKeywordAnalysis = true
```

## License

This project is licensed under the Apache License 2.0.
