# Student Lifecycle Management System

A comprehensive PowerShell-based solution for managing student onboarding, offboarding, and year group transitions in educational institutions using Microsoft Entra ID (Azure AD), Microsoft 365, and Exchange Online.

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [CSV File Format](#csv-file-format)
- [Operations](#operations)
- [Security and Safeguarding](#security-and-safeguarding)
- [Logging and Auditing](#logging-and-auditing)
- [Troubleshooting](#troubleshooting)

## Overview

This solution is designed for school administrators to manage the complete student lifecycle throughout the academic year:

- **Primary School (Reception - Year 6)**: Students move through year groups annually, with Year 6 graduates moving to secondary education
- **Secondary School (Year 7 - Year 11)**: Students progress through years, with Year 11 either moving to 6th form or graduating
- **6th Form (Year 12 - Year 13)**: Accepting both internal Year 11 progressions and external transfers, with Year 13 as final graduation

The script handles:
- Creating user accounts in Microsoft Entra ID
- Assigning security groups for classes, subjects, and disciplines
- License assignment for Microsoft 365
- Email delegation to security admins for safeguarding
- MFA setup and authentication methods
- 60-day retention for graduated students
- Comprehensive logging and reporting

## Features

### Core Functionality
- ✅ **Automated User Creation**: Creates Entra ID accounts with sanitized names
- ✅ **Name Sanitization**: Handles apostrophes, special characters, and long names
- ✅ **Security Group Management**: Automatically assigns students to appropriate groups
- ✅ **License Assignment**: Applies Microsoft 365 student licenses
- ✅ **Email Delegation**: Delegates all student emails to security admin for safeguarding
- ✅ **MFA Configuration**: Sets up multi-factor authentication requirements
- ✅ **Year Group Transitions**: Bulk move students to next year group
- ✅ **Graduate Retention**: 60-day retention period for graduating students
- ✅ **Comprehensive Logging**: Detailed logs for every operation
- ✅ **HTML/CSV Reports**: Professional reports for auditing and compliance

### Safety Features
- ✅ **Test Mode**: Simulate operations without making actual changes
- ✅ **Confirmation Prompts**: Requires confirmation before bulk operations
- ✅ **Error Handling**: Comprehensive error catching and logging
- ✅ **Step-by-Step Validation**: Pauses between major operations
- ✅ **Rollback Information**: Detailed logs for troubleshooting

## Prerequisites

### Software Requirements
- **PowerShell 5.1 or higher**
- **Microsoft.Graph PowerShell Module**
- **ExchangeOnlineManagement PowerShell Module**

### Permissions Required
- **Global Administrator** or **User Administrator** in Entra ID
- **Exchange Administrator** for mailbox delegation
- **License Administrator** for license assignment

### Microsoft 365 Licenses
- Student licenses (e.g., Microsoft 365 A3 for students)

## Installation

### 1. Clone or Download the Repository

```powershell
git clone https://github.com/ksmart07/studentonboard.git
cd studentonboard
```

### 2. Install Required PowerShell Modules

```powershell
# Install Microsoft Graph module
Install-Module Microsoft.Graph -Scope CurrentUser -Force

# Install Exchange Online Management module
Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force
```

### 3. Verify Installation

```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation CheckPrerequisites
```

## Configuration

### Edit config.json

Update the `config.json` file with your school's specific settings:

```json
{
  "SchoolSettings": {
    "SchoolName": "Your School Name",
    "Domain": "yourschool.edu",
    "SecurityAdminEmail": "security.admin@yourschool.edu",
    "ITDepartmentPhone": "+44-1234-567890"
  }
}
```

### Key Configuration Settings

| Setting | Description | Example |
|---------|-------------|---------|
| `Domain` | Your school's email domain | `school.edu` |
| `SecurityAdminEmail` | Email for safeguarding delegation | `security.admin@school.edu` |
| `ITDepartmentPhone` | Default MFA contact number | `+44-1234-567890` |
| `GraduateRetentionDays` | Days to retain graduated students | `60` |

## Usage

### Basic Command Structure

```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation <Operation> [parameters]
```

### Common Operations

#### 1. Check Prerequisites
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation CheckPrerequisites
```

#### 2. Onboard New Students (Test Mode)
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Sample-NewStudents-Reception.csv" -TestMode
```

#### 3. Onboard New Students (Production)
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Sample-NewStudents-Reception.csv"
```

#### 4. Onboard Specific Year Group
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Students.csv" -YearGroup "Year7"
```

#### 5. Transition All Year Groups (Annual Rollover)
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Transition
```

#### 6. Offboard Graduating Students
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Offboard
```

#### 7. Generate Comprehensive Report
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Report
```

## CSV File Format

### Required Columns
- `FirstName`: Student's first name
- `LastName`: Student's last name
- `YearGroup`: Year group (Reception, Year1, Year2, ..., Year13)

### Optional Columns
- `DateOfBirth`: Student's date of birth (format: YYYY-MM-DD)
- `Class`: Class name (e.g., 7A, 7B)
- `Subjects`: Semicolon-separated list of subjects (e.g., "Maths;English;Science")
- `ParentEmail`: Parent/guardian email
- `ParentPhone`: Parent/guardian phone
- `AdditionalInfo`: Any additional notes

### Sample CSV

```csv
FirstName,LastName,DateOfBirth,YearGroup,Class,Subjects,ParentEmail,ParentPhone,AdditionalInfo
Emma,Johnson,2018-09-15,Reception,RClassA,,"parent1@email.com","+44-1234-111111",New student
Liam,O'Connor,2018-11-20,Reception,RClassB,,"parent2@email.com","+44-1234-111112",Special needs support
```

### Special Character Handling

The script automatically handles:
- **Apostrophes**: O'Connor → OConnor (for username)
- **Hyphens**: Mary-Jane → MaryJane (for username)
- **Long names**: Truncated to 20 characters for usernames
- **Display names**: Preserve original formatting with apostrophes

## Operations

### Onboarding

**Purpose**: Create new student accounts at the start of academic year or for mid-year admissions.

**Process**:
1. Reads student data from CSV file
2. Sanitizes names and creates usernames
3. Creates Entra ID user account
4. Generates random initial password (must be changed on first login)
5. Adds to appropriate security groups (year, class, subjects)
6. Assigns Microsoft 365 student licenses
7. Delegates email to security admin account
8. Sets up MFA requirements
9. Logs all operations
10. Generates summary report

**Use Cases**:
- Reception intake at start of year
- Year 7 intake from primary schools
- Year 12 intake from other schools
- Mid-year transfers

### Transition

**Purpose**: Move all students to their next year group at end of academic year.

**Year Group Progression Map**:
```
Reception → Year 1
Year 1 → Year 2
Year 2 → Year 3
Year 3 → Year 4
Year 4 → Year 5
Year 5 → Year 6
Year 6 → Graduated (Primary)
Year 7 → Year 8
Year 8 → Year 9
Year 9 → Year 10
Year 10 → Year 11
Year 11 → Graduated (Secondary) or Year 12
Year 12 → Year 13
Year 13 → Graduated (6th Form)
```

**Process**:
1. Identifies all students in each year group
2. Updates Department field to next year
3. Updates security group memberships
4. Moves graduating students to archive group
5. Maintains 60-day retention for graduates
6. Logs all transitions

### Offboarding

**Purpose**: Properly offboard graduating students with retention period.

**Process**:
1. Identifies students in archive (graduated) group
2. Disables user accounts
3. Removes Microsoft 365 licenses
4. Maintains mailbox for 60 days
5. Schedules account deletion after retention
6. Logs all actions

**Graduating Years**:
- **Year 6**: Moving to secondary school
- **Year 11**: Moving to 6th form elsewhere or leaving education
- **Year 13**: Final graduation

### Reporting

**Purpose**: Generate comprehensive reports for auditing and compliance.

**Outputs**:
- **HTML Report**: Visual report with tables and summaries
  - Total student count
  - Active vs. disabled accounts
  - Year group distribution
  - License status
- **CSV Export**: Detailed student list for analysis
- **Audit Logs**: All operations with timestamps

**Report Locations**:
- HTML: `./Reports/StudentLifecycle-Report-[timestamp].html`
- CSV: `./Reports/StudentAccounts-[timestamp].csv`

## Security and Safeguarding

### Email Delegation

All student emails are automatically delegated to the designated security admin account for:
- **Safeguarding monitoring**: Real-time oversight of student communications
- **Compliance**: Meeting regulatory requirements
- **Incident response**: Quick access in case of concerns

**Permissions Granted**:
- **FullAccess**: Read all emails
- **SendAs**: Send emails on behalf of student if needed

### Multi-Factor Authentication (MFA)

- Default placeholder phone number (IT Department) is configured
- Students are **required** to set up MFA on first login
- Students must change password on first login
- Conditional access policies enforce MFA

### Data Protection

- **Password Security**: Random initial passwords, forced change on first login
- **Account Lifecycle**: Proper offboarding prevents unauthorized access
- **Audit Trail**: Comprehensive logging for compliance
- **Retention Policy**: 60-day grace period for graduated students

## Logging and Auditing

### Log Files

All operations generate detailed logs in `./Logs/` directory:

| Log File | Purpose |
|----------|---------|
| `StudentLifecycle-[Operation]-[timestamp].log` | Complete operation log |
| `StudentLifecycle-[Operation]-[timestamp]-Errors.log` | Error-only log |

### Log Levels

- **INFO**: General information messages
- **SUCCESS**: Successful operations
- **WARNING**: Non-critical issues
- **ERROR**: Critical failures

### Sample Log Entry

```
2025-11-20 12:30:45 [INFO] Creating user: Emma Johnson (emma.johnson@school.edu) - Year Group: Reception
2025-11-20 12:30:47 [SUCCESS] Successfully created user: emma.johnson@school.edu
2025-11-20 12:30:48 [SUCCESS] Added user to group: YearGroup-Reception
2025-11-20 12:30:49 [SUCCESS] Granted FullAccess permission to security admin
```

### Reports

Reports are saved in `./Reports/` directory:
- Timestamped for version control
- HTML format for easy viewing
- CSV format for data analysis
- Includes summary statistics
- Lists all student accounts with status

## Troubleshooting

### Common Issues

#### 1. Module Not Found

**Error**: `Microsoft.Graph module not found`

**Solution**:
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force
```

#### 2. Connection Failed

**Error**: `Failed to connect to services`

**Solution**:
- Verify you have appropriate admin permissions
- Check your internet connection
- Ensure MFA is set up for your admin account
- Try authenticating manually first

#### 3. License Assignment Failed

**Error**: `Failed to assign licenses`

**Solution**:
- Verify student licenses are available in tenant
- Check license quota hasn't been exceeded
- Ensure user has UsageLocation set (defaults to "GB")

#### 4. Group Not Found

**Warning**: `Group not found: [GroupName] - Creating it...`

**Solution**: This is normal behavior. Script will create groups automatically.

#### 5. CSV Import Failed

**Error**: `Required column missing`

**Solution**: Ensure CSV has required columns: FirstName, LastName, YearGroup

### Test Mode

Always test operations first using `-TestMode` flag:

```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Students.csv" -TestMode
```

This simulates all operations without making actual changes.

### Verification Steps

After onboarding students:

1. **Check Azure AD Portal**:
   - Navigate to Azure Active Directory → Users
   - Verify new accounts are created

2. **Check Microsoft 365 Admin Center**:
   - Navigate to Users → Active users
   - Verify licenses are assigned

3. **Check Exchange Admin Center**:
   - Navigate to Recipients → Mailboxes
   - Verify mailboxes are created
   - Check permissions on mailboxes

4. **Run Report**:
   ```powershell
   .\Student-Onboarding-Offboarding.ps1 -Operation Report
   ```

### Support

For issues or questions:
1. Check the log files in `./Logs/` directory
2. Review error messages in `*-Errors.log` files
3. Run in test mode to identify issues
4. Check Azure AD audit logs for detailed error messages

## Best Practices

### Before Academic Year Start

1. **Update Configuration**: Review and update `config.json`
2. **Test in Sandbox**: Run all operations in test mode
3. **Prepare CSV Files**: Clean and validate all student data
4. **Backup**: Take snapshot of current Entra ID state
5. **Communicate**: Inform stakeholders of timeline

### During Operation

1. **Start with Test Mode**: Always test first
2. **Small Batches**: Process students in smaller groups initially
3. **Monitor Logs**: Watch logs in real-time
4. **Verify Each Step**: Check Azure portal between operations
5. **Keep Backups**: Save CSV files and reports

### After Operation

1. **Run Reports**: Generate comprehensive reports
2. **Verify Users**: Check sample users in portal
3. **Test Login**: Have test student account verify login process
4. **Archive Logs**: Save all logs for compliance
5. **Document Issues**: Note any problems for next year

### Annual Cycle

**September (Start of Year)**:
- Onboard Reception, Year 7, Year 12 new students
- Transition all existing students to next year
- Verify all group memberships

**Throughout Year**:
- Onboard mid-year transfers
- Update security groups as needed
- Run reports monthly

**June/July (End of Year)**:
- Prepare for year group transitions
- Identify graduating students
- Begin offboarding process for Year 6, 11, 13
- Generate final reports

**August**:
- Complete offboarding after 60-day retention
- Archive reports
- Prepare for new academic year

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## Version History

- **1.0**: Initial release
  - Onboarding functionality
  - Offboarding with retention
  - Year group transitions
  - Comprehensive logging
  - HTML/CSV reporting
  - Name sanitization
  - Email delegation
  - MFA setup

## Acknowledgments

Designed for educational institutions managing student lifecycles in Microsoft 365 environments.
