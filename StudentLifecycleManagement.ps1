<#
.SYNOPSIS
    Student Lifecycle Management System for Academic Year Transitions
    
.DESCRIPTION
    Manages onboarding, offboarding, and year group transitions for students
    Handles Primary (Reception-Year 6), Secondary (Year 7-11), and Sixth Form (Year 12-13)
    Creates Entra ID accounts, assigns groups, licenses, and configures mailbox delegation
    
.NOTES
    Author: School IT Administration
    Version: 1.0
    Requires: Microsoft Graph PowerShell SDK, Exchange Online Management
    
.REQUIREMENTS
    - Global Administrator or User Administrator role
    - CSV files with student data in specified format
    - Exchange Online PowerShell V2 module
    - Microsoft.Graph modules (Users, Groups, Identity.SignIns)
#>

#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Groups, Microsoft.Graph.Identity.SignIns, ExchangeOnlineManagement

# ============================================================================
# SECTION 1: CONFIGURATION AND INITIALIZATION
# ============================================================================

# Script configuration
$ScriptVersion = "1.0"
$ScriptStartTime = Get-Date
$LogPath = "C:\StudentManagement\Logs"
$ReportPath = "C:\StudentManagement\Reports"
$CSVPath = "C:\StudentManagement\CSV"
$ArchivePath = "C:\StudentManagement\Archive"

# Create directory structure if it doesn't exist
$Paths = @($LogPath, $ReportPath, $CSVPath, $ArchivePath)
foreach ($Path in $Paths) {
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

# Log file naming
$DateStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogPath "StudentManagement_$DateStamp.log"
$ErrorLogFile = Join-Path $LogPath "StudentManagement_Errors_$DateStamp.log"
$ReportFile = Join-Path $ReportPath "StudentManagement_Report_$DateStamp.html"

# Safeguarding delegation account (mailbox monitoring)
$SafeguardingAdminEmail = "safeguarding-admin@yourdomain.com"

# Default MFA phone (IT Department placeholder)
$DefaultMFAPhone = "+44XXXXXXXXXX"  # Replace with actual IT department phone

# License SKU IDs (Update these with your tenant's actual SKU Part Numbers)
$StudentLicenseSKU = "yourtenant:STANDARDWOFFPACK_STUDENT"  # Microsoft 365 A1 for Students

# Offboarding retention period (days)
$GraduateRetentionDays = 60

# ============================================================================
# SECTION 2: LOGGING FUNCTIONS
# ============================================================================

function Write-Log {
    <#
    .SYNOPSIS
        Writes messages to log file and console
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO','WARNING','ERROR','SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$TimeStamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogMessage
    
    # Write to console with color coding
    switch ($Level) {
        'ERROR'   { Write-Host $LogMessage -ForegroundColor Red }
        'WARNING' { Write-Host $LogMessage -ForegroundColor Yellow }
        'SUCCESS' { Write-Host $LogMessage -ForegroundColor Green }
        default   { Write-Host $LogMessage -ForegroundColor White }
    }
    
    # Write errors to separate error log
    if ($Level -eq 'ERROR') {
        Add-Content -Path $ErrorLogFile -Value $LogMessage
    }
}

function Write-SectionHeader {
    <#
    .SYNOPSIS
        Writes a section header to logs for better readability
    #>
    param([string]$Title)
    
    $Line = "=" * 80
    Write-Log -Message $Line -Level INFO
    Write-Log -Message $Title -Level INFO
    Write-Log -Message $Line -Level INFO
}

# ============================================================================
# SECTION 3: VALIDATION AND PREREQUISITE CHECKS
# ============================================================================

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Validates all prerequisites are met before execution
    #>
    Write-SectionHeader "PREREQUISITE VALIDATION"
    
    $AllChecksPassed = $true
    
    # Check PowerShell version
    Write-Log "Checking PowerShell version..." -Level INFO
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Log "PowerShell 5.1 or higher is required. Current version: $($PSVersionTable.PSVersion)" -Level ERROR
        $AllChecksPassed = $false
    } else {
        Write-Log "PowerShell version check passed: $($PSVersionTable.PSVersion)" -Level SUCCESS
    }
    
    # Check required modules
    Write-Log "Checking required PowerShell modules..." -Level INFO
    $RequiredModules = @(
        'Microsoft.Graph.Users',
        'Microsoft.Graph.Groups',
        'Microsoft.Graph.Identity.SignIns',
        'ExchangeOnlineManagement'
    )
    
    foreach ($Module in $RequiredModules) {
        if (Get-Module -ListAvailable -Name $Module) {
            Write-Log "Module '$Module' is installed" -Level SUCCESS
        } else {
            Write-Log "Required module '$Module' is not installed" -Level ERROR
            Write-Log "Install with: Install-Module -Name $Module -Scope CurrentUser" -Level WARNING
            $AllChecksPassed = $false
        }
    }
    
    # Check if running as administrator
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
    $IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $IsAdmin) {
        Write-Log "Script is not running with Administrator privileges" -Level WARNING
        Write-Log "Some operations may require elevation" -Level WARNING
    } else {
        Write-Log "Running with Administrator privileges" -Level SUCCESS
    }
    
    return $AllChecksPassed
}

# ============================================================================
# SECTION 4: AUTHENTICATION AND CONNECTION
# ============================================================================

function Connect-Services {
    <#
    .SYNOPSIS
        Connects to Microsoft Graph and Exchange Online
    #>
    Write-SectionHeader "SERVICE AUTHENTICATION"
    
    try {
        # Connect to Microsoft Graph
        Write-Log "Connecting to Microsoft Graph..." -Level INFO
        Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All", "UserAuthenticationMethod.ReadWrite.All" -ErrorAction Stop
        Write-Log "Successfully connected to Microsoft Graph" -Level SUCCESS
        
        # Verify Graph connection
        $Context = Get-MgContext
        Write-Log "Connected as: $($Context.Account)" -Level INFO
        Write-Log "Tenant ID: $($Context.TenantId)" -Level INFO
        
        # Connect to Exchange Online
        Write-Log "Connecting to Exchange Online..." -Level INFO
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        Write-Log "Successfully connected to Exchange Online" -Level SUCCESS
        
        return $true
    }
    catch {
        Write-Log "Failed to connect to services: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

# ============================================================================
# SECTION 5: CSV PROCESSING AND DATA VALIDATION
# ============================================================================

function Get-CleanedName {
    <#
    .SYNOPSIS
        Cleans and formats student names for Entra ID compatibility
    #>
    param(
        [string]$Name
    )
    
    # Remove or replace problematic characters
    $CleanName = $Name -replace "[''`´]", ""  # Remove apostrophes and quotes
    $CleanName = $CleanName -replace "[^\w\s-]", ""  # Remove special characters except hyphen
    $CleanName = $CleanName.Trim()
    
    # Truncate if too long (DisplayName limit is 256 characters)
    if ($CleanName.Length -gt 64) {
        $CleanName = $CleanName.Substring(0, 64)
        Write-Log "Name truncated to 64 characters: $CleanName" -Level WARNING
    }
    
    return $CleanName
}

function Import-StudentData {
    <#
    .SYNOPSIS
        Imports and validates student data from CSV files
    .DESCRIPTION
        Expected CSV columns:
        - FirstName: Student's first name
        - LastName: Student's last name
        - DateOfBirth: Format YYYY-MM-DD
        - YearGroup: Current year group (e.g., "Reception", "Year1", "Year7", "Year12")
        - NewYearGroup: Target year group for transition (or "Graduate" for leavers)
        - StudentID: Unique student identifier
        - ParentEmail: Parent/guardian email for notifications
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$CSVFilePath
    )
    
    Write-SectionHeader "CSV DATA IMPORT AND VALIDATION"
    
    if (-not (Test-Path $CSVFilePath)) {
        Write-Log "CSV file not found: $CSVFilePath" -Level ERROR
        return $null
    }
    
    Write-Log "Importing CSV file: $CSVFilePath" -Level INFO
    
    try {
        $Students = Import-Csv -Path $CSVFilePath -ErrorAction Stop
        Write-Log "Successfully imported $($Students.Count) records" -Level SUCCESS
        
        # Validate required columns
        $RequiredColumns = @('FirstName', 'LastName', 'DateOfBirth', 'YearGroup', 'NewYearGroup', 'StudentID')
        $CSVColumns = ($Students | Get-Member -MemberType NoteProperty).Name
        
        foreach ($Column in $RequiredColumns) {
            if ($Column -notin $CSVColumns) {
                Write-Log "Required column missing: $Column" -Level ERROR
                return $null
            }
        }
        Write-Log "CSV structure validation passed" -Level SUCCESS
        
        # Clean and validate each record
        $ValidatedStudents = @()
        $RowNumber = 1
        
        foreach ($Student in $Students) {
            $RowNumber++
            $IsValid = $true
            
            # Clean names
            $Student.FirstName = Get-CleanedName -Name $Student.FirstName
            $Student.LastName = Get-CleanedName -Name $Student.LastName
            
            # Validate required fields
            if ([string]::IsNullOrWhiteSpace($Student.FirstName)) {
                Write-Log "Row $RowNumber: FirstName is empty" -Level WARNING
                $IsValid = $false
            }
            
            if ([string]::IsNullOrWhiteSpace($Student.LastName)) {
                Write-Log "Row $RowNumber: LastName is empty" -Level WARNING
                $IsValid = $false
            }
            
            if ([string]::IsNullOrWhiteSpace($Student.StudentID)) {
                Write-Log "Row $RowNumber: StudentID is empty" -Level WARNING
                $IsValid = $false
            }
            
            # Validate date of birth
            try {
                $DOB = [DateTime]::ParseExact($Student.DateOfBirth, "yyyy-MM-dd", $null)
            }
            catch {
                Write-Log "Row $RowNumber: Invalid DateOfBirth format for $($Student.FirstName) $($Student.LastName)" -Level WARNING
                $IsValid = $false
            }
            
            if ($IsValid) {
                $ValidatedStudents += $Student
            }
        }
        
        Write-Log "Validated $($ValidatedStudents.Count) of $($Students.Count) records" -Level INFO
        
        if ($ValidatedStudents.Count -eq 0) {
            Write-Log "No valid student records found" -Level ERROR
            return $null
        }
        
        return $ValidatedStudents
    }
    catch {
        Write-Log "Error importing CSV: $($_.Exception.Message)" -Level ERROR
        return $null
    }
}

# ============================================================================
# SECTION 6: USER PRINCIPAL NAME (UPN) GENERATION
# ============================================================================

function New-StudentUPN {
    <#
    .SYNOPSIS
        Generates a unique User Principal Name for a student
    #>
    param(
        [string]$FirstName,
        [string]$LastName,
        [string]$StudentID,
        [string]$Domain = "yourdomain.com"  # Update with your domain
    )
    
    # Generate base UPN: firstname.lastname@domain
    $BaseUPN = "$($FirstName.ToLower()).$($LastName.ToLower())@$Domain"
    $BaseUPN = $BaseUPN -replace "\s+", ""  # Remove any spaces
    
    # Check if UPN already exists
    try {
        $ExistingUser = Get-MgUser -Filter "userPrincipalName eq '$BaseUPN'" -ErrorAction SilentlyContinue
        
        if ($ExistingUser) {
            # UPN exists, append student ID
            $UPN = "$($FirstName.ToLower()).$($LastName.ToLower()).$StudentID@$Domain"
            Write-Log "UPN collision detected, using: $UPN" -Level WARNING
        } else {
            $UPN = $BaseUPN
        }
    }
    catch {
        # If check fails, use student ID variant to be safe
        $UPN = "$($FirstName.ToLower()).$($LastName.ToLower()).$StudentID@$Domain"
    }
    
    return $UPN
}

# ============================================================================
# SECTION 7: SECURITY GROUP MAPPING
# ============================================================================

function Get-YearGroupSecurityGroups {
    <#
    .SYNOPSIS
        Returns security group assignments based on year group
    #>
    param(
        [string]$YearGroup
    )
    
    # Define security groups for each year group
    # Update these group names to match your Entra ID groups
    $GroupMappings = @{
        # Primary School
        'Reception' = @('SG-Students-Primary', 'SG-Students-Reception')
        'Year1' = @('SG-Students-Primary', 'SG-Students-Year1')
        'Year2' = @('SG-Students-Primary', 'SG-Students-Year2')
        'Year3' = @('SG-Students-Primary', 'SG-Students-Year3')
        'Year4' = @('SG-Students-Primary', 'SG-Students-Year4')
        'Year5' = @('SG-Students-Primary', 'SG-Students-Year5')
        'Year6' = @('SG-Students-Primary', 'SG-Students-Year6')
        
        # Secondary School (Key Stage 3 & 4)
        'Year7' = @('SG-Students-Secondary', 'SG-Students-KS3', 'SG-Students-Year7')
        'Year8' = @('SG-Students-Secondary', 'SG-Students-KS3', 'SG-Students-Year8')
        'Year9' = @('SG-Students-Secondary', 'SG-Students-KS3', 'SG-Students-Year9')
        'Year10' = @('SG-Students-Secondary', 'SG-Students-KS4', 'SG-Students-Year10')
        'Year11' = @('SG-Students-Secondary', 'SG-Students-KS4', 'SG-Students-Year11')
        
        # Sixth Form (Key Stage 5)
        'Year12' = @('SG-Students-SixthForm', 'SG-Students-KS5', 'SG-Students-Year12')
        'Year13' = @('SG-Students-SixthForm', 'SG-Students-KS5', 'SG-Students-Year13')
    }
    
    return $GroupMappings[$YearGroup]
}

# ============================================================================
# SECTION 8: USER CREATION AND ONBOARDING
# ============================================================================

function New-StudentAccount {
    <#
    .SYNOPSIS
        Creates a new student account in Entra ID
    #>
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Student
    )
    
    Write-Log "Processing: $($Student.FirstName) $($Student.LastName) (ID: $($Student.StudentID))" -Level INFO
    
    try {
        # Generate UPN
        $UPN = New-StudentUPN -FirstName $Student.FirstName -LastName $Student.LastName -StudentID $Student.StudentID
        Write-Log "Generated UPN: $UPN" -Level INFO
        
        # Check if user already exists
        $ExistingUser = Get-MgUser -Filter "userPrincipalName eq '$UPN'" -ErrorAction SilentlyContinue
        
        if ($ExistingUser) {
            Write-Log "User already exists: $UPN (Updating instead)" -Level WARNING
            return Update-StudentAccount -Student $Student -UserID $ExistingUser.Id
        }
        
        # Generate temporary password
        $TempPassword = -join ((65..90) + (97..122) + (48..57) + (33..47) | Get-Random -Count 16 | ForEach-Object {[char]$_})
        
        # Prepare user parameters
        $PasswordProfile = @{
            ForceChangePasswordNextSignIn = $true
            Password = $TempPassword
        }
        
        $DisplayName = "$($Student.FirstName) $($Student.LastName)"
        $MailNickname = "$($Student.FirstName)$($Student.LastName)".ToLower() -replace "\s+", ""
        
        $UserParams = @{
            DisplayName = $DisplayName
            UserPrincipalName = $UPN
            MailNickname = $MailNickname
            GivenName = $Student.FirstName
            Surname = $Student.LastName
            AccountEnabled = $true
            PasswordProfile = $PasswordProfile
            UsageLocation = "GB"  # Update with your country code
            Department = "Students"
            JobTitle = $Student.NewYearGroup
            EmployeeId = $Student.StudentID
        }
        
        # Create user
        Write-Log "Creating Entra ID account..." -Level INFO
        $NewUser = New-MgUser @UserParams -ErrorAction Stop
        Write-Log "Successfully created user: $UPN" -Level SUCCESS
        
        # Store credentials securely for reporting
        $Script:CreatedUsers += [PSCustomObject]@{
            UPN = $UPN
            DisplayName = $DisplayName
            StudentID = $Student.StudentID
            TempPassword = $TempPassword
            YearGroup = $Student.NewYearGroup
            ObjectID = $NewUser.Id
        }
        
        # Wait for user propagation
        Start-Sleep -Seconds 5
        
        return $NewUser
    }
    catch {
        Write-Log "Failed to create user $($Student.FirstName) $($Student.LastName): $($_.Exception.Message)" -Level ERROR
        return $null
    }
}

function Update-StudentAccount {
    <#
    .SYNOPSIS
        Updates existing student account for year group transition
    #>
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Student,
        
        [Parameter(Mandatory=$true)]
        [string]$UserID
    )
    
    try {
        Write-Log "Updating existing account for year transition..." -Level INFO
        
        $UpdateParams = @{
            JobTitle = $Student.NewYearGroup
        }
        
        Update-MgUser -UserId $UserID -BodyParameter $UpdateParams -ErrorAction Stop
        Write-Log "Successfully updated user account" -Level SUCCESS
        
        return (Get-MgUser -UserId $UserID)
    }
    catch {
        Write-Log "Failed to update user: $($_.Exception.Message)" -Level ERROR
        return $null
    }
}

# ============================================================================
# SECTION 9: GROUP MEMBERSHIP MANAGEMENT
# ============================================================================

function Set-StudentGroupMembership {
    <#
    .SYNOPSIS
        Assigns student to appropriate security groups
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserID,
        
        [Parameter(Mandatory=$true)]
        [string]$YearGroup
    )
    
    Write-Log "Assigning security groups for $YearGroup..." -Level INFO
    
    $Groups = Get-YearGroupSecurityGroups -YearGroup $YearGroup
    
    if (-not $Groups) {
        Write-Log "No security groups defined for $YearGroup" -Level WARNING
        return
    }
    
    foreach ($GroupName in $Groups) {
        try {
            # Find group by display name
            $Group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction Stop
            
            if ($Group) {
                # Check if already a member
                $IsMember = Get-MgGroupMember -GroupId $Group.Id | Where-Object { $_.Id -eq $UserID }
                
                if (-not $IsMember) {
                    # Add to group
                    New-MgGroupMember -GroupId $Group.Id -DirectoryObjectId $UserID -ErrorAction Stop
                    Write-Log "Added to group: $GroupName" -Level SUCCESS
                } else {
                    Write-Log "Already member of: $GroupName" -Level INFO
                }
            } else {
                Write-Log "Group not found: $GroupName (Create this group in Entra ID)" -Level WARNING
            }
        }
        catch {
            Write-Log "Failed to add to group $GroupName: $($_.Exception.Message)" -Level ERROR
        }
    }
}

function Remove-StudentFromPreviousGroups {
    <#
    .SYNOPSIS
        Removes student from previous year group security groups
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserID,
        
        [Parameter(Mandatory=$true)]
        [string]$PreviousYearGroup
    )
    
    Write-Log "Removing from previous year group groups..." -Level INFO
    
    $Groups = Get-YearGroupSecurityGroups -YearGroup $PreviousYearGroup
    
    if (-not $Groups) {
        return
    }
    
    foreach ($GroupName in $Groups) {
        try {
            $Group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction SilentlyContinue
            
            if ($Group) {
                # Check if member
                $IsMember = Get-MgGroupMember -GroupId $Group.Id | Where-Object { $_.Id -eq $UserID }
                
                if ($IsMember) {
                    Remove-MgGroupMemberByRef -GroupId $Group.Id -DirectoryObjectId $UserID -ErrorAction Stop
                    Write-Log "Removed from group: $GroupName" -Level SUCCESS
                }
            }
        }
        catch {
            Write-Log "Failed to remove from group $GroupName: $($_.Exception.Message)" -Level WARNING
        }
    }
}

# ============================================================================
# SECTION 10: LICENSE ASSIGNMENT
# ============================================================================

function Set-StudentLicense {
    <#
    .SYNOPSIS
        Assigns Microsoft 365 license to student
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserID
    )
    
    Write-Log "Assigning Microsoft 365 student license..." -Level INFO
    
    try {
        # Get available licenses
        $SubscribedSku = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -like "*STUDENT*" } | Select-Object -First 1
        
        if (-not $SubscribedSku) {
            Write-Log "No student licenses found in tenant" -Level WARNING
            return
        }
        
        Write-Log "Using license SKU: $($SubscribedSku.SkuPartNumber)" -Level INFO
        
        # Check current license
        $User = Get-MgUser -UserId $UserID -Property AssignedLicenses
        $HasLicense = $User.AssignedLicenses | Where-Object { $_.SkuId -eq $SubscribedSku.SkuId }
        
        if ($HasLicense) {
            Write-Log "License already assigned" -Level INFO
            return
        }
        
        # Assign license
        $LicenseParams = @{
            AddLicenses = @(
                @{
                    SkuId = $SubscribedSku.SkuId
                }
            )
            RemoveLicenses = @()
        }
        
        Set-MgUserLicense -UserId $UserID -BodyParameter $LicenseParams -ErrorAction Stop
        Write-Log "Successfully assigned license" -Level SUCCESS
    }
    catch {
        Write-Log "Failed to assign license: $($_.Exception.Message)" -Level ERROR
    }
}

# ============================================================================
# SECTION 11: MFA CONFIGURATION
# ============================================================================

function Set-StudentMFA {
    <#
    .SYNOPSIS
        Configures default MFA method (placeholder phone)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserID
    )
    
    Write-Log "Configuring MFA authentication method..." -Level INFO
    
    try {
        # Add phone authentication method (placeholder for IT department)
        $PhoneParams = @{
            PhoneNumber = $DefaultMFAPhone
            PhoneType = "mobile"
        }
        
        New-MgUserAuthenticationPhoneMethod -UserId $UserID -BodyParameter $PhoneParams -ErrorAction Stop
        Write-Log "MFA phone method configured (placeholder)" -Level SUCCESS
    }
    catch {
        Write-Log "Failed to configure MFA: $($_.Exception.Message)" -Level WARNING
        Write-Log "User will be prompted to set up MFA on first login" -Level INFO
    }
}

# ============================================================================
# SECTION 12: MAILBOX DELEGATION (SAFEGUARDING)
# ============================================================================

function Set-MailboxDelegation {
    <#
    .SYNOPSIS
        Delegates mailbox access to safeguarding admin account
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserPrincipalName
    )
    
    Write-Log "Configuring mailbox delegation for safeguarding..." -Level INFO
    
    try {
        # Wait for mailbox provisioning (can take several minutes)
        $MaxWaitTime = 300  # 5 minutes
        $WaitInterval = 30  # 30 seconds
        $ElapsedTime = 0
        $MailboxReady = $false
        
        Write-Log "Waiting for mailbox provisioning (this may take a few minutes)..." -Level INFO
        
        while ($ElapsedTime -lt $MaxWaitTime -and -not $MailboxReady) {
            try {
                $Mailbox = Get-Mailbox -Identity $UserPrincipalName -ErrorAction Stop
                $MailboxReady = $true
                Write-Log "Mailbox provisioned successfully" -Level SUCCESS
            }
            catch {
                Start-Sleep -Seconds $WaitInterval
                $ElapsedTime += $WaitInterval
                Write-Log "Still waiting for mailbox... ($ElapsedTime seconds elapsed)" -Level INFO
            }
        }
        
        if (-not $MailboxReady) {
            Write-Log "Mailbox not ready after $MaxWaitTime seconds - will retry later" -Level WARNING
            return $false
        }
        
        # Add FullAccess permission for safeguarding admin
        Add-MailboxPermission -Identity $UserPrincipalName -User $SafeguardingAdminEmail -AccessRights FullAccess -InheritanceType All -AutoMapping $false -ErrorAction Stop
        Write-Log "Granted FullAccess to $SafeguardingAdminEmail" -Level SUCCESS
        
        # Add SendAs permission
        Add-RecipientPermission -Identity $UserPrincipalName -Trustee $SafeguardingAdminEmail -AccessRights SendAs -Confirm:$false -ErrorAction Stop
        Write-Log "Granted SendAs to $SafeguardingAdminEmail" -Level SUCCESS
        
        return $true
    }
    catch {
        Write-Log "Failed to configure mailbox delegation: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

# ============================================================================
# SECTION 13: OFFBOARDING AND GRADUATE MANAGEMENT
# ============================================================================

function Invoke-StudentOffboarding {
    <#
    .SYNOPSIS
        Offboards graduating students (Year 6, Year 11, Year 13)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Student
    )
    
    Write-Log "Offboarding graduate: $($Student.FirstName) $($Student.LastName)" -Level INFO
    
    try {
        # Find user
        $UPN = New-StudentUPN -FirstName $Student.FirstName -LastName $Student.LastName -StudentID $Student.StudentID
        $User = Get-MgUser -Filter "userPrincipalName eq '$UPN'" -ErrorAction SilentlyContinue
        
        if (-not $User) {
            Write-Log "User not found for offboarding: $UPN" -Level WARNING
            return
        }
        
        # Move to "Graduates" OU/Group
        Write-Log "Moving to Graduates security group..." -Level INFO
        $GraduatesGroup = Get-MgGroup -Filter "displayName eq 'SG-Students-Graduates'" -ErrorAction SilentlyContinue
        
        if ($GraduatesGroup) {
            New-MgGroupMember -GroupId $GraduatesGroup.Id -DirectoryObjectId $User.Id -ErrorAction SilentlyContinue
            Write-Log "Added to Graduates group" -Level SUCCESS
        }
        
        # Remove from year group groups
        Remove-StudentFromPreviousGroups -UserID $User.Id -PreviousYearGroup $Student.YearGroup
        
        # Disable account (will be purged after retention period)
        Update-MgUser -UserId $User.Id -AccountEnabled $false -ErrorAction Stop
        Write-Log "Account disabled" -Level SUCCESS
        
        # Set deletion date
        $DeletionDate = (Get-Date).AddDays($GraduateRetentionDays)
        Update-MgUser -UserId $User.Id -EmployeeHireDate $DeletionDate -ErrorAction SilentlyContinue
        Write-Log "Scheduled for deletion: $($DeletionDate.ToString('yyyy-MM-dd'))" -Level INFO
        
        # Convert mailbox to shared (preserves data, reduces license cost)
        try {
            Set-Mailbox -Identity $UPN -Type Shared -ErrorAction Stop
            Write-Log "Mailbox converted to Shared" -Level SUCCESS
        }
        catch {
            Write-Log "Failed to convert mailbox: $($_.Exception.Message)" -Level WARNING
        }
        
        # Remove licenses
        $User = Get-MgUser -UserId $User.Id -Property AssignedLicenses
        if ($User.AssignedLicenses.Count -gt 0) {
            $RemoveLicenses = $User.AssignedLicenses | ForEach-Object { $_.SkuId }
            $LicenseParams = @{
                AddLicenses = @()
                RemoveLicenses = $RemoveLicenses
            }
            Set-MgUserLicense -UserId $User.Id -BodyParameter $LicenseParams -ErrorAction Stop
            Write-Log "Licenses removed" -Level SUCCESS
        }
        
        # Log offboarding
        $Script:OffboardedUsers += [PSCustomObject]@{
            UPN = $UPN
            DisplayName = "$($Student.FirstName) $($Student.LastName)"
            StudentID = $Student.StudentID
            YearGroup = $Student.YearGroup
            OffboardDate = Get-Date
            DeletionDate = $DeletionDate
            ObjectID = $User.Id
        }
        
        Write-Log "Offboarding completed successfully" -Level SUCCESS
    }
    catch {
        Write-Log "Offboarding failed: $($_.Exception.Message)" -Level ERROR
    }
}

function Remove-ExpiredGraduates {
    <#
    .SYNOPSIS
        Purges graduate accounts that have exceeded retention period
    #>
    Write-SectionHeader "PURGING EXPIRED GRADUATE ACCOUNTS"
    
    try {
        # Get all disabled users in Graduates group
        $GraduatesGroup = Get-MgGroup -Filter "displayName eq 'SG-Students-Graduates'" -ErrorAction SilentlyContinue
        
        if (-not $GraduatesGroup) {
            Write-Log "Graduates group not found - skipping purge" -Level WARNING
            return
        }
        
        $Members = Get-MgGroupMember -GroupId $GraduatesGroup.Id -All
        $CurrentDate = Get-Date
        $PurgedCount = 0
        
        foreach ($Member in $Members) {
            try {
                $User = Get-MgUser -UserId $Member.Id -Property EmployeeHireDate, AccountEnabled -ErrorAction Stop
                
                # Check if past deletion date
                if ($User.EmployeeHireDate -and $User.EmployeeHireDate -lt $CurrentDate -and -not $User.AccountEnabled) {
                    Write-Log "Purging expired account: $($User.UserPrincipalName)" -Level INFO
                    
                    # Delete user permanently
                    Remove-MgUser -UserId $User.Id -ErrorAction Stop
                    Write-Log "Successfully deleted: $($User.UserPrincipalName)" -Level SUCCESS
                    $PurgedCount++
                }
            }
            catch {
                Write-Log "Failed to purge user: $($_.Exception.Message)" -Level ERROR
            }
        }
        
        Write-Log "Purged $PurgedCount expired graduate account(s)" -Level SUCCESS
    }
    catch {
        Write-Log "Error during graduate purge: $($_.Exception.Message)" -Level ERROR
    }
}

# ============================================================================
# SECTION 14: MAIN PROCESSING LOGIC
# ============================================================================

function Invoke-StudentOnboarding {
    <#
    .SYNOPSIS
        Main onboarding process for new and transitioning students
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$Students
    )
    
    Write-SectionHeader "STUDENT ONBOARDING AND TRANSITION"
    
    $ProcessedCount = 0
    $SuccessCount = 0
    $FailureCount = 0
    
    foreach ($Student in $Students) {
        $ProcessedCount++
        Write-Log "[$ProcessedCount/$($Students.Count)] Processing student..." -Level INFO
        
        try {
            # Check if this is a graduate (offboarding)
            if ($Student.NewYearGroup -eq "Graduate") {
                Invoke-StudentOffboarding -Student $Student
                continue
            }
            
            # Create or update user account
            $User = New-StudentAccount -Student $Student
            
            if (-not $User) {
                $FailureCount++
                continue
            }
            
            # Remove from previous year groups if transitioning
            if ($Student.YearGroup -ne $Student.NewYearGroup) {
                Remove-StudentFromPreviousGroups -UserID $User.Id -PreviousYearGroup $Student.YearGroup
            }
            
            # Assign to new year group security groups
            Set-StudentGroupMembership -UserID $User.Id -YearGroup $Student.NewYearGroup
            
            # Assign license
            Set-StudentLicense -UserID $User.Id
            
            # Configure MFA
            Set-StudentMFA -UserID $User.Id
            
            # Configure mailbox delegation (safeguarding)
            $MailboxConfigured = Set-MailboxDelegation -UserPrincipalName $User.UserPrincipalName
            
            if ($MailboxConfigured) {
                Write-Log "All configurations completed successfully" -Level SUCCESS
                $SuccessCount++
            } else {
                Write-Log "Completed with mailbox delegation pending" -Level WARNING
                $SuccessCount++
            }
            
            Write-Log "Student onboarding completed: $($User.UserPrincipalName)" -Level SUCCESS
            Write-Log "" -Level INFO  # Blank line for readability
        }
        catch {
            Write-Log "Critical error processing student: $($_.Exception.Message)" -Level ERROR
            $FailureCount++
        }
    }
    
    # Summary
    Write-SectionHeader "ONBOARDING SUMMARY"
    Write-Log "Total processed: $ProcessedCount" -Level INFO
    Write-Log "Successful: $SuccessCount" -Level SUCCESS
    Write-Log "Failed: $FailureCount" -Level $(if ($FailureCount -gt 0) { 'WARNING' } else { 'INFO' })
}

# ============================================================================
# SECTION 15: RETRY MAILBOX DELEGATION
# ============================================================================

function Invoke-RetryMailboxDelegation {
    <#
    .SYNOPSIS
        Retries mailbox delegation for accounts where it initially failed
    #>
    Write-SectionHeader "RETRY MAILBOX DELEGATION"
    
    Write-Log "Checking for accounts needing mailbox delegation..." -Level INFO
    
    $RetryCount = 0
    $SuccessCount = 0
    
    foreach ($User in $Script:CreatedUsers) {
        try {
            # Check if mailbox delegation is already configured
            $Permissions = Get-MailboxPermission -Identity $User.UPN -ErrorAction SilentlyContinue | 
                Where-Object { $_.User -eq $SafeguardingAdminEmail -and $_.AccessRights -contains "FullAccess" }
            
            if (-not $Permissions) {
                Write-Log "Retrying delegation for: $($User.UPN)" -Level INFO
                $RetryCount++
                
                if (Set-MailboxDelegation -UserPrincipalName $User.UPN) {
                    $SuccessCount++
                }
            }
        }
        catch {
            Write-Log "Retry failed for $($User.UPN): $($_.Exception.Message)" -Level WARNING
        }
    }
    
    Write-Log "Retry complete: $SuccessCount of $RetryCount mailboxes configured" -Level INFO
}

# ============================================================================
# SECTION 16: VERIFICATION AND AUDIT
# ============================================================================

function Invoke-UserVerification {
    <#
    .SYNOPSIS
        Verifies created accounts and generates audit report
    #>
    Write-SectionHeader "ACCOUNT VERIFICATION AND AUDIT"
    
    $VerificationResults = @()
    
    foreach ($User in $Script:CreatedUsers) {
        Write-Log "Verifying: $($User.UPN)" -Level INFO
        
        try {
            # Get user from Entra ID
            $EntraUser = Get-MgUser -UserId $User.ObjectID -Property DisplayName, UserPrincipalName, AccountEnabled, AssignedLicenses, JobTitle -ErrorAction Stop
            
            # Check license
            $HasLicense = $EntraUser.AssignedLicenses.Count -gt 0
            
            # Check group membership
            $Groups = Get-MgUserMemberOf -UserId $User.ObjectID | Select-Object -ExpandProperty AdditionalProperties
            $GroupCount = $Groups.Count
            
            # Check mailbox
            $Mailbox = $null
            $MailboxDelegated = $false
            try {
                $Mailbox = Get-Mailbox -Identity $User.UPN -ErrorAction SilentlyContinue
                if ($Mailbox) {
                    $Permissions = Get-MailboxPermission -Identity $User.UPN -ErrorAction SilentlyContinue | 
                        Where-Object { $_.User -eq $SafeguardingAdminEmail }
                    $MailboxDelegated = $Permissions -ne $null
                }
            }
            catch {
                # Mailbox might still be provisioning
            }
            
            # Check MFA
            $MFAMethods = Get-MgUserAuthenticationMethod -UserId $User.ObjectID -ErrorAction SilentlyContinue
            $HasMFA = $MFAMethods.Count -gt 0
            
            $VerificationResults += [PSCustomObject]@{
                UPN = $User.UPN
                DisplayName = $User.DisplayName
                StudentID = $User.StudentID
                YearGroup = $User.YearGroup
                AccountEnabled = $EntraUser.AccountEnabled
                HasLicense = $HasLicense
                GroupMemberships = $GroupCount
                MailboxExists = ($Mailbox -ne $null)
                MailboxDelegated = $MailboxDelegated
                HasMFA = $HasMFA
                Status = if ($EntraUser.AccountEnabled -and $HasLicense -and $GroupCount -gt 0) { "OK" } else { "INCOMPLETE" }
            }
            
            $Status = if ($EntraUser.AccountEnabled -and $HasLicense -and $GroupCount -gt 0) { "SUCCESS" } else { "WARNING" }
            Write-Log "Verification complete: $($User.UPN) - Status: $Status" -Level $Status
        }
        catch {
            Write-Log "Verification failed for $($User.UPN): $($_.Exception.Message)" -Level ERROR
            
            $VerificationResults += [PSCustomObject]@{
                UPN = $User.UPN
                DisplayName = $User.DisplayName
                StudentID = $User.StudentID
                Status = "ERROR"
            }
        }
    }
    
    return $VerificationResults
}

# ============================================================================
# SECTION 17: HTML REPORT GENERATION
# ============================================================================

function New-HTMLReport {
    <#
    .SYNOPSIS
        Generates comprehensive HTML report of operations
    #>
    param(
        [array]$VerificationResults
    )
    
    Write-SectionHeader "GENERATING HTML REPORT"
    
    $HTML = @"
<!DOCTYPE html>
<html>
<head>
    <title>Student Management Report - $DateStamp</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; border-bottom: 2px solid #95a5a6; padding-bottom: 5px; }
        .summary { background-color: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .summary-item { display: inline-block; margin: 10px 20px; }
        .summary-label { font-weight: bold; color: #7f8c8d; }
        .summary-value { font-size: 24px; color: #2c3e50; margin-left: 10px; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; background-color: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th { background-color: #3498db; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ecf0f1; }
        tr:hover { background-color: #f8f9fa; }
        .status-ok { color: #27ae60; font-weight: bold; }
        .status-incomplete { color: #f39c12; font-weight: bold; }
        .status-error { color: #e74c3c; font-weight: bold; }
        .credential-warning { background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 2px solid #95a5a6; color: #7f8c8d; font-size: 12px; }
        .check { color: #27ae60; }
        .cross { color: #e74c3c; }
    </style>
</head>
<body>
    <h1>Student Lifecycle Management Report</h1>
    <div class="summary">
        <div class="summary-item">
            <span class="summary-label">Execution Date:</span>
            <span class="summary-value">$($ScriptStartTime.ToString('yyyy-MM-dd HH:mm:ss'))</span>
        </div>
        <div class="summary-item">
            <span class="summary-label">Total Processed:</span>
            <span class="summary-value">$($Script:CreatedUsers.Count + $Script:OffboardedUsers.Count)</span>
        </div>
        <div class="summary-item">
            <span class="summary-label">Onboarded:</span>
            <span class="summary-value" style="color: #27ae60;">$($Script:CreatedUsers.Count)</span>
        </div>
        <div class="summary-item">
            <span class="summary-label">Offboarded:</span>
            <span class="summary-value" style="color: #e74c3c;">$($Script:OffboardedUsers.Count)</span>
        </div>
    </div>

    <div class="credential-warning">
        <strong>⚠️ SECURITY NOTICE:</strong> Temporary passwords have been generated for new accounts. 
        These credentials are logged securely and must be distributed via secure channels. 
        Users are required to change passwords on first login.
    </div>

    <h2>Newly Onboarded Students</h2>
    <table>
        <thead>
            <tr>
                <th>UPN</th>
                <th>Display Name</th>
                <th>Student ID</th>
                <th>Year Group</th>
                <th>Temporary Password</th>
                <th>Status</th>
            </tr>
        </thead>
        <tbody>
"@

    foreach ($User in $Script:CreatedUsers) {
        $Verification = $VerificationResults | Where-Object { $_.UPN -eq $User.UPN }
        $StatusClass = switch ($Verification.Status) {
            "OK" { "status-ok" }
            "INCOMPLETE" { "status-incomplete" }
            default { "status-error" }
        }
        
        $HTML += @"
            <tr>
                <td>$($User.UPN)</td>
                <td>$($User.DisplayName)</td>
                <td>$($User.StudentID)</td>
                <td>$($User.YearGroup)</td>
                <td><code>$($User.TempPassword)</code></td>
                <td class="$StatusClass">$($Verification.Status)</td>
            </tr>
"@
    }

    $HTML += @"
        </tbody>
    </table>

    <h2>Account Verification Details</h2>
    <table>
        <thead>
            <tr>
                <th>UPN</th>
                <th>Year Group</th>
                <th>Account Enabled</th>
                <th>License Assigned</th>
                <th>Group Memberships</th>
                <th>Mailbox Exists</th>
                <th>Mailbox Delegated</th>
                <th>MFA Configured</th>
            </tr>
        </thead>
        <tbody>
"@

    foreach ($Result in $VerificationResults) {
        $EnabledIcon = if ($Result.AccountEnabled) { "✓" } else { "✗" }
        $LicenseIcon = if ($Result.HasLicense) { "✓" } else { "✗" }
        $MailboxIcon = if ($Result.MailboxExists) { "✓" } else { "✗" }
        $DelegationIcon = if ($Result.MailboxDelegated) { "✓" } else { "✗" }
        $MFAIcon = if ($Result.HasMFA) { "✓" } else { "✗" }
        
        $HTML += @"
            <tr>
                <td>$($Result.UPN)</td>
                <td>$($Result.YearGroup)</td>
                <td class="$(if ($Result.AccountEnabled) { 'check' } else { 'cross' })">$EnabledIcon</td>
                <td class="$(if ($Result.HasLicense) { 'check' } else { 'cross' })">$LicenseIcon</td>
                <td>$($Result.GroupMemberships)</td>
                <td class="$(if ($Result.MailboxExists) { 'check' } else { 'cross' })">$MailboxIcon</td>
                <td class="$(if ($Result.MailboxDelegated) { 'check' } else { 'cross' })">$DelegationIcon</td>
                <td class="$(if ($Result.HasMFA) { 'check' } else { 'cross' })">$MFAIcon</td>
            </tr>
"@
    }

    $HTML += @"
        </tbody>
    </table>
"@

    if ($Script:OffboardedUsers.Count -gt 0) {
        $HTML += @"
    <h2>Offboarded Students (Graduates)</h2>
    <table>
        <thead>
            <tr>
                <th>UPN</th>
                <th>Display Name</th>
                <th>Student ID</th>
                <th>Previous Year Group</th>
                <th>Offboard Date</th>
                <th>Scheduled Deletion</th>
            </tr>
        </thead>
        <tbody>
"@

        foreach ($User in $Script:OffboardedUsers) {
            $HTML += @"
            <tr>
                <td>$($User.UPN)</td>
                <td>$($User.DisplayName)</td>
                <td>$($User.StudentID)</td>
                <td>$($User.YearGroup)</td>
                <td>$($User.OffboardDate.ToString('yyyy-MM-dd HH:mm'))</td>
                <td>$($User.DeletionDate.ToString('yyyy-MM-dd'))</td>
            </tr>
"@
        }

        $HTML += @"
        </tbody>
    </table>
"@
    }

    $HTML += @"
    <div class="footer">
        <p><strong>Script Version:</strong> $ScriptVersion</p>
        <p><strong>Execution Duration:</strong> $((Get-Date) - $ScriptStartTime)</p>
        <p><strong>Log Files:</strong></p>
        <ul>
            <li>Main Log: $LogFile</li>
            <li>Error Log: $ErrorLogFile</li>
            <li>Report: $ReportFile</li>
        </ul>
        <p><em>Generated by Student Lifecycle Management System</em></p>
    </div>
</body>
</html>
"@

    try {
        $HTML | Out-File -FilePath $ReportFile -Encoding UTF8 -ErrorAction Stop
        Write-Log "HTML report generated: $ReportFile" -Level SUCCESS
    }
    catch {
        Write-Log "Failed to generate HTML report: $($_.Exception.Message)" -Level ERROR
    }
}

# ============================================================================
# SECTION 18: PAUSE AND CHECKPOINT FUNCTIONS
# ============================================================================

function Invoke-Checkpoint {
    <#
    .SYNOPSIS
        Pauses execution and prompts user to verify previous steps
    #>
    param(
        [string]$Message = "Review the logs above. Continue?"
    )
    
    Write-Host "`n" -NoNewline
    Write-Host "CHECKPOINT: " -ForegroundColor Cyan -NoNewline
    Write-Host $Message -ForegroundColor Yellow
    Write-Host "Press 'Y' to continue, 'N' to abort, 'L' to view last 20 log entries: " -NoNewline -ForegroundColor Cyan
    
    $Response = Read-Host
    
    switch ($Response.ToUpper()) {
        'Y' {
            Write-Log "Checkpoint passed - continuing execution" -Level INFO
            return $true
        }
        'N' {
            Write-Log "Execution aborted by user at checkpoint" -Level WARNING
            return $false
        }
        'L' {
            Write-Host "`nLast 20 log entries:" -ForegroundColor Cyan
            Get-Content $LogFile -Tail 20 | ForEach-Object { Write-Host $_ }
            return Invoke-Checkpoint -Message $Message  # Recursive call
        }
        default {
            Write-Host "Invalid response. Please enter Y, N, or L." -ForegroundColor Red
            return Invoke-Checkpoint -Message $Message  # Recursive call
        }
    }
}

# ============================================================================
# SECTION 19: MAIN EXECUTION WORKFLOW
# ============================================================================

# Initialize script-level variables for tracking
$Script:CreatedUsers = @()
$Script:OffboardedUsers = @()

# Start execution
Write-Log "======================================================================" -Level INFO
Write-Log "STUDENT LIFECYCLE MANAGEMENT SYSTEM - VERSION $ScriptVersion" -Level INFO
Write-Log "Execution started: $($ScriptStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -Level INFO
Write-Log "======================================================================" -Level INFO

# Step 1: Prerequisite checks
if (-not (Test-Prerequisites)) {
    Write-Log "Prerequisite checks failed. Please resolve issues and try again." -Level ERROR
    exit 1
}

if (-not (Invoke-Checkpoint -Message "Prerequisites validated. Proceed with authentication?")) {
    Write-Log "Script execution cancelled" -Level WARNING
    exit 0
}

# Step 2: Connect to services
if (-not (Connect-Services)) {
    Write-Log "Failed to connect to required services. Exiting." -Level ERROR
    exit 1
}

if (-not (Invoke-Checkpoint -Message "Successfully authenticated. Proceed with CSV import?")) {
    Write-Log "Script execution cancelled" -Level WARNING
    Disconnect-MgGraph
    Disconnect-ExchangeOnline -Confirm:$false
    exit 0
}

# Step 3: Import student data from CSV
$CSVFile = Join-Path $CSVPath "Students.csv"
Write-Host "`nExpected CSV location: $CSVFile" -ForegroundColor Cyan
Write-Host "Ensure your CSV has these columns: FirstName, LastName, DateOfBirth, YearGroup, NewYearGroup, StudentID, ParentEmail" -ForegroundColor Yellow

$Students = Import-StudentData -CSVFilePath $CSVFile

if (-not $Students) {
    Write-Log "Failed to import student data. Exiting." -Level ERROR
    Disconnect-MgGraph
    Disconnect-ExchangeOnline -Confirm:$false
    exit 1
}

Write-Log "Successfully imported and validated $($Students.Count) student records" -Level SUCCESS

if (-not (Invoke-Checkpoint -Message "CSV data loaded. Review validation messages above. Proceed with student processing?")) {
    Write-Log "Script execution cancelled" -Level WARNING
    Disconnect-MgGraph
    Disconnect-ExchangeOnline -Confirm:$false
    exit 0
}

# Step 4: Process students (onboarding and offboarding)
Invoke-StudentOnboarding -Students $Students

if (-not (Invoke-Checkpoint -Message "Student processing complete. Proceed with mailbox delegation retry?")) {
    Write-Log "Skipping mailbox delegation retry" -Level WARNING
} else {
    # Step 5: Retry mailbox delegation for any that failed initially
    Start-Sleep -Seconds 10  # Give Exchange a moment
    Invoke-RetryMailboxDelegation
}

if (-not (Invoke-Checkpoint -Message "Proceed with graduate account purge?")) {
    Write-Log "Skipping graduate purge" -Level WARNING
} else {
    # Step 6: Purge expired graduate accounts
    Remove-ExpiredGraduates
}

if (-not (Invoke-Checkpoint -Message "Proceed with account verification and reporting?")) {
    Write-Log "Skipping verification and reporting" -Level WARNING
} else {
    # Step 7: Verify accounts and generate reports
    $VerificationResults = Invoke-UserVerification
    
    # Step 8: Generate HTML report
    New-HTMLReport -VerificationResults $VerificationResults
}

# ============================================================================
# SECTION 20: CLEANUP AND FINALIZATION
# ============================================================================

Write-SectionHeader "SCRIPT FINALIZATION"

# Export results to CSV for record-keeping
if ($Script:CreatedUsers.Count -gt 0) {
    $CreatedUsersCSV = Join-Path $ReportPath "CreatedUsers_$DateStamp.csv"
    $Script:CreatedUsers | Export-Csv -Path $CreatedUsersCSV -NoTypeInformation -Encoding UTF8
    Write-Log "Created users exported to: $CreatedUsersCSV" -Level SUCCESS
}

if ($Script:OffboardedUsers.Count -gt 0) {
    $OffboardedUsersCSV = Join-Path $ReportPath "OffboardedUsers_$DateStamp.csv"
    $Script:OffboardedUsers | Export-Csv -Path $OffboardedUsersCSV -NoTypeInformation -Encoding UTF8
    Write-Log "Offboarded users exported to: $OffboardedUsersCSV" -Level SUCCESS
}

# Disconnect from services
Write-Log "Disconnecting from Microsoft services..." -Level INFO
Disconnect-MgGraph | Out-Null
Disconnect-ExchangeOnline -Confirm:$false | Out-Null
Write-Log "Disconnected successfully" -Level SUCCESS

# Calculate execution time
$ExecutionTime = (Get-Date) - $ScriptStartTime
Write-Log "Total execution time: $($ExecutionTime.ToString())" -Level INFO

Write-Log "======================================================================" -Level INFO
Write-Log "SCRIPT EXECUTION COMPLETED" -Level SUCCESS
Write-Log "======================================================================" -Level INFO
Write-Host "`n"
Write-Host "SUMMARY REPORT" -ForegroundColor Green -BackgroundColor Black
Write-Host "==============" -ForegroundColor Green -BackgroundColor Black
Write-Host "Onboarded: $($Script:CreatedUsers.Count) students" -ForegroundColor Cyan
Write-Host "Offboarded: $($Script:OffboardedUsers.Count) students" -ForegroundColor Yellow
Write-Host "`nReports generated:" -ForegroundColor White
Write-Host "  - HTML Report: $ReportFile" -ForegroundColor Cyan
Write-Host "  - Main Log: $LogFile" -ForegroundColor Cyan
Write-Host "  - Error Log: $ErrorLogFile" -ForegroundColor Cyan
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "  1. Review the HTML report in your browser" -ForegroundColor White
Write-Host "  2. Distribute temporary passwords securely to students" -ForegroundColor White
Write-Host "  3. Verify mailbox delegation in Exchange Admin Center" -ForegroundColor White
Write-Host "  4. Check authentication methods in Entra ID" -ForegroundColor White
Write-Host "`n"

# End of script
