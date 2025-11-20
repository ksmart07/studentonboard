# Quick Reference Guide

## Installation (5 minutes)

```powershell
# 1. Install modules
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser

# 2. Verify
.\Student-Onboarding-Offboarding.ps1 -Operation CheckPrerequisites

# 3. Edit config.json with your school details
```

## Common Commands

### Test Everything First
```powershell
# Always test with -TestMode flag first
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile "file.csv" -TestMode
```

### Onboard New Students
```powershell
# Reception intake
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Sample-NewStudents-Reception.csv"

# Year 7 intake
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Sample-NewStudents-Year7.csv"

# Year 12 intake (new and transfers)
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Sample-NewStudents-Year12.csv"
```

### Annual Rollover (End of Academic Year)
```powershell
# Transition ALL students to next year group
.\Student-Onboarding-Offboarding.ps1 -Operation Transition
```

### Offboard Graduates
```powershell
# Disable Year 6, 11, 13 graduates (60-day retention)
.\Student-Onboarding-Offboarding.ps1 -Operation Offboard
```

### Generate Reports
```powershell
# Create HTML and CSV reports
.\Student-Onboarding-Offboarding.ps1 -Operation Report
```

## CSV Format Quick Reference

Required columns:
- `FirstName`
- `LastName`
- `YearGroup`

Optional columns:
- `DateOfBirth`
- `Class`
- `Subjects` (semicolon-separated: "Maths;English;Science")
- `ParentEmail`
- `ParentPhone`
- `AdditionalInfo`

Example:
```csv
FirstName,LastName,DateOfBirth,YearGroup,Class,Subjects
Emma,Johnson,2018-09-15,Reception,RClassA,
Liam,O'Connor,2011-09-10,Year7,7A,"Maths;English;Science"
```

## Year Group Progression Map

```
Reception → Year 1 → Year 2 → Year 3 → Year 4 → Year 5 → Year 6 → [Graduate]
Year 7 → Year 8 → Year 9 → Year 10 → Year 11 → [Graduate or Year 12]
Year 12 → Year 13 → [Graduate]
```

## Where to Find Things

- **Logs**: `./Logs/StudentLifecycle-*.log`
- **Reports**: `./Reports/StudentLifecycle-Report-*.html`
- **CSV Exports**: `./Reports/StudentAccounts-*.csv`
- **Sample CSVs**: `Sample-NewStudents-*.csv`
- **Configuration**: `config.json`

## Typical Workflow

### Start of Academic Year (September)
1. Update `config.json`
2. Prepare CSV files for new students
3. Test in test mode: `-TestMode`
4. Onboard Reception students
5. Onboard Year 7 students  
6. Onboard Year 12 students (internal + external)
7. Run Transition operation for existing students
8. Generate and review reports

### Mid-Year Transfer
1. Add student to CSV file
2. Run onboard with specific year group
3. Verify in reports

### End of Academic Year (June/July)
1. Run Transition operation
2. Run Offboard for graduates
3. Generate final reports
4. Archive logs

### After 60 Days (August)
1. Graduated accounts automatically disabled
2. Licenses removed
3. Mailbox retained for compliance
4. Generate final archive report

## Troubleshooting Quick Fixes

| Problem | Solution |
|---------|----------|
| "Module not found" | `Install-Module Microsoft.Graph` |
| "Cannot connect" | Check admin permissions |
| "CSV column missing" | Add FirstName, LastName, YearGroup |
| "License failed" | Check license availability in tenant |
| "Group not found" | Script creates groups automatically |

## Safety Features

- ✅ **Test Mode**: `-TestMode` flag simulates without changes
- ✅ **Confirmation**: Prompts before bulk operations
- ✅ **Logging**: Every action logged with timestamp
- ✅ **Error Handling**: Continues on single failures
- ✅ **Rollback Info**: Detailed logs for troubleshooting

## Key Security Features

1. **Email Delegation**: All student emails → security admin
2. **MFA Required**: Students must set up on first login
3. **Password Policy**: Random initial password, forced change
4. **Audit Trail**: Complete logging for compliance
5. **Retention**: 60-day grace period for graduates

## Parameters Cheat Sheet

```powershell
-Operation         # Required: CheckPrerequisites, Onboard, Offboard, Transition, Report
-CSVFile          # Path to CSV file (required for Onboard)
-YearGroup        # Filter by year group (optional)
-ConfigFile       # Path to config.json (default: .\config.json)
-TestMode         # Simulate without making changes (recommended for testing)
```

## Example Daily Tasks

**New Student Arrives Mid-Year**:
```powershell
# Add to CSV, then:
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\NewStudent.csv"
```

**Check Current Status**:
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Report
```

**Test New Configuration**:
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Test.csv" -TestMode
```

## Support Checklist

If something goes wrong:
1. ☑️ Check log file in `./Logs/` directory
2. ☑️ Check error log file (`*-Errors.log`)
3. ☑️ Verify CSV format is correct
4. ☑️ Run in test mode to identify issue
5. ☑️ Check Azure AD portal for manual verification
6. ☑️ Review error messages for specific guidance

## Configuration Quick Edit

Edit `config.json`:
```json
{
  "SchoolSettings": {
    "Domain": "yourschool.edu",              // ← Your email domain
    "SecurityAdminEmail": "security@...",     // ← Safeguarding email
    "ITDepartmentPhone": "+44-1234-567890"   // ← Default MFA phone
  }
}
```

## Best Practices

1. ✅ Always run with `-TestMode` first
2. ✅ Start with small batches (5-10 students)
3. ✅ Verify in Azure portal after each operation
4. ✅ Keep CSV files backed up
5. ✅ Archive logs monthly
6. ✅ Generate reports after major operations
7. ✅ Document any manual changes made
8. ✅ Test annually before start of term

## One-Line Commands for Common Tasks

```powershell
# Quick check if everything is working
.\Student-Onboarding-Offboarding.ps1 -Operation Report

# Test onboarding without making changes
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\test.csv" -TestMode

# Onboard specific year only
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\all.csv" -YearGroup "Year7"
```

---

**Remember**: Test mode is your friend! Always use `-TestMode` when trying new operations.
