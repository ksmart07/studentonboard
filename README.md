# Student Lifecycle Management System

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A comprehensive PowerShell solution for managing student onboarding, offboarding, and year group transitions in educational institutions using Microsoft Entra ID (Azure AD), Microsoft 365, and Exchange Online.

## 🎓 Overview

This system is designed for school administrators to manage the complete student lifecycle:

- **Onboarding**: Reception, Year 7, and Year 12 new students
- **Transitions**: Automatic year group progression (Reception→Year 1, etc.)
- **Offboarding**: Graduating students (Year 6, 11, 13) with 60-day retention
- **Security**: Email delegation for safeguarding and monitoring
- **Compliance**: MFA setup, comprehensive logging, and audit reports

## ✨ Features

- ✅ Automated user creation in Microsoft Entra ID
- ✅ Name sanitization (handles apostrophes, special characters, long names)
- ✅ Security group assignments (classes, subjects, disciplines)
- ✅ Microsoft 365 license management
- ✅ Email delegation to security admin for safeguarding
- ✅ MFA and authentication method setup
- ✅ Year group transitions for entire school
- ✅ 60-day retention for graduated students
- ✅ Comprehensive logging and HTML/CSV reporting
- ✅ Test mode for safe operation testing

## 🚀 Quick Start

### 1. Install Prerequisites

```powershell
# Install required modules
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser

# Verify installation
.\Student-Onboarding-Offboarding.ps1 -Operation CheckPrerequisites
```

### 2. Configure Your School

Edit `config.json` with your school's settings:

```json
{
  "SchoolSettings": {
    "SchoolName": "Your School Name",
    "Domain": "yourschool.edu",
    "SecurityAdminEmail": "security.admin@yourschool.edu"
  }
}
```

### 3. Prepare Student Data

Create a CSV file with your students:

```csv
FirstName,LastName,DateOfBirth,YearGroup,Class,Subjects
Emma,Johnson,2018-09-15,Reception,RClassA,
Liam,O'Connor,2018-11-20,Reception,RClassB,
```

See `Sample-NewStudents-Reception.csv` for complete example.

### 4. Run Operations

```powershell
# Test first (no changes made)
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Students.csv" -TestMode

# Run for production
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Students.csv"

# Transition year groups (annual rollover)
.\Student-Onboarding-Offboarding.ps1 -Operation Transition

# Generate reports
.\Student-Onboarding-Offboarding.ps1 -Operation Report
```

## 📖 Documentation

- **[USER-GUIDE.md](USER-GUIDE.md)**: Complete documentation with all features and operations
- **Sample CSV files**: Templates for different scenarios included

## 🔐 Security & Safeguarding

### Email Delegation
All student emails are automatically delegated to the security admin account for:
- Real-time monitoring of student communications
- Compliance with safeguarding regulations
- Quick incident response

### Multi-Factor Authentication
- Students required to set up MFA on first login
- Forced password change on first login
- Default IT department contact configured

## 📊 Operations

| Operation | Purpose | Command |
|-----------|---------|---------|
| **CheckPrerequisites** | Verify modules installed | `-Operation CheckPrerequisites` |
| **Onboard** | Create new student accounts | `-Operation Onboard -CSVFile "file.csv"` |
| **Transition** | Move students to next year | `-Operation Transition` |
| **Offboard** | Disable graduating students | `-Operation Offboard` |
| **Report** | Generate HTML/CSV reports | `-Operation Report` |

## 📝 Logging & Auditing

All operations generate detailed logs:
- `./Logs/StudentLifecycle-[Operation]-[timestamp].log` - Complete operation log
- `./Logs/StudentLifecycle-[Operation]-[timestamp]-Errors.log` - Error-only log
- `./Reports/StudentLifecycle-Report-[timestamp].html` - Visual HTML report
- `./Reports/StudentAccounts-[timestamp].csv` - CSV export for analysis

## 🎯 Use Cases

### New Academic Year - Reception Intake
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard `
    -CSVFile ".\Reception-2024.csv" `
    -YearGroup "Reception"
```

### Annual Year Group Transition
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Transition
```

### 6th Form External Transfers
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard `
    -CSVFile ".\Year12-External.csv" `
    -YearGroup "Year12"
```

### End of Year Graduation
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Offboard
```

## 📋 Requirements

- **PowerShell**: 5.1 or higher
- **Modules**: Microsoft.Graph, ExchangeOnlineManagement
- **Permissions**: Global Admin or User Admin in Entra ID
- **Licenses**: Microsoft 365 A3 for students (or equivalent)

## 🛠️ Troubleshooting

### Test Mode
Always test operations first:
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile "file.csv" -TestMode
```

### Common Issues
- **Module not found**: Run `Install-Module Microsoft.Graph`
- **Connection failed**: Verify admin permissions
- **License assignment failed**: Check license availability in tenant

See [USER-GUIDE.md](USER-GUIDE.md) for detailed troubleshooting.

## 📅 Annual Cycle

**September**: Onboard new students, transition year groups  
**Throughout Year**: Handle mid-year transfers  
**June/July**: Identify and begin offboarding graduates  
**August**: Complete offboarding after retention period  

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💼 For School Administrators

This solution provides:
- **Efficiency**: Automate manual onboarding/offboarding tasks
- **Compliance**: Meet safeguarding and data protection requirements
- **Audit Trail**: Comprehensive logging for inspections
- **Safety**: Test mode and confirmation prompts prevent mistakes
- **Reporting**: Professional reports for stakeholders

## 🔗 Links

- [Microsoft Graph PowerShell](https://learn.microsoft.com/en-us/powershell/microsoftgraph/)
- [Exchange Online PowerShell](https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell)
- [Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/)

---

**Note**: This script is designed for educational environments and handles sensitive student data. Always test in a non-production environment first and ensure compliance with your institution's data protection policies.
