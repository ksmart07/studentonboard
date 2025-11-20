# Testing Guide

This guide helps you test the Student Lifecycle Management System safely before using it in production.

## Testing Approach

**ALWAYS** test with `-TestMode` flag first. This simulates all operations without making any actual changes to Entra ID, Exchange, or Microsoft 365.

## Test Scenarios

### Scenario 1: Prerequisites Check

**Purpose**: Verify all required modules are installed.

```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation CheckPrerequisites
```

**Expected Output**:
- ✅ Microsoft.Graph modules found
- ✅ ExchangeOnlineManagement module found
- ✅ PowerShell version OK
- ✅ "All prerequisites met!"

**If Failed**:
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force
```

---

### Scenario 2: Test Onboarding (Test Mode)

**Purpose**: Simulate onboarding new Reception students.

```powershell
.\Student-Onboarding-Offboarding.ps1 `
    -Operation Onboard `
    -CSVFile ".\Sample-NewStudents-Reception.csv" `
    -TestMode
```

**Expected Output**:
- Script reads CSV successfully
- Shows count of students to onboard
- Displays "[TEST MODE]" warnings for each operation
- No actual users created
- Logs created in `./Logs/` directory

**Verify**:
- Check log file: `./Logs/StudentLifecycle-Onboard-*.log`
- Confirm "[TEST MODE]" appears in log entries
- Review sanitized usernames (e.g., "Liam O'Connor" → "liam.oconnor")

---

### Scenario 3: Test Year 7 Onboarding

**Purpose**: Test secondary school intake with subjects.

```powershell
.\Student-Onboarding-Offboarding.ps1 `
    -Operation Onboard `
    -CSVFile ".\Sample-NewStudents-Year7.csv" `
    -YearGroup "Year7" `
    -TestMode
```

**Expected Output**:
- Students filtered to Year 7 only
- Subject groups identified (Maths, English, Science, etc.)
- Security group assignments logged
- No actual changes made

---

### Scenario 4: Test Year Group Transition

**Purpose**: Simulate annual year group rollover.

```powershell
.\Student-Onboarding-Offboarding.ps1 `
    -Operation Transition `
    -TestMode
```

**Expected Output**:
- Shows year group progression map
- Displays "[TEST MODE]" for transition operations
- Logs which groups would be updated
- No actual updates made

---

### Scenario 5: Test Offboarding

**Purpose**: Simulate graduate offboarding.

```powershell
.\Student-Onboarding-Offboarding.ps1 `
    -Operation Offboard `
    -TestMode
```

**Expected Output**:
- Shows 60-day retention policy
- Displays graduating year groups (Year 6, 11, 13)
- Logs offboarding process steps
- No accounts actually disabled

---

### Scenario 6: Test Reporting

**Purpose**: Generate test report structure.

```powershell
.\Student-Onboarding-Offboarding.ps1 `
    -Operation Report `
    -TestMode
```

**Expected Output**:
- Shows report generation process
- Creates sample report structure
- No actual data pulled from Entra ID

---

## Production Testing (Sandbox Environment)

If you have access to a test/sandbox Microsoft 365 tenant, run actual operations:

### Test 1: Onboard Single Test Student

**Create test CSV**:
```csv
FirstName,LastName,DateOfBirth,YearGroup,Class,Subjects
Test,Student,2018-09-15,Reception,TestClass,
```

**Run**:
```powershell
.\Student-Onboarding-Offboarding.ps1 `
    -Operation Onboard `
    -CSVFile ".\TestStudent.csv"
```

**Verify in Azure Portal**:
1. Navigate to Azure AD → Users
2. Search for "test.student@yourdomain.com"
3. Verify account created
4. Check Department field = "Reception"
5. Verify assigned to groups

**Verify in M365 Admin**:
1. Navigate to Users → Active users
2. Find test student
3. Check license assignment
4. Verify mailbox created

**Verify in Exchange Admin**:
1. Navigate to Recipients → Mailboxes
2. Find test student mailbox
3. Check permissions
4. Verify security admin has FullAccess

### Test 2: Generate Report

```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Report
```

**Verify**:
- HTML report opens in browser
- Shows test student
- CSV export created
- All data accurate

### Test 3: Offboard Test Student

**Mark for offboarding**:
1. Update test student's Department to "Graduated-Primary"
2. Add to "Graduated-Students-Archive" group

**Run**:
```powershell
.\Student-Onboarding-Offboarding.ps1 -Operation Offboard
```

**Verify**:
- Account disabled
- Licenses removed
- Mailbox still accessible (retention)

---

## Validation Checklist

After each test, verify:

### Logs Created
- [ ] Main log file exists in `./Logs/`
- [ ] Error log created (may be empty if no errors)
- [ ] Timestamps are accurate
- [ ] All operations logged

### Name Sanitization
- [ ] Apostrophes handled (O'Connor → oconnor for username)
- [ ] Special characters removed
- [ ] Long names truncated to 20 chars
- [ ] Display names preserve original formatting

### Security Groups
- [ ] Year group assignment correct
- [ ] Class group assignment correct
- [ ] Subject groups created and assigned
- [ ] Group naming follows convention

### User Properties
- [ ] Display Name formatted correctly
- [ ] User Principal Name follows pattern
- [ ] Department set to year group
- [ ] Usage Location set to "GB"
- [ ] Account enabled

### Email Delegation
- [ ] Security admin has FullAccess
- [ ] Security admin has SendAs
- [ ] AutoMapping disabled

### MFA Settings
- [ ] Force password change on first login
- [ ] MFA requirement logged

### Reports
- [ ] HTML report generates
- [ ] CSV export generates
- [ ] Data accuracy verified
- [ ] Report files timestamped

---

## Common Test Issues and Solutions

### Issue: "Microsoft.Graph module not found"
**Solution**: Install module:
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

### Issue: "Cannot connect to services"
**Solution**: 
- Verify admin permissions
- Try manual connection first:
```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"
Connect-ExchangeOnline
```

### Issue: "CSV file not found"
**Solution**: Use full path:
```powershell
$CSVPath = "C:\Path\To\Students.csv"
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile $CSVPath -TestMode
```

### Issue: Test mode still prompts for confirmation
**Solution**: This is expected behavior for safety. Type "Y" to continue test.

### Issue: Logs not created
**Solution**: 
- Check permissions on current directory
- Manually create Logs folder:
```powershell
New-Item -Path .\Logs -ItemType Directory -Force
```

---

## Test Mode vs Production

| Feature | Test Mode | Production |
|---------|-----------|------------|
| Connects to services | ❌ No | ✅ Yes |
| Creates users | ❌ No | ✅ Yes |
| Assigns groups | ❌ No | ✅ Yes |
| Assigns licenses | ❌ No | ✅ Yes |
| Creates logs | ✅ Yes | ✅ Yes |
| Shows operations | ✅ Yes | ✅ Yes |
| Requires confirmation | ✅ Yes | ✅ Yes |
| Safe to run | ✅ Always | ⚠️ With caution |

---

## Performance Testing

Test with different CSV sizes:

**Small batch (10 students)**:
```powershell
# Expected: ~2-3 minutes
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Small.csv"
```

**Medium batch (50 students)**:
```powershell
# Expected: ~10-15 minutes
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Medium.csv"
```

**Large batch (200+ students)**:
```powershell
# Expected: ~45-60 minutes
# Consider splitting into smaller batches
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Large.csv"
```

---

## Final Pre-Production Checklist

Before running in production:

- [ ] All tests passed in test mode
- [ ] Tested in sandbox environment (if available)
- [ ] Config.json updated with production values
- [ ] CSV files reviewed and validated
- [ ] Backup of current Entra ID state taken
- [ ] Stakeholders notified of timing
- [ ] Support team on standby
- [ ] Rollback plan documented
- [ ] Test single user first in production
- [ ] Verify single user creation successful
- [ ] Then proceed with batch operations

---

## Rollback Testing

Test ability to reverse operations:

1. **Create test user**
2. **Document user ID and properties**
3. **Manually disable/delete**
4. **Verify removal successful**
5. **Document process for production rollback**

---

## Monitoring During Testing

Watch these in real-time:

1. **PowerShell Console**: For immediate feedback
2. **Log File**: Tail the log in another window
   ```powershell
   Get-Content .\Logs\StudentLifecycle-*.log -Wait
   ```
3. **Azure AD Portal**: Refresh to see changes
4. **Task Manager**: Monitor memory/CPU usage

---

## Success Criteria

Tests are successful when:

✅ All prerequisites met  
✅ CSV imports correctly  
✅ Names sanitized properly  
✅ Test mode runs without errors  
✅ Logs created with correct information  
✅ Reports generate successfully  
✅ Sandbox testing (if done) creates users correctly  
✅ All verification checks pass  
✅ Performance acceptable  
✅ Documentation clear and accurate  

---

## Next Steps After Testing

Once all tests pass:

1. Document any issues found and resolved
2. Update config.json for production
3. Prepare final CSV files
4. Schedule production run
5. Brief support team
6. Execute with `-TestMode` first, then production
7. Monitor closely
8. Generate final reports
9. Archive logs
10. Document lessons learned

---

**Remember**: Testing is not optional. Always test with `-TestMode` first!
