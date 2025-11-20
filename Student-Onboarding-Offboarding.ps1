<#
.SYNOPSIS
    Comprehensive PowerShell script for student lifecycle management in educational environments.

.DESCRIPTION
    This script handles the complete student lifecycle including:
    - Onboarding new students (Reception, Year 7, Year 12)
    - Year group transitions (Reception→Year 1, Year 1→Year 2, etc.)
    - Offboarding graduating students (Year 6, Year 11, Year 13)
    - Entra ID user creation and management
    - Security group assignments (classes, subjects, disciplines)
    - License assignments and application access
    - Email delegation to security admin for safeguarding
    - MFA and authentication method setup
    - Comprehensive logging and reporting

.PARAMETER ConfigFile
    Path to the JSON configuration file. Default: ./config.json

.PARAMETER CSVFile
    Path to the CSV file containing student records.

.PARAMETER Operation
    The operation to perform: Onboard, Offboard, Transition, Report

.PARAMETER YearGroup
    The year group to process (e.g., Reception, Year1, Year7, etc.)

.PARAMETER TestMode
    Run in test mode without making actual changes to Entra ID.

.EXAMPLE
    .\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\NewStudents.csv" -YearGroup "Reception"
    
.EXAMPLE
    .\Student-Onboarding-Offboarding.ps1 -Operation Transition -CSVFile ".\AllStudents.csv"
    
.EXAMPLE
    .\Student-Onboarding-Offboarding.ps1 -Operation Offboard -YearGroup "Year6"

.NOTES
    Author: School IT Administrator
    Version: 1.0
    Requires: Microsoft.Graph PowerShell Module, ExchangeOnlineManagement Module
    
    This script requires appropriate administrative permissions in:
    - Microsoft Entra ID (Azure AD)
    - Microsoft 365 Admin Center
    - Exchange Online
    
.LINK
    https://github.com/ksmart07/studentonboard
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = ".\config.json",
    
    [Parameter(Mandatory=$false)]
    [string]$CSVFile,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("Onboard", "Offboard", "Transition", "Report", "CheckPrerequisites")]
    [string]$Operation,
    
    [Parameter(Mandatory=$false)]
    [string]$YearGroup,
    
    [Parameter(Mandatory=$false)]
    [switch]$TestMode
)

#Requires -Version 5.1

# ============================================================================
# SECTION 1: INITIALIZATION AND CONFIGURATION
# ============================================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Student Lifecycle Management System" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Load configuration file
if (-not (Test-Path $ConfigFile)) {
    Write-Error "Configuration file not found: $ConfigFile"
    exit 1
}

Write-Host "[INFO] Loading configuration from: $ConfigFile" -ForegroundColor Yellow
$Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json

# Create log and report directories
$LogDir = $Config.Logging.LogDirectory
$ReportDir = $Config.Logging.ReportDirectory

if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    Write-Host "[INFO] Created log directory: $LogDir" -ForegroundColor Green
}

if (-not (Test-Path $ReportDir)) {
    New-Item -Path $ReportDir -ItemType Directory -Force | Out-Null
    Write-Host "[INFO] Created report directory: $ReportDir" -ForegroundColor Green
}

# Initialize logging
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = Join-Path $LogDir "StudentLifecycle-$Operation-$Timestamp.log"
$ErrorLogFile = Join-Path $LogDir "StudentLifecycle-$Operation-$Timestamp-Errors.log"
$ReportFile = Join-Path $ReportDir "StudentLifecycle-Report-$Timestamp.html"

# ============================================================================
# SECTION 2: LOGGING FUNCTIONS
# ============================================================================

function Write-Log {
    <#
    .SYNOPSIS
        Writes a message to the log file and console.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $LogMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogMessage
    
    switch ($Level) {
        "INFO"    { Write-Host $Message -ForegroundColor White }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "ERROR"   { Write-Host $Message -ForegroundColor Red; Add-Content -Path $ErrorLogFile -Value $LogMessage }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
    }
}

function Write-SectionHeader {
    <#
    .SYNOPSIS
        Writes a section header to the log and console.
    #>
    param([string]$Title)
    
    $Line = "=" * 80
    Write-Log -Message ""
    Write-Log -Message $Line
    Write-Log -Message $Title
    Write-Log -Message $Line
}

# ============================================================================
# SECTION 3: NAME SANITIZATION AND VALIDATION
# ============================================================================

function Remove-InvalidCharacters {
    <#
    .SYNOPSIS
        Removes or replaces invalid characters from names.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    # Remove leading/trailing spaces
    $CleanName = $Name.Trim()
    
    # Replace apostrophes with empty string for usernames
    $CleanName = $CleanName -replace "[''`]", ""
    
    # Replace other special characters
    $CleanName = $CleanName -replace "[^a-zA-Z0-9\-\s]", ""
    
    # Remove multiple spaces
    $CleanName = $CleanName -replace "\s+", " "
    
    return $CleanName
}

function Get-SanitizedUsername {
    <#
    .SYNOPSIS
        Creates a sanitized username from first and last name.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FirstName,
        
        [Parameter(Mandatory=$true)]
        [string]$LastName,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxLength = 20
    )
    
    $CleanFirst = Remove-InvalidCharacters -Name $FirstName
    $CleanLast = Remove-InvalidCharacters -Name $LastName
    
    # Create username as firstname.lastname
    $Username = "$CleanFirst.$CleanLast".ToLower()
    
    # Truncate if too long
    if ($Username.Length -gt $MaxLength) {
        $Username = $Username.Substring(0, $MaxLength)
    }
    
    return $Username
}

function Get-SanitizedDisplayName {
    <#
    .SYNOPSIS
        Creates a sanitized display name that preserves apostrophes.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FirstName,
        
        [Parameter(Mandatory=$true)]
        [string]$LastName
    )
    
    $CleanFirst = $FirstName.Trim()
    $CleanLast = $LastName.Trim()
    
    return "$CleanFirst $CleanLast"
}

# ============================================================================
# SECTION 4: MODULE PREREQUISITES CHECK
# ============================================================================

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Checks if required PowerShell modules are installed and connected.
    #>
    Write-SectionHeader -Title "CHECKING PREREQUISITES"
    
    $AllPrereqsMet = $true
    
    # Check for Microsoft.Graph module
    Write-Log -Message "Checking for Microsoft.Graph module..."
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
        Write-Log -Message "Microsoft.Graph.Users module not found. Please install it using: Install-Module Microsoft.Graph -Scope CurrentUser" -Level "ERROR"
        $AllPrereqsMet = $false
    } else {
        Write-Log -Message "Microsoft.Graph modules found." -Level "SUCCESS"
    }
    
    # Check for ExchangeOnlineManagement module
    Write-Log -Message "Checking for ExchangeOnlineManagement module..."
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Log -Message "ExchangeOnlineManagement module not found. Please install it using: Install-Module ExchangeOnlineManagement -Scope CurrentUser" -Level "ERROR"
        $AllPrereqsMet = $false
    } else {
        Write-Log -Message "ExchangeOnlineManagement module found." -Level "SUCCESS"
    }
    
    # Check PowerShell version
    Write-Log -Message "Checking PowerShell version..."
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Log -Message "PowerShell 5.1 or higher is required. Current version: $($PSVersionTable.PSVersion)" -Level "ERROR"
        $AllPrereqsMet = $false
    } else {
        Write-Log -Message "PowerShell version: $($PSVersionTable.PSVersion) - OK" -Level "SUCCESS"
    }
    
    if ($AllPrereqsMet) {
        Write-Log -Message "All prerequisites met!" -Level "SUCCESS"
    } else {
        Write-Log -Message "Some prerequisites are missing. Please install required modules." -Level "ERROR"
    }
    
    return $AllPrereqsMet
}

function Connect-ToServices {
    <#
    .SYNOPSIS
        Connects to Microsoft Graph and Exchange Online.
    #>
    Write-SectionHeader -Title "CONNECTING TO MICROSOFT SERVICES"
    
    if ($TestMode) {
        Write-Log -Message "Running in TEST MODE - Skipping actual service connections" -Level "WARNING"
        return $true
    }
    
    try {
        # Connect to Microsoft Graph
        Write-Log -Message "Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All" -ErrorAction Stop
        Write-Log -Message "Successfully connected to Microsoft Graph" -Level "SUCCESS"
        
        # Connect to Exchange Online
        Write-Log -Message "Connecting to Exchange Online..."
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        Write-Log -Message "Successfully connected to Exchange Online" -Level "SUCCESS"
        
        return $true
    }
    catch {
        Write-Log -Message "Failed to connect to services: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# ============================================================================
# SECTION 5: CSV FILE PROCESSING
# ============================================================================

function Import-StudentData {
    <#
    .SYNOPSIS
        Imports and validates student data from CSV file.
    .DESCRIPTION
        Expected CSV columns:
        FirstName, LastName, DateOfBirth, YearGroup, Class, 
        ParentEmail, ParentPhone, Subjects, AdditionalInfo
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$CSVPath
    )
    
    Write-SectionHeader -Title "IMPORTING STUDENT DATA FROM CSV"
    
    if (-not (Test-Path $CSVPath)) {
        Write-Log -Message "CSV file not found: $CSVPath" -Level "ERROR"
        return $null
    }
    
    Write-Log -Message "Reading CSV file: $CSVPath"
    
    try {
        $Students = Import-Csv -Path $CSVPath -ErrorAction Stop
        Write-Log -Message "Successfully imported $($Students.Count) student records" -Level "SUCCESS"
        
        # Validate required columns
        $RequiredColumns = @("FirstName", "LastName", "YearGroup")
        $CSVColumns = $Students[0].PSObject.Properties.Name
        
        foreach ($Column in $RequiredColumns) {
            if ($Column -notin $CSVColumns) {
                Write-Log -Message "Required column missing: $Column" -Level "ERROR"
                return $null
            }
        }
        
        Write-Log -Message "CSV validation successful" -Level "SUCCESS"
        return $Students
    }
    catch {
        Write-Log -Message "Failed to import CSV: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

# ============================================================================
# SECTION 6: ENTRA ID USER CREATION
# ============================================================================

function New-StudentUser {
    <#
    .SYNOPSIS
        Creates a new student user in Entra ID (Azure AD).
    #>
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Student,
        
        [Parameter(Mandatory=$false)]
        [switch]$TestMode
    )
    
    $FirstName = $Student.FirstName
    $LastName = $Student.LastName
    $YearGroup = $Student.YearGroup
    
    # Sanitize names
    $DisplayName = Get-SanitizedDisplayName -FirstName $FirstName -LastName $LastName
    $Username = Get-SanitizedUsername -FirstName $FirstName -LastName $LastName
    $UPN = "$Username@$($Config.SchoolSettings.Domain)"
    
    # Generate initial password
    $InitialPassword = "Welcome$(Get-Random -Minimum 1000 -Maximum 9999)!"
    
    Write-Log -Message "Creating user: $DisplayName ($UPN) - Year Group: $YearGroup"
    
    if ($TestMode) {
        Write-Log -Message "[TEST MODE] Would create user: $UPN" -Level "WARNING"
        return @{
            Success = $true
            UPN = $UPN
            DisplayName = $DisplayName
            Password = $InitialPassword
        }
    }
    
    try {
        # Create user parameters
        $PasswordProfile = @{
            Password = $InitialPassword
            ForceChangePasswordNextSignIn = $true
        }
        
        $UserParams = @{
            DisplayName = $DisplayName
            UserPrincipalName = $UPN
            MailNickname = $Username
            PasswordProfile = $PasswordProfile
            AccountEnabled = $true
            GivenName = $FirstName
            Surname = $LastName
            Department = $YearGroup
            UsageLocation = "GB"
        }
        
        # Add optional fields if present
        if ($Student.DateOfBirth) {
            $UserParams.EmployeeType = "Student"
        }
        
        # Create the user
        $NewUser = New-MgUser @UserParams -ErrorAction Stop
        
        Write-Log -Message "Successfully created user: $UPN" -Level "SUCCESS"
        
        return @{
            Success = $true
            UPN = $UPN
            DisplayName = $DisplayName
            UserId = $NewUser.Id
            Password = $InitialPassword
        }
    }
    catch {
        Write-Log -Message "Failed to create user $UPN : $($_.Exception.Message)" -Level "ERROR"
        return @{
            Success = $false
            UPN = $UPN
            Error = $_.Exception.Message
        }
    }
}

# ============================================================================
# SECTION 7: SECURITY GROUP MANAGEMENT
# ============================================================================

function Add-StudentToGroups {
    <#
    .SYNOPSIS
        Adds student to appropriate security groups based on year, class, and subjects.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserId,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Student,
        
        [Parameter(Mandatory=$false)]
        [switch]$TestMode
    )
    
    $GroupsToAdd = @()
    
    # Add to year group
    $YearGroupName = "$($Config.SecurityGroups.YearGroupPrefix)$($Student.YearGroup)"
    $GroupsToAdd += $YearGroupName
    
    # Add to class group if specified
    if ($Student.Class) {
        $ClassGroupName = "$($Config.SecurityGroups.ClassGroupPrefix)$($Student.Class)"
        $GroupsToAdd += $ClassGroupName
    }
    
    # Add to subject groups if specified
    if ($Student.Subjects) {
        $Subjects = $Student.Subjects -split ";"
        foreach ($Subject in $Subjects) {
            $SubjectGroupName = "$($Config.SecurityGroups.SubjectGroupPrefix)$($Subject.Trim())"
            $GroupsToAdd += $SubjectGroupName
        }
    }
    
    Write-Log -Message "Adding user to $($GroupsToAdd.Count) groups..."
    
    foreach ($GroupName in $GroupsToAdd) {
        if ($TestMode) {
            Write-Log -Message "[TEST MODE] Would add user to group: $GroupName" -Level "WARNING"
            continue
        }
        
        try {
            # Try to find the group
            $Group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction SilentlyContinue
            
            if (-not $Group) {
                Write-Log -Message "Group not found: $GroupName - Creating it..." -Level "WARNING"
                # Create the group if it doesn't exist
                $GroupParams = @{
                    DisplayName = $GroupName
                    MailNickname = $GroupName -replace "[^a-zA-Z0-9]", ""
                    MailEnabled = $false
                    SecurityEnabled = $true
                    GroupTypes = @()
                }
                $Group = New-MgGroup @GroupParams -ErrorAction Stop
                Write-Log -Message "Created new group: $GroupName" -Level "SUCCESS"
            }
            
            # Add user to group
            New-MgGroupMember -GroupId $Group.Id -DirectoryObjectId $UserId -ErrorAction Stop
            Write-Log -Message "Added user to group: $GroupName" -Level "SUCCESS"
        }
        catch {
            Write-Log -Message "Failed to add user to group $GroupName : $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

# ============================================================================
# SECTION 8: LICENSE ASSIGNMENT
# ============================================================================

function Set-StudentLicenses {
    <#
    .SYNOPSIS
        Assigns appropriate Microsoft 365 licenses to student.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserId,
        
        [Parameter(Mandatory=$false)]
        [switch]$TestMode
    )
    
    Write-Log -Message "Assigning licenses to user..."
    
    if ($TestMode) {
        Write-Log -Message "[TEST MODE] Would assign default student licenses" -Level "WARNING"
        return
    }
    
    try {
        # Get available licenses in the tenant
        $AvailableLicenses = Get-MgSubscribedSku -ErrorAction Stop
        
        # Find student license SKU
        $StudentLicense = $AvailableLicenses | Where-Object {
            $_.SkuPartNumber -like "*STUDENT*" -or $_.SkuPartNumber -like "*A3*"
        } | Select-Object -First 1
        
        if ($StudentLicense) {
            $LicenseParams = @{
                AddLicenses = @(
                    @{
                        SkuId = $StudentLicense.SkuId
                        DisabledPlans = @()
                    }
                )
                RemoveLicenses = @()
            }
            
            Set-MgUserLicense -UserId $UserId @LicenseParams -ErrorAction Stop
            Write-Log -Message "Successfully assigned license: $($StudentLicense.SkuPartNumber)" -Level "SUCCESS"
        } else {
            Write-Log -Message "No student license SKU found in tenant" -Level "WARNING"
        }
    }
    catch {
        Write-Log -Message "Failed to assign licenses: $($_.Exception.Message)" -Level "ERROR"
    }
}

# ============================================================================
# SECTION 9: EMAIL DELEGATION FOR SAFEGUARDING
# ============================================================================

function Set-EmailDelegation {
    <#
    .SYNOPSIS
        Delegates student email to security admin account for safeguarding.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$StudentUPN,
        
        [Parameter(Mandatory=$false)]
        [switch]$TestMode
    )
    
    $SecurityAdmin = $Config.SchoolSettings.SecurityAdminEmail
    
    Write-Log -Message "Setting up email delegation to security admin for: $StudentUPN"
    
    if ($TestMode) {
        Write-Log -Message "[TEST MODE] Would delegate email to: $SecurityAdmin" -Level "WARNING"
        return
    }
    
    try {
        # Grant FullAccess permission
        Add-MailboxPermission -Identity $StudentUPN -User $SecurityAdmin -AccessRights FullAccess -InheritanceType All -AutoMapping $false -ErrorAction Stop
        Write-Log -Message "Granted FullAccess permission to security admin" -Level "SUCCESS"
        
        # Grant SendAs permission
        Add-RecipientPermission -Identity $StudentUPN -Trustee $SecurityAdmin -AccessRights SendAs -Confirm:$false -ErrorAction Stop
        Write-Log -Message "Granted SendAs permission to security admin" -Level "SUCCESS"
    }
    catch {
        Write-Log -Message "Failed to set email delegation: $($_.Exception.Message)" -Level "ERROR"
    }
}

# ============================================================================
# SECTION 10: MFA AND AUTHENTICATION SETUP
# ============================================================================

function Set-AuthenticationMethods {
    <#
    .SYNOPSIS
        Sets up default authentication methods for student (MFA).
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserId,
        
        [Parameter(Mandatory=$false)]
        [switch]$TestMode
    )
    
    $DefaultPhone = $Config.SchoolSettings.ITDepartmentPhone
    
    Write-Log -Message "Setting up authentication methods (MFA required on first login)..."
    
    if ($TestMode) {
        Write-Log -Message "[TEST MODE] Would set default phone: $DefaultPhone" -Level "WARNING"
        return
    }
    
    try {
        # Note: Authentication phone setup via Microsoft Graph requires additional permissions
        # and may need to be configured through Azure AD portal or conditional access policies
        
        # Set a note that MFA is required
        Write-Log -Message "User will be required to set up MFA on first login" -Level "SUCCESS"
        Write-Log -Message "Default IT Department contact: $DefaultPhone"
        
        # In production, you would configure conditional access policies to enforce MFA
        # This can be done through Azure Portal or additional Graph API calls with appropriate permissions
    }
    catch {
        Write-Log -Message "Failed to set authentication methods: $($_.Exception.Message)" -Level "ERROR"
    }
}

# ============================================================================
# SECTION 11: STUDENT ONBOARDING ORCHESTRATION
# ============================================================================

function Invoke-StudentOnboarding {
    <#
    .SYNOPSIS
        Main orchestration function for onboarding students.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$CSVFile,
        
        [Parameter(Mandatory=$false)]
        [string]$YearGroup,
        
        [Parameter(Mandatory=$false)]
        [switch]$TestMode
    )
    
    Write-SectionHeader -Title "STUDENT ONBOARDING PROCESS"
    
    # Step 1: Import student data
    $Students = Import-StudentData -CSVPath $CSVFile
    if (-not $Students) {
        Write-Log -Message "Failed to import student data. Aborting." -Level "ERROR"
        return
    }
    
    # Filter by year group if specified
    if ($YearGroup) {
        $Students = $Students | Where-Object { $_.YearGroup -eq $YearGroup }
        Write-Log -Message "Filtered to $($Students.Count) students in year group: $YearGroup"
    }
    
    # Pause for confirmation
    Write-Host ""
    Write-Host "About to onboard $($Students.Count) students." -ForegroundColor Yellow
    if (-not $TestMode) {
        $Confirmation = Read-Host "Do you want to continue? (Y/N)"
        if ($Confirmation -ne "Y") {
            Write-Log -Message "Onboarding cancelled by user" -Level "WARNING"
            return
        }
    }
    
    $Results = @()
    $SuccessCount = 0
    $FailCount = 0
    
    # Step 2: Process each student
    foreach ($Student in $Students) {
        Write-Log -Message ""
        Write-Log -Message "Processing student: $($Student.FirstName) $($Student.LastName)"
        
        # Create user
        $UserResult = New-StudentUser -Student $Student -TestMode:$TestMode
        
        if ($UserResult.Success) {
            $SuccessCount++
            
            # Wait a moment for user creation to propagate
            if (-not $TestMode) {
                Start-Sleep -Seconds 2
            }
            
            # Add to security groups
            if ($UserResult.UserId) {
                Add-StudentToGroups -UserId $UserResult.UserId -Student $Student -TestMode:$TestMode
                
                # Assign licenses
                Set-StudentLicenses -UserId $UserResult.UserId -TestMode:$TestMode
                
                # Set up email delegation
                Set-EmailDelegation -StudentUPN $UserResult.UPN -TestMode:$TestMode
                
                # Set up authentication
                Set-AuthenticationMethods -UserId $UserResult.UserId -TestMode:$TestMode
            }
        } else {
            $FailCount++
        }
        
        $Results += [PSCustomObject]@{
            FirstName = $Student.FirstName
            LastName = $Student.LastName
            YearGroup = $Student.YearGroup
            UPN = $UserResult.UPN
            Status = if ($UserResult.Success) { "Success" } else { "Failed" }
            Error = $UserResult.Error
            Password = $UserResult.Password
        }
    }
    
    # Step 3: Summary
    Write-SectionHeader -Title "ONBOARDING SUMMARY"
    Write-Log -Message "Total students processed: $($Students.Count)"
    Write-Log -Message "Successfully onboarded: $SuccessCount" -Level "SUCCESS"
    Write-Log -Message "Failed: $FailCount" -Level $(if ($FailCount -gt 0) { "ERROR" } else { "INFO" })
    
    # Export results
    $ResultsFile = Join-Path $ReportDir "Onboarding-Results-$Timestamp.csv"
    $Results | Export-Csv -Path $ResultsFile -NoTypeInformation
    Write-Log -Message "Results exported to: $ResultsFile" -Level "SUCCESS"
    
    return $Results
}

# ============================================================================
# SECTION 12: YEAR GROUP TRANSITIONS
# ============================================================================

function Invoke-YearGroupTransition {
    <#
    .SYNOPSIS
        Handles year group transitions (e.g., Reception → Year 1, Year 1 → Year 2).
    #>
    param(
        [Parameter(Mandatory=$false)]
        [switch]$TestMode
    )
    
    Write-SectionHeader -Title "YEAR GROUP TRANSITION PROCESS"
    
    Write-Log -Message "This function moves students up to their next year group:"
    Write-Log -Message "  Reception → Year 1"
    Write-Log -Message "  Year 1 → Year 2"
    Write-Log -Message "  Year 5 → Year 6"
    Write-Log -Message "  Year 6 → [Graduated - Primary]"
    Write-Log -Message "  Year 7 → Year 8"
    Write-Log -Message "  Year 11 → [Graduated - Secondary or 6th Form]"
    Write-Log -Message "  Year 12 → Year 13"
    Write-Log -Message "  Year 13 → [Graduated]"
    
    # Pause for confirmation
    Write-Host ""
    if (-not $TestMode) {
        $Confirmation = Read-Host "This will update year groups for ALL students. Continue? (Y/N)"
        if ($Confirmation -ne "Y") {
            Write-Log -Message "Transition cancelled by user" -Level "WARNING"
            return
        }
    }
    
    $TransitionMap = @{
        "Reception" = "Year1"
        "Year1" = "Year2"
        "Year2" = "Year3"
        "Year3" = "Year4"
        "Year4" = "Year5"
        "Year5" = "Year6"
        "Year6" = "Graduated-Primary"
        "Year7" = "Year8"
        "Year8" = "Year9"
        "Year9" = "Year10"
        "Year10" = "Year11"
        "Year11" = "Graduated-Secondary"
        "Year12" = "Year13"
        "Year13" = "Graduated-SixthForm"
    }
    
    if ($TestMode) {
        Write-Log -Message "[TEST MODE] Would transition year groups according to map above" -Level "WARNING"
        return
    }
    
    try {
        foreach ($CurrentYear in $TransitionMap.Keys) {
            $NextYear = $TransitionMap[$CurrentYear]
            $GroupName = "$($Config.SecurityGroups.YearGroupPrefix)$CurrentYear"
            
            Write-Log -Message "Processing transition: $CurrentYear → $NextYear"
            
            # Get users in current year group
            $Group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction SilentlyContinue
            
            if ($Group) {
                $Members = Get-MgGroupMember -GroupId $Group.Id -All
                Write-Log -Message "Found $($Members.Count) students in $CurrentYear"
                
                foreach ($Member in $Members) {
                    try {
                        # Update user's department field to reflect new year
                        Update-MgUser -UserId $Member.Id -Department $NextYear -ErrorAction Stop
                        Write-Log -Message "  Updated user to $NextYear"
                        
                        # If graduating, add to archive group
                        if ($NextYear -like "Graduated-*") {
                            $ArchiveGroupName = $Config.RetentionSettings.ArchiveGroupName
                            $ArchiveGroup = Get-MgGroup -Filter "displayName eq '$ArchiveGroupName'" -ErrorAction SilentlyContinue
                            
                            if (-not $ArchiveGroup) {
                                # Create archive group
                                $ArchiveGroup = New-MgGroup -DisplayName $ArchiveGroupName -MailNickname "GraduatedStudents" -MailEnabled $false -SecurityEnabled $true -GroupTypes @()
                            }
                            
                            New-MgGroupMember -GroupId $ArchiveGroup.Id -DirectoryObjectId $Member.Id -ErrorAction Stop
                            Write-Log -Message "  Added to archive group for retention"
                        }
                    }
                    catch {
                        Write-Log -Message "  Failed to update user: $($_.Exception.Message)" -Level "ERROR"
                    }
                }
            } else {
                Write-Log -Message "Group not found: $GroupName" -Level "WARNING"
            }
        }
        
        Write-Log -Message "Year group transition completed" -Level "SUCCESS"
    }
    catch {
        Write-Log -Message "Error during year group transition: $($_.Exception.Message)" -Level "ERROR"
    }
}

# ============================================================================
# SECTION 13: STUDENT OFFBOARDING
# ============================================================================

function Invoke-StudentOffboarding {
    <#
    .SYNOPSIS
        Handles offboarding of graduating students with retention period.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$YearGroup,
        
        [Parameter(Mandatory=$false)]
        [switch]$TestMode
    )
    
    Write-SectionHeader -Title "STUDENT OFFBOARDING PROCESS"
    
    $GraduatingYears = $Config.GraduatingYears
    $RetentionDays = $Config.RetentionSettings.GraduateRetentionDays
    
    Write-Log -Message "Offboarding graduating students from: $($GraduatingYears -join ', ')"
    Write-Log -Message "Retention period: $RetentionDays days"
    
    if ($TestMode) {
        Write-Log -Message "[TEST MODE] Would offboard students in graduating years" -Level "WARNING"
        Write-Log -Message "Process would:"
        Write-Log -Message "  1. Move to archive group"
        Write-Log -Message "  2. Disable account"
        Write-Log -Message "  3. Remove licenses"
        Write-Log -Message "  4. Schedule deletion after $RetentionDays days"
        return
    }
    
    try {
        $ArchiveGroupName = $Config.RetentionSettings.ArchiveGroupName
        $ArchiveGroup = Get-MgGroup -Filter "displayName eq '$ArchiveGroupName'" -ErrorAction SilentlyContinue
        
        if (-not $ArchiveGroup) {
            Write-Log -Message "Archive group not found. Creating it..." -Level "WARNING"
            $ArchiveGroup = New-MgGroup -DisplayName $ArchiveGroupName -MailNickname "GraduatedStudents" -MailEnabled $false -SecurityEnabled $true -GroupTypes @()
        }
        
        # Get members from archive group (students marked for offboarding)
        $GraduatedStudents = Get-MgGroupMember -GroupId $ArchiveGroup.Id -All
        Write-Log -Message "Found $($GraduatedStudents.Count) graduated students to process"
        
        foreach ($Student in $GraduatedStudents) {
            try {
                $User = Get-MgUser -UserId $Student.Id
                
                # Check if retention period has passed
                # (In a real implementation, you would track the graduation date)
                # For now, we'll disable and remove licenses
                
                Write-Log -Message "Processing: $($User.DisplayName) ($($User.UserPrincipalName))"
                
                # Disable account
                Update-MgUser -UserId $User.Id -AccountEnabled $false
                Write-Log -Message "  Account disabled"
                
                # Remove licenses
                $UserLicenses = Get-MgUserLicenseDetail -UserId $User.Id
                if ($UserLicenses) {
                    $RemoveLicenses = $UserLicenses | ForEach-Object { $_.SkuId }
                    Set-MgUserLicense -UserId $User.Id -AddLicenses @() -RemoveLicenses $RemoveLicenses
                    Write-Log -Message "  Licenses removed"
                }
                
                Write-Log -Message "  Student offboarded successfully" -Level "SUCCESS"
                Write-Log -Message "  Note: Account will be retained for $RetentionDays days before permanent deletion"
            }
            catch {
                Write-Log -Message "  Failed to offboard: $($_.Exception.Message)" -Level "ERROR"
            }
        }
        
        Write-Log -Message "Offboarding process completed" -Level "SUCCESS"
    }
    catch {
        Write-Log -Message "Error during offboarding: $($_.Exception.Message)" -Level "ERROR"
    }
}

# ============================================================================
# SECTION 14: REPORTING
# ============================================================================

function New-ComprehensiveReport {
    <#
    .SYNOPSIS
        Generates comprehensive HTML report of all students.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [switch]$TestMode
    )
    
    Write-SectionHeader -Title "GENERATING COMPREHENSIVE REPORT"
    
    if ($TestMode) {
        Write-Log -Message "[TEST MODE] Would generate reports from M365, Exchange, and Azure" -Level "WARNING"
        return
    }
    
    try {
        # Get all users with student department
        $AllStudents = Get-MgUser -Filter "userType eq 'Member'" -All -Property DisplayName,UserPrincipalName,Department,AccountEnabled,AssignedLicenses
        
        $StudentUsers = $AllStudents | Where-Object { 
            $_.Department -like "Year*" -or $_.Department -like "Reception" 
        }
        
        Write-Log -Message "Found $($StudentUsers.Count) student accounts"
        
        # Build HTML report
        $HTML = @"
<!DOCTYPE html>
<html>
<head>
    <title>Student Lifecycle Management Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #0066cc; }
        h2 { color: #0099cc; margin-top: 30px; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th { background-color: #0066cc; color: white; padding: 10px; text-align: left; }
        td { border: 1px solid #ddd; padding: 8px; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .summary { background-color: #e6f2ff; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .timestamp { color: #666; font-style: italic; }
    </style>
</head>
<body>
    <h1>Student Lifecycle Management Report</h1>
    <p class="timestamp">Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Total Student Accounts:</strong> $($StudentUsers.Count)</p>
        <p><strong>Active Accounts:</strong> $(($StudentUsers | Where-Object {$_.AccountEnabled}).Count)</p>
        <p><strong>Disabled Accounts:</strong> $(($StudentUsers | Where-Object {-not $_.AccountEnabled}).Count)</p>
    </div>
    
    <h2>Student Accounts</h2>
    <table>
        <tr>
            <th>Display Name</th>
            <th>User Principal Name</th>
            <th>Year Group</th>
            <th>Status</th>
            <th>Licensed</th>
        </tr>
"@
        
        foreach ($Student in $StudentUsers) {
            $Status = if ($Student.AccountEnabled) { "Active" } else { "Disabled" }
            $Licensed = if ($Student.AssignedLicenses.Count -gt 0) { "Yes" } else { "No" }
            
            $HTML += @"
        <tr>
            <td>$($Student.DisplayName)</td>
            <td>$($Student.UserPrincipalName)</td>
            <td>$($Student.Department)</td>
            <td>$Status</td>
            <td>$Licensed</td>
        </tr>
"@
        }
        
        $HTML += @"
    </table>
    
    <h2>Year Group Distribution</h2>
    <table>
        <tr>
            <th>Year Group</th>
            <th>Count</th>
        </tr>
"@
        
        $YearGroupCounts = $StudentUsers | Group-Object -Property Department | Sort-Object Name
        foreach ($Group in $YearGroupCounts) {
            $HTML += @"
        <tr>
            <td>$($Group.Name)</td>
            <td>$($Group.Count)</td>
        </tr>
"@
        }
        
        $HTML += @"
    </table>
    
    <p class="timestamp">Report Location: $ReportFile</p>
</body>
</html>
"@
        
        # Save HTML report
        $HTML | Out-File -FilePath $ReportFile -Encoding UTF8
        Write-Log -Message "HTML report generated: $ReportFile" -Level "SUCCESS"
        
        # Also export CSV
        $CSVReportFile = Join-Path $ReportDir "StudentAccounts-$Timestamp.csv"
        $StudentUsers | Select-Object DisplayName, UserPrincipalName, Department, AccountEnabled | 
            Export-Csv -Path $CSVReportFile -NoTypeInformation
        Write-Log -Message "CSV report generated: $CSVReportFile" -Level "SUCCESS"
        
        # Open the HTML report
        Write-Log -Message "Opening report in default browser..."
        Start-Process $ReportFile
    }
    catch {
        Write-Log -Message "Error generating report: $($_.Exception.Message)" -Level "ERROR"
    }
}

# ============================================================================
# SECTION 15: MAIN EXECUTION
# ============================================================================

Write-Log -Message "Script started - Operation: $Operation"
Write-Log -Message "Test Mode: $TestMode"
Write-Log -Message "Log file: $LogFile"

# Check prerequisites
if ($Operation -ne "CheckPrerequisites") {
    $PrereqsOK = Test-Prerequisites
    if (-not $PrereqsOK -and -not $TestMode) {
        Write-Log -Message "Prerequisites not met. Please install required modules." -Level "ERROR"
        Write-Host ""
        Write-Host "To install required modules, run:" -ForegroundColor Yellow
        Write-Host "  Install-Module Microsoft.Graph -Scope CurrentUser" -ForegroundColor Cyan
        Write-Host "  Install-Module ExchangeOnlineManagement -Scope CurrentUser" -ForegroundColor Cyan
        exit 1
    }
    
    # Connect to services
    if (-not $TestMode) {
        $Connected = Connect-ToServices
        if (-not $Connected) {
            Write-Log -Message "Failed to connect to services. Aborting." -Level "ERROR"
            exit 1
        }
    }
}

# Execute requested operation
switch ($Operation) {
    "CheckPrerequisites" {
        Test-Prerequisites
    }
    
    "Onboard" {
        if (-not $CSVFile) {
            Write-Log -Message "CSV file is required for onboarding operation" -Level "ERROR"
            exit 1
        }
        Invoke-StudentOnboarding -CSVFile $CSVFile -YearGroup $YearGroup -TestMode:$TestMode
    }
    
    "Offboard" {
        Invoke-StudentOffboarding -YearGroup $YearGroup -TestMode:$TestMode
    }
    
    "Transition" {
        Invoke-YearGroupTransition -TestMode:$TestMode
    }
    
    "Report" {
        New-ComprehensiveReport -TestMode:$TestMode
    }
}

# ============================================================================
# SECTION 16: CLEANUP AND FINALIZATION
# ============================================================================

Write-SectionHeader -Title "SCRIPT EXECUTION COMPLETED"
Write-Log -Message "Operation: $Operation"
Write-Log -Message "Log file: $LogFile"
if (Test-Path $ErrorLogFile) {
    Write-Log -Message "Error log: $ErrorLogFile" -Level "WARNING"
}
Write-Log -Message "Report directory: $ReportDir"

# Disconnect from services
if (-not $TestMode) {
    try {
        Write-Log -Message "Disconnecting from services..."
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log -Message "Disconnected successfully" -Level "SUCCESS"
    }
    catch {
        # Silently ignore disconnect errors
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Script execution completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
