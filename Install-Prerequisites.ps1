<#
.SYNOPSIS
    Installation script for Student Lifecycle Management System prerequisites.

.DESCRIPTION
    This script installs the required PowerShell modules and verifies the environment
    is ready to run the Student Lifecycle Management System.

.PARAMETER SkipModuleInstall
    Skip the installation of PowerShell modules (useful if already installed).

.PARAMETER Scope
    Installation scope for modules: CurrentUser or AllUsers (requires admin).
    Default: CurrentUser

.EXAMPLE
    .\Install-Prerequisites.ps1

.EXAMPLE
    .\Install-Prerequisites.ps1 -Scope AllUsers

.EXAMPLE
    .\Install-Prerequisites.ps1 -SkipModuleInstall

.NOTES
    Author: School IT Administrator
    Version: 1.0
    Requires: PowerShell 5.1 or higher
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$SkipModuleInstall,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("CurrentUser", "AllUsers")]
    [string]$Scope = "CurrentUser"
)

#Requires -Version 5.1

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Student Lifecycle Management System" -ForegroundColor Cyan
Write-Host "Prerequisites Installation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator (required for AllUsers scope)
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($Scope -eq "AllUsers" -and -not $IsAdmin) {
    Write-Host "ERROR: AllUsers scope requires running PowerShell as Administrator" -ForegroundColor Red
    Write-Host "Please restart PowerShell as Administrator or use -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

# Step 1: Check PowerShell version
Write-Host "[1/5] Checking PowerShell version..." -ForegroundColor Yellow
$PSVersion = $PSVersionTable.PSVersion
Write-Host "      Current version: $($PSVersion.Major).$($PSVersion.Minor)" -ForegroundColor White

if ($PSVersion.Major -lt 5) {
    Write-Host "      ERROR: PowerShell 5.1 or higher is required" -ForegroundColor Red
    Write-Host "      Please upgrade PowerShell: https://aka.ms/powershell" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "      ✓ PowerShell version OK" -ForegroundColor Green
}

# Step 2: Check/Set Execution Policy
Write-Host ""
Write-Host "[2/5] Checking execution policy..." -ForegroundColor Yellow
$ExecutionPolicy = Get-ExecutionPolicy -Scope CurrentUser

if ($ExecutionPolicy -eq "Restricted" -or $ExecutionPolicy -eq "Undefined") {
    Write-Host "      Current policy: $ExecutionPolicy (scripts cannot run)" -ForegroundColor Yellow
    Write-Host "      Setting execution policy to RemoteSigned for CurrentUser..." -ForegroundColor Yellow
    
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host "      ✓ Execution policy updated" -ForegroundColor Green
    }
    catch {
        Write-Host "      ERROR: Failed to set execution policy: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "      Current policy: $ExecutionPolicy" -ForegroundColor White
    Write-Host "      ✓ Execution policy OK" -ForegroundColor Green
}

# Step 3: Check/Install PowerShellGet
Write-Host ""
Write-Host "[3/5] Checking PowerShellGet module..." -ForegroundColor Yellow
$PowerShellGet = Get-Module -ListAvailable -Name PowerShellGet | Sort-Object Version -Descending | Select-Object -First 1

if ($PowerShellGet) {
    Write-Host "      Version: $($PowerShellGet.Version)" -ForegroundColor White
    
    if ($PowerShellGet.Version -lt [Version]"2.0.0") {
        Write-Host "      Updating PowerShellGet to latest version..." -ForegroundColor Yellow
        try {
            Install-Module -Name PowerShellGet -Force -AllowClobber -Scope $Scope
            Write-Host "      ✓ PowerShellGet updated" -ForegroundColor Green
        }
        catch {
            Write-Host "      WARNING: Failed to update PowerShellGet: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "      Continuing with existing version..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "      ✓ PowerShellGet OK" -ForegroundColor Green
    }
} else {
    Write-Host "      PowerShellGet not found, installing..." -ForegroundColor Yellow
    try {
        Install-Module -Name PowerShellGet -Force -AllowClobber -Scope $Scope
        Write-Host "      ✓ PowerShellGet installed" -ForegroundColor Green
    }
    catch {
        Write-Host "      ERROR: Failed to install PowerShellGet: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

if (-not $SkipModuleInstall) {
    # Step 4: Install Microsoft.Graph module
    Write-Host ""
    Write-Host "[4/5] Installing Microsoft Graph PowerShell module..." -ForegroundColor Yellow
    
    $GraphModule = Get-Module -ListAvailable -Name Microsoft.Graph.Users | Sort-Object Version -Descending | Select-Object -First 1
    
    if ($GraphModule) {
        Write-Host "      Microsoft.Graph already installed (version $($GraphModule.Version))" -ForegroundColor White
        Write-Host "      Checking for updates..." -ForegroundColor Yellow
        
        try {
            $LatestVersion = Find-Module -Name Microsoft.Graph | Select-Object -ExpandProperty Version
            if ($GraphModule.Version -lt $LatestVersion) {
                Write-Host "      Newer version available ($LatestVersion), updating..." -ForegroundColor Yellow
                Update-Module -Name Microsoft.Graph -Force -Scope $Scope
                Write-Host "      ✓ Microsoft.Graph updated" -ForegroundColor Green
            } else {
                Write-Host "      ✓ Microsoft.Graph is up to date" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "      WARNING: Could not check for updates: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "      ✓ Continuing with installed version" -ForegroundColor Green
        }
    } else {
        Write-Host "      Installing Microsoft.Graph (this may take several minutes)..." -ForegroundColor Yellow
        try {
            Install-Module -Name Microsoft.Graph -Scope $Scope -Force -AllowClobber
            Write-Host "      ✓ Microsoft.Graph installed successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "      ERROR: Failed to install Microsoft.Graph: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
    
    # Step 5: Install ExchangeOnlineManagement module
    Write-Host ""
    Write-Host "[5/5] Installing Exchange Online Management module..." -ForegroundColor Yellow
    
    $ExchangeModule = Get-Module -ListAvailable -Name ExchangeOnlineManagement | Sort-Object Version -Descending | Select-Object -First 1
    
    if ($ExchangeModule) {
        Write-Host "      ExchangeOnlineManagement already installed (version $($ExchangeModule.Version))" -ForegroundColor White
        Write-Host "      Checking for updates..." -ForegroundColor Yellow
        
        try {
            $LatestVersion = Find-Module -Name ExchangeOnlineManagement | Select-Object -ExpandProperty Version
            if ($ExchangeModule.Version -lt $LatestVersion) {
                Write-Host "      Newer version available ($LatestVersion), updating..." -ForegroundColor Yellow
                Update-Module -Name ExchangeOnlineManagement -Force -Scope $Scope
                Write-Host "      ✓ ExchangeOnlineManagement updated" -ForegroundColor Green
            } else {
                Write-Host "      ✓ ExchangeOnlineManagement is up to date" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "      WARNING: Could not check for updates: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "      ✓ Continuing with installed version" -ForegroundColor Green
        }
    } else {
        Write-Host "      Installing ExchangeOnlineManagement..." -ForegroundColor Yellow
        try {
            Install-Module -Name ExchangeOnlineManagement -Scope $Scope -Force -AllowClobber
            Write-Host "      ✓ ExchangeOnlineManagement installed successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "      ERROR: Failed to install ExchangeOnlineManagement: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
} else {
    Write-Host ""
    Write-Host "[4/5] Skipping module installation (as requested)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "[5/5] Skipping module installation (as requested)" -ForegroundColor Yellow
}

# Final verification
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Running final verification..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$AllGood = $true

# Check Microsoft.Graph
Write-Host "Checking Microsoft.Graph.Users..." -ForegroundColor Yellow
$GraphCheck = Get-Module -ListAvailable -Name Microsoft.Graph.Users
if ($GraphCheck) {
    Write-Host "  ✓ Microsoft.Graph.Users found (version $($GraphCheck[0].Version))" -ForegroundColor Green
} else {
    Write-Host "  ✗ Microsoft.Graph.Users not found" -ForegroundColor Red
    $AllGood = $false
}

# Check ExchangeOnlineManagement
Write-Host "Checking ExchangeOnlineManagement..." -ForegroundColor Yellow
$ExchangeCheck = Get-Module -ListAvailable -Name ExchangeOnlineManagement
if ($ExchangeCheck) {
    Write-Host "  ✓ ExchangeOnlineManagement found (version $($ExchangeCheck[0].Version))" -ForegroundColor Green
} else {
    Write-Host "  ✗ ExchangeOnlineManagement not found" -ForegroundColor Red
    $AllGood = $false
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if ($AllGood) {
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Edit config.json with your school's settings" -ForegroundColor White
    Write-Host "2. Prepare your CSV file with student data" -ForegroundColor White
    Write-Host "3. Test with: .\Student-Onboarding-Offboarding.ps1 -Operation CheckPrerequisites" -ForegroundColor White
    Write-Host "4. Run operations in test mode first: -TestMode" -ForegroundColor White
    Write-Host ""
    Write-Host "For more information, see USER-GUIDE.md" -ForegroundColor Cyan
} else {
    Write-Host "Installation completed with errors!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please review the errors above and try again." -ForegroundColor Yellow
    Write-Host "You may need to:" -ForegroundColor Yellow
    Write-Host "- Run PowerShell as Administrator (for AllUsers scope)" -ForegroundColor White
    Write-Host "- Check your internet connection" -ForegroundColor White
    Write-Host "- Manually install modules with: Install-Module <ModuleName>" -ForegroundColor White
    exit 1
}

Write-Host ""
