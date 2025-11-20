# Changelog

All notable changes to the Student Lifecycle Management System will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-20

### Added

#### Core Functionality
- Complete PowerShell script for student lifecycle management (`Student-Onboarding-Offboarding.ps1`)
- Support for five main operations:
  - `CheckPrerequisites`: Verify required modules and environment
  - `Onboard`: Create new student accounts
  - `Offboard`: Disable graduating students with retention
  - `Transition`: Move students to next year group
  - `Report`: Generate comprehensive HTML/CSV reports

#### Student Onboarding
- CSV file import and validation
- Name sanitization handling:
  - Apostrophes (O'Connor → oconnor for usernames)
  - Special characters removal
  - Long name truncation (max 20 characters)
  - Display name preservation with original formatting
- Automated username generation (firstname.lastname format)
- Random initial password generation with complexity
- Microsoft Entra ID (Azure AD) user creation
- Security group assignments:
  - Year group (e.g., YearGroup-Reception)
  - Class group (e.g., Class-7A)
  - Subject groups (e.g., Subject-Maths, Subject-English)
- Microsoft 365 license assignment
- Email delegation to security admin for safeguarding:
  - FullAccess permission
  - SendAs permission
  - AutoMapping disabled
- MFA setup requirements:
  - Force password change on first login
  - Default IT department contact phone
- Batch processing support
- Year group filtering option

#### Year Group Transitions
- Complete year progression map:
  - Reception → Year 1 → ... → Year 6 → Graduated
  - Year 7 → Year 8 → ... → Year 11 → Graduated or Year 12
  - Year 12 → Year 13 → Graduated
- Automatic department field updates
- Security group membership updates
- Archive group assignment for graduates
- Bulk transition capability

#### Student Offboarding
- Graduating student identification (Year 6, 11, 13)
- 60-day retention policy implementation
- Account disabling process
- License removal automation
- Archive group management
- Mailbox retention for compliance

#### Logging and Auditing
- Comprehensive logging system:
  - Main operation log
  - Error-only log
  - Timestamped log files
- Four log levels: INFO, WARNING, ERROR, SUCCESS
- Section-based logging for easy troubleshooting
- Log file location: `./Logs/`

#### Reporting
- HTML report generation with:
  - Summary statistics
  - Student account listing
  - Year group distribution
  - Status indicators (Active/Disabled)
  - License status
- CSV export for data analysis
- Report file location: `./Reports/`
- Automatic browser opening for HTML reports

#### Safety Features
- Test mode (`-TestMode`) for safe operation simulation
- Confirmation prompts before bulk operations
- Comprehensive error handling
- Step-by-step validation
- Rollback information in logs

#### Configuration
- JSON-based configuration file (`config.json`):
  - School settings (name, domain, security admin)
  - Year group definitions
  - Retention policies
  - Security group naming conventions
  - License preferences
  - Logging preferences

#### Documentation
- **README.md**: Quick start guide and overview
- **USER-GUIDE.md**: Complete documentation (15,000+ words)
  - Installation instructions
  - Configuration guide
  - Usage examples
  - CSV format specifications
  - Operation details
  - Security considerations
  - Troubleshooting guide
  - Best practices
  - Annual cycle planning
- **QUICK-REFERENCE.md**: Daily use reference
  - Common commands
  - Quick examples
  - One-line commands
  - Parameter cheat sheet
- **TESTING-GUIDE.md**: Comprehensive testing procedures
  - Test scenarios
  - Validation checklists
  - Performance testing
  - Sandbox testing guide
- **SECURITY.md**: Security documentation
  - Security features explained
  - Threat mitigation
  - Compliance considerations
  - Incident response procedures
  - Security checklist

#### Sample Files
- **Sample-NewStudents-Reception.csv**: Reception intake template
- **Sample-NewStudents-Year7.csv**: Year 7 intake template
- **Sample-NewStudents-Year12.csv**: Year 12 intake template (internal + external)
- **Sample-AllStudents-Transition.csv**: Year transition template

#### Development Files
- **.gitignore**: Excludes logs, reports, and sensitive data
- **LICENSE**: MIT License
- **CHANGELOG.md**: This file

### Features Highlight

#### Safeguarding
- Real-time email monitoring capability through security admin delegation
- Full compliance with UK Keeping Children Safe in Education (KCSIE) requirements
- Audit trail for all operations
- Incident investigation support

#### Compliance
- GDPR/UK Data Protection Act 2018 compliant
- 60-day retention for graduated students
- Comprehensive audit logging
- Data minimization principles
- Right to access via reporting

#### Multi-Factor Authentication
- Enforced MFA setup on first login
- Placeholder IT department contact
- Student-owned authentication methods
- Conditional access policy support

#### User Experience
- Clear console output with color coding
- Progress indicators
- Confirmation prompts for safety
- Detailed error messages
- Professional HTML reports

#### Performance
- Batch processing support
- Efficient Graph API usage
- 2-second delay between operations for propagation
- Suitable for 200+ student batches

### Technical Details

#### Requirements
- PowerShell 5.1 or higher
- Microsoft.Graph PowerShell module
- ExchangeOnlineManagement PowerShell module
- Appropriate admin permissions:
  - Global Admin or User Admin (Entra ID)
  - Exchange Admin (mailbox delegation)
  - License Admin (license assignment)

#### Architecture
- Modular function-based design
- 16 major sections:
  1. Initialization and Configuration
  2. Logging Functions
  3. Name Sanitization and Validation
  4. Module Prerequisites Check
  5. CSV File Processing
  6. Entra ID User Creation
  7. Security Group Management
  8. License Assignment
  9. Email Delegation
  10. MFA and Authentication Setup
  11. Student Onboarding Orchestration
  12. Year Group Transitions
  13. Student Offboarding
  14. Reporting
  15. Main Execution
  16. Cleanup and Finalization

#### Error Handling
- Try-catch blocks for all external operations
- Graceful degradation on non-critical failures
- Detailed error logging
- Error isolation (one failure doesn't stop batch)

#### Security
- No hardcoded credentials
- Configuration in separate file
- Secure credential handling via Microsoft.Graph
- Least-privilege principle
- Test mode prevents accidents

### Known Limitations

1. **Authentication Phone Setup**: Setting default authentication phone via Graph API requires additional permissions and may need Azure AD portal configuration
2. **Large Batches**: Very large batches (500+) may take significant time and should be split
3. **Network Dependencies**: Requires stable internet connection for Graph API calls
4. **License SKU Detection**: Auto-detection of student license SKU may not work in all tenants
5. **Graduated Deletion**: Automatic deletion after 60 days requires separate scheduling (not implemented in v1.0)

### Future Considerations

Items for potential future versions:
- GUI interface option (mentioned in requirements but non-GUI prioritized)
- Automated scheduling via Azure Automation
- Integration with school information systems
- Advanced reporting with charts and graphs
- Email notification system
- Graduated student automatic deletion scheduler
- Parent portal integration
- Bulk password reset capability
- Group membership templates
- Custom license assignment rules
- Azure AD B2B collaboration for external students
- Integration with Microsoft Teams class creation
- OneNote class notebook creation
- SharePoint site provisioning for classes

### Notes

- **Design Philosophy**: Prioritized non-GUI PowerShell script with comprehensive annotations as per requirements
- **Professional Standards**: Formal, professional approach with extensive documentation
- **Safety First**: Multiple safety features including test mode, confirmations, and logging
- **Compliance Focused**: Built with UK educational safeguarding and GDPR requirements in mind
- **Production Ready**: Includes all features for real-world deployment

### Credits

- Developed for educational institutions managing student lifecycles
- Supports UK primary schools, secondary schools, and 6th form colleges
- Implements Microsoft best practices for Entra ID and M365 management

---

## Release Notes v1.0.0

This initial release provides a complete, production-ready solution for school administrators to manage student onboarding, year group transitions, and offboarding in Microsoft 365 environments.

### Highlights

✨ **Complete Lifecycle Management**: Handles students from Reception through Year 13  
🔒 **Safeguarding Built-in**: Email delegation for monitoring and compliance  
📊 **Professional Reporting**: HTML and CSV reports for auditing  
🧪 **Safe Testing**: Test mode simulates all operations  
📖 **Comprehensive Documentation**: Over 30,000 words of guides and references  
🎓 **Education-Focused**: Designed specifically for UK schools  

### Getting Started

```powershell
# 1. Install prerequisites
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser

# 2. Verify installation
.\Student-Onboarding-Offboarding.ps1 -Operation CheckPrerequisites

# 3. Configure your school
# Edit config.json with your settings

# 4. Test with sample data
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Sample-NewStudents-Reception.csv" -TestMode

# 5. Run in production
.\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile ".\Students.csv"
```

### Upgrade Path

This is the initial release. Future versions will maintain backward compatibility where possible.

---

[1.0.0]: https://github.com/ksmart07/studentonboard/releases/tag/v1.0.0
