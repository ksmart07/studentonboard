# studentonboard
Student Lifecycle Management System
Overview
Comprehensive PowerShell automation for managing student accounts through their entire educational journey - from Reception to Year 13, including onboarding, year group transitions, and offboarding.
Key Features

✅ Automated Entra ID Account Creation - Creates user accounts with appropriate naming conventions
✅ Year Group Transitions - Moves students between year groups and security groups
✅ Graduate Management - 60-day retention for Year 6, Year 11, and Year 13 graduates
✅ License Assignment - Assigns Microsoft 365 A1 student licenses
✅ Security Group Management - Automatic assignment to year/class groups
✅ Mailbox Delegation - Delegates all student mailboxes to safeguarding admin
✅ MFA Configuration - Sets default authentication with forced password change
✅ Comprehensive Logging - Detailed logs for auditing and troubleshooting
✅ HTML Reports - Professional reports with temporary passwords
✅ Checkpoints - Interactive validation at each major step

Prerequisites
Required PowerShell Modules
powershell# Install required modules (run as Administrator)
Install-Module -Name Microsoft.Graph.Users -Scope CurrentUser -Force
Install-Module -Name Microsoft.Graph.Groups -Scope CurrentUser -Force
Install-Module -Name Microsoft.Graph.Identity.SignIns -Scope CurrentUser -Force
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force
Required Permissions

Global Administrator or User Administrator role in Entra ID
Exchange Administrator for mailbox operations
Groups Administrator for security group management

Directory Structure
The script automatically creates:
C:\StudentManagement\
├── CSV\              # Input CSV files
├── Logs\             # Execution and error logs
├── Reports\          # HTML reports and CSV exports
└── Archive\          # Historical data
Configuration
Before Running - Update These Values

Domain Name (Line ~475)

powershell   [string]$Domain = "yourschool.edu"  # Change to your actual domain

Safeguarding Admin Email (Line ~37)

powershell   $SafeguardingAdminEmail = "safeguarding-admin@yourschool.edu"

IT Department MFA Phone (Line ~40)

powershell   $DefaultMFAPhone = "+441234567890"  # Your IT helpdesk number

License SKU (Line ~43)

powershell   # Find your SKU with: Get-MgSubscribedSku | Select SkuPartNumber
   $StudentLicenseSKU = "yourtenant:STANDARDWOFFPACK_STUDENT"

Security Groups (Lines ~520-544)
Update group names to match your Entra ID groups:

powershell   $GroupMappings = @{
       'Reception' = @('SG-Students-Primary', 'SG-Students-Reception')
       # ... update all groups
   }
CSV File Format
Required Columns
ColumnDescriptionExampleFirstNameStudent's first nameJohnLastNameStudent's surnameSmithDateOfBirthFormat: YYYY-MM-DD2015-09-15YearGroupCurrent year groupYear5NewYearGroupTarget year groupYear6StudentIDUnique identifierSTU001ParentEmailGuardian email (optional)parent@example.com
Valid Year Groups

Primary: Reception, Year1, Year2, Year3, Year4, Year5, Year6
Secondary: Year7, Year8, Year9, Year10, Year11
Sixth Form: Year12, Year13
Graduates: Use Graduate in NewYearGroup column

Special Cases
New Year 7 Students (from other schools)
csvFirstName,LastName,DateOfBirth,YearGroup,NewYearGroup,StudentID,ParentEmail
Emma,Wilson,2011-07-15,Year6,Year7,STU100,parent@email.com
New Sixth Form Students (from other schools)
csvFirstName,LastName,DateOfBirth,YearGroup,NewYearGroup,StudentID,ParentEmail
Tom,Davies,2007-06-20,Year11,Year12,STU200,parent@email.com
Graduating Students
csvFirstName,LastName,DateOfBirth,YearGroup,NewYearGroup,StudentID,ParentEmail
Sarah,Brown,2012-05-10,Year6,Graduate,STU007,parent@email.com
Alex,Green,2007-04-15,Year11,Graduate,STU012,parent@email.com
Lucy,White,2005-03-22,Year13,Graduate,STU014,parent@email.com
Name Handling
The script automatically handles:

Apostrophes: O'Connor → OConnor
Hyphens: Johnson-Smith → JohnsonSmith
Long names: Truncated to 64 characters
Special characters: Removed or replaced

Usage
Step 1: Prepare Your CSV

Copy the provided template to C:\StudentManagement\CSV\Students.csv
Fill in your student data
Ensure all required columns are present

Step 2: Run the Script
powershell# Open PowerShell as Administrator
cd C:\StudentManagement
.\StudentLifecycleManagement.ps1
Step 3: Interactive Checkpoints
The script will pause at key stages:

After prerequisite validation
After authentication
After CSV import
After student processing
Before mailbox delegation retry
Before graduate purge
Before verification and reporting

At each checkpoint:

Press Y to continue
Press N to abort
Press L to view last 20 log entries

Step 4: Review Reports
After completion, check:

HTML Report: C:\StudentManagement\Reports\StudentManagement_Report_[timestamp].html
Main Log: C:\StudentManagement\Logs\StudentManagement_[timestamp].log
Error Log: C:\StudentManagement\Logs\StudentManagement_Errors_[timestamp].log
Created Users CSV: C:\StudentManagement\Reports\CreatedUsers_[timestamp].csv

What the Script Does
For New Students (Onboarding)

✅ Creates Entra ID user account
✅ Generates User Principal Name (firstname.lastname@domain)
✅ Creates temporary password (forced change on first login)
✅ Assigns to year-appropriate security groups
✅ Assigns Microsoft 365 student license
✅ Configures MFA placeholder (IT phone number)
✅ Waits for mailbox provisioning
✅ Delegates mailbox to safeguarding admin (FullAccess + SendAs)
✅ Logs all actions

For Transitioning Students

✅ Verifies existing account
✅ Updates JobTitle to new year group
✅ Removes from previous year group security groups
✅ Adds to new year group security groups
✅ Maintains existing licenses and MFA
✅ Maintains mailbox delegation

For Graduates (Offboarding)

✅ Moves to "SG-Students-Graduates" group
✅ Removes from active year groups
✅ Disables account
✅ Converts mailbox to Shared (preserves data, removes license cost)
✅ Removes licenses
✅ Sets deletion date (60 days from offboarding)
✅ After 60 days, permanently deletes account

Troubleshooting
Issue: "Module not found"
Solution: Install required modules
powershellInstall-Module -Name Microsoft.Graph.Users -Force
Install-Module -Name ExchangeOnlineManagement -Force
Issue: "Access denied"
Solution: Ensure you have Global Administrator or User Administrator role
Issue: "Mailbox not found"
Cause: Mailbox provisioning can take 5-30 minutes
Solution:

The script waits up to 5 minutes automatically
Run the "Retry Mailbox Delegation" section later
Or manually delegate using Exchange Admin Center

Issue: "License assignment failed"
Solution: Check license availability
powershellConnect-MgGraph
Get-MgSubscribedSku | Select SkuPartNumber, ConsumedUnits, PrepaidUnits
Issue: "Security group not found"
Solution: Create missing security groups in Entra ID:
SG-Students-Primary
SG-Students-Reception
SG-Students-Year1
... (etc)
SG-Students-Graduates
Issue: "CSV validation failed"
Check:

All required columns present
Dates in YYYY-MM-DD format
No empty required fields
Valid year group names

Security Groups Setup
Create These Groups in Entra ID
Primary School Groups
SG-Students-Primary (all primary students)
SG-Students-Reception
SG-Students-Year1
SG-Students-Year2
SG-Students-Year3
SG-Students-Year4
SG-Students-Year5
SG-Students-Year6
Secondary School Groups
SG-Students-Secondary (all secondary students)
SG-Students-KS3 (Years 7-9)
SG-Students-Year7
SG-Students-Year8
SG-Students-Year9
SG-Students-KS4 (Years 10-11)
SG-Students-Year10
SG-Students-Year11
Sixth Form Groups
SG-Students-SixthForm (all sixth form)
SG-Students-KS5 (Years 12-13)
SG-Students-Year12
SG-Students-Year13
Special Groups
SG-Students-Graduates (60-day retention)
Post-Execution Tasks
1. Password Distribution

Never email passwords
Print securely and distribute via sealed envelopes
Or use secure password management system
HTML report contains all temporary passwords

2. Verify in Microsoft 365 Admin Center

Navigate to Users > Active users
Filter by department "Students"
Check licenses assigned
Verify account enabled

3. Verify in Exchange Admin Center

Navigate to Recipients > Mailboxes
Find student mailboxes
Check Manage mailbox delegation
Confirm safeguarding admin has FullAccess

4. Verify in Entra ID

Navigate to Users > All users
Select a student
Check Groups tab
Check Authentication methods tab
Verify Sign-ins (after first login)

5. Schedule Regular Graduate Purge
Set up scheduled task to run monthly:
powershell# Run only the graduate purge section
Remove-ExpiredGraduates
Best Practices
Annual Transitions (September)

Week before term: Run script with CSV for all transitions
Day before term: Run mailbox delegation retry
First day of term: Distribute passwords to form tutors
First week: Monitor error logs and verification reports

Mid-Year Additions

Update CSV with new students only
Run script as needed
NewYearGroup = current year group for new students

Graduate Retention

Year 6 → 60 days for secondary school applications
Year 11 → 60 days for sixth form enrollment
Year 13 → 60 days for university/employment records

Safeguarding Compliance

All student emails delegated to safeguarding admin
Mailbox auditing enabled
Regular review of mailbox access
Document all access in safeguarding logs

License Requirements
Students Need

Microsoft 365 A1 for Students (free) or
Microsoft 365 A3 for Students (paid)

What's Included in A1

Exchange Online (mailbox)
OneDrive (1TB storage)
Teams
Office Online
SharePoint

Check Available Licenses
powershellConnect-MgGraph
Get-MgSubscribedSku | Select SkuPartNumber, ConsumedUnits, @{N='Available';E={$_.PrepaidUnits.Enabled - $_.ConsumedUnits}}
Maintenance
Weekly Tasks

Review error logs
Check mailbox delegation retry queue
Monitor graduate deletion schedule

Monthly Tasks

Run graduate purge
Audit security group memberships
Review safeguarding mailbox access logs

Annual Tasks (Summer)

Archive previous year's reports
Update security groups if year structure changes
Review and update license assignments
Test script with sample data before September rush

Support and Logging
Log Files Location
C:\StudentManagement\Logs\
├── StudentManagement_[timestamp].log       # Main execution log
└── StudentManagement_Errors_[timestamp].log  # Errors only
Report Files Location
C:\StudentManagement\Reports\
├── StudentManagement_Report_[timestamp].html     # Interactive report
├── CreatedUsers_[timestamp].csv                  # Onboarded students
└── OffboardedUsers_[timestamp].csv               # Graduated students
Log Levels

INFO: Normal operations
SUCCESS: Completed successfully
WARNING: Non-critical issues
ERROR: Critical failures

Version History
v1.0 (Current)

Initial release
Full lifecycle management
Comprehensive logging
HTML reporting
Interactive checkpoints
Mailbox delegation
MFA configuration
Graduate retention and purge

Contributing
For updates or issues, contact your IT department or the script maintainer.
License
Internal use only - [Your School Name]

Last Updated: November 2025
Maintained by: KSMART IT 
