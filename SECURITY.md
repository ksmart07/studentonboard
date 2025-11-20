# Security Considerations

## Overview

This document outlines the security features, considerations, and best practices for the Student Lifecycle Management System.

## Security Features Implemented

### 1. Email Delegation for Safeguarding

**Purpose**: All student emails are delegated to a designated security admin account for monitoring and safeguarding purposes.

**Implementation**:
- **FullAccess Permission**: Security admin can read all student emails
- **SendAs Permission**: Security admin can send emails on behalf of students if required
- **AutoMapping Disabled**: Student mailboxes don't automatically appear in security admin's Outlook

**Configuration**:
```json
"SecurityAdminEmail": "security.admin@school.edu"
```

**Compliance**:
- Meets UK safeguarding requirements
- Enables real-time monitoring of student communications
- Supports incident investigation and response
- Maintains audit trail of access

### 2. Multi-Factor Authentication (MFA)

**Default Configuration**:
- Students are required to set up MFA on first login
- Placeholder phone number (IT Department) configured
- Students must configure their own authentication methods

**Initial Setup**:
- Script logs MFA requirement
- Conditional access policies should enforce MFA
- Students cannot proceed without MFA setup

**Recommendation**:
```powershell
# Configure via Azure AD Conditional Access:
# - Require MFA for all users
# - Block legacy authentication
# - Require compliant devices for students
```

### 3. Password Security

**Initial Password**:
- Randomly generated: `Welcome[1000-9999]!`
- Meets complexity requirements
- Must be changed on first login
- Never reused or predictable

**Password Policy Enforced**:
- Minimum length: 8 characters
- Complexity: Letters, numbers, special characters
- Force change on first login: ✅
- Never expires: ❌ (follows tenant policy)

### 4. Account Lifecycle Security

**Onboarding**:
- Accounts created with minimum required permissions
- Usage location set correctly for compliance
- Account enabled only when fully configured

**Offboarding**:
- Immediate account disable upon graduation
- License removal to prevent unauthorized access
- 60-day mailbox retention for compliance
- Scheduled deletion after retention period

**Transition**:
- Group memberships updated securely
- Department field updated for access control
- Audit trail maintained

### 5. Access Control

**Principle of Least Privilege**:
- Students assigned only to required groups
- Security groups limit access to appropriate resources
- Year-specific access automatically updated

**Group Structure**:
```
YearGroup-Reception    → Year-specific resources
Class-7A              → Class-specific resources  
Subject-Maths         → Subject-specific resources
Discipline-Science    → Discipline-specific resources
```

### 6. Audit Logging

**Comprehensive Logging**:
- Every operation logged with timestamp
- User creating accounts logged
- Success and failure both logged
- Separate error log for failures

**Log Contents**:
- Who performed action
- What action was performed
- When action occurred
- Result of action (success/failure)
- Error details if failed

**Log Retention**:
- Logs stored in `./Logs/` directory
- Timestamped filenames for version control
- Recommend 7-year retention for compliance
- Regular backup to secure location

### 7. Data Protection

**Personal Information Handling**:
- CSV files should be encrypted at rest
- Secure transmission of CSV files
- Limited access to CSV files
- Automatic sanitization of names

**GDPR Compliance**:
- 60-day retention for graduated students
- Proper deletion after retention
- Audit trail for data access
- Right to access implemented via reports

### 8. Script Security

**Code Security**:
- No hardcoded credentials
- Configuration in separate file
- Test mode prevents accidental changes
- Confirmation prompts for destructive actions

**Execution Security**:
- Requires PowerShell 5.1+ (security features)
- Requires appropriate admin permissions
- Connects with least-privilege scopes
- Disconnects after operations

## Security Best Practices

### Before Running Script

1. **Verify Configuration**:
   ```powershell
   Get-Content .\config.json | ConvertFrom-Json
   # Verify SecurityAdminEmail is correct
   # Verify Domain is correct
   ```

2. **Check Permissions**:
   - Run as user with appropriate admin rights
   - Global Admin or User Admin required
   - Exchange Admin for mailbox delegation
   - License Admin for license assignment

3. **Secure CSV Files**:
   ```powershell
   # Encrypt CSV before storage
   # Use secure file share for CSV files
   # Limit access to CSV directory
   # Delete CSV after processing
   ```

4. **Test Mode First**:
   ```powershell
   # ALWAYS test first
   .\Student-Onboarding-Offboarding.ps1 -Operation Onboard -CSVFile "file.csv" -TestMode
   ```

### During Execution

1. **Monitor Logs**:
   ```powershell
   # In separate window, tail the log
   Get-Content .\Logs\StudentLifecycle-*.log -Wait
   ```

2. **Verify Operations**:
   - Check Azure AD portal periodically
   - Verify group assignments
   - Check license assignments
   - Verify email delegation

3. **Handle Errors Immediately**:
   - Review error log
   - Fix issues before continuing
   - Document resolutions

### After Execution

1. **Verify All Accounts**:
   - Run Report operation
   - Manually check sample accounts
   - Test student login (test account)
   - Verify MFA prompt

2. **Secure Logs**:
   ```powershell
   # Archive logs to secure location
   # Set appropriate permissions
   # Implement retention policy
   ```

3. **Clean Up**:
   ```powershell
   # Securely delete CSV files
   # Clear command history if contains sensitive data
   # Disconnect from services
   ```

## Threat Mitigation

### Threat: Unauthorized Access to Student Accounts

**Mitigation**:
- MFA required for all accounts
- Password complexity enforced
- Account lockout policies
- Conditional access policies

### Threat: Compromised Security Admin Account

**Mitigation**:
- Security admin requires MFA
- Privileged Identity Management (PIM)
- Regular access reviews
- Alert on unusual access patterns

### Threat: Data Breach via CSV Files

**Mitigation**:
- Encrypt CSV files at rest
- Secure file transmission
- Limited access to CSV files
- Delete CSV after processing
- Audit CSV access

### Threat: Script Misuse or Errors

**Mitigation**:
- Test mode prevents accidents
- Confirmation prompts
- Comprehensive logging
- Role-based access to script
- Code review before changes

### Threat: Insider Threat

**Mitigation**:
- Audit all operations
- Require multiple approvals for bulk operations
- Regular access reviews
- Monitor security admin account usage
- Implement separation of duties

### Threat: Expired Account Retention

**Mitigation**:
- Automatic account disable on graduation
- 60-day retention policy
- Scheduled deletion process
- Regular cleanup audits

## Compliance Considerations

### UK Schools Compliance

**Keeping Children Safe in Education (KCSIE)**:
- ✅ Email monitoring capability
- ✅ Safeguarding admin oversight
- ✅ Audit trail for investigations
- ✅ Immediate response capability

**Data Protection Act 2018 / UK GDPR**:
- ✅ Lawful basis: Public task (education)
- ✅ Data minimization: Only required fields
- ✅ Storage limitation: 60-day retention
- ✅ Integrity and confidentiality: Encryption, access control
- ✅ Accountability: Comprehensive logging

### Microsoft 365 Compliance

**Compliance Manager**:
- Regular assessment required
- Implement recommended controls
- Document compliance status

**Retention Policies**:
```powershell
# Recommended M365 retention policies:
# - Student emails: 7 years
# - Student files: 7 years  
# - Audit logs: 7 years
```

## Incident Response

### Security Incident Detected

1. **Immediate Actions**:
   ```powershell
   # Disable affected account
   Update-MgUser -UserId <userId> -AccountEnabled $false
   
   # Reset password
   # Remove from sensitive groups
   # Notify security team
   ```

2. **Investigation**:
   - Review audit logs
   - Check security admin access logs
   - Review email delegation logs
   - Document findings

3. **Remediation**:
   - Fix vulnerability
   - Update procedures
   - Notify affected parties
   - Update script if needed

### Data Breach Response

1. **Contain**:
   - Disable affected accounts
   - Revoke sessions
   - Remove external sharing

2. **Assess**:
   - Identify compromised data
   - Determine scope
   - Check regulatory requirements

3. **Notify**:
   - ICO (within 72 hours if required)
   - Affected individuals
   - Senior leadership

4. **Remediate**:
   - Fix security gap
   - Update procedures
   - Additional monitoring

## Security Checklist

### Configuration Security
- [ ] config.json permissions restricted
- [ ] Security admin email verified
- [ ] IT department phone number updated
- [ ] Domain name correct
- [ ] No hardcoded credentials

### CSV File Security
- [ ] CSV files encrypted at rest
- [ ] Secure transmission method
- [ ] Access restricted to authorized personnel
- [ ] Deleted after processing
- [ ] Backed up securely

### Account Security
- [ ] MFA enforced for all accounts
- [ ] Password policy configured
- [ ] Conditional access policies enabled
- [ ] Account lockout policy set
- [ ] Legacy authentication blocked

### Monitoring & Logging
- [ ] Audit logging enabled in M365
- [ ] Script logs reviewed regularly
- [ ] Security admin access monitored
- [ ] Alerts configured for unusual activity
- [ ] Logs backed up and retained

### Access Control
- [ ] Principle of least privilege applied
- [ ] Security groups properly configured
- [ ] Regular access reviews scheduled
- [ ] Separation of duties implemented
- [ ] Emergency access accounts configured

### Compliance
- [ ] GDPR requirements met
- [ ] KCSIE requirements met
- [ ] Retention policies configured
- [ ] Privacy notices updated
- [ ] Data protection impact assessment completed

## Recommendations

### Immediate Improvements

1. **Implement Azure AD Privileged Identity Management (PIM)**:
   - Just-in-time admin access
   - Time-limited permissions
   - Approval workflows

2. **Configure Conditional Access**:
   ```
   Policy: Require MFA for All Users
   - Users: All students
   - Conditions: All cloud apps
   - Grant: Require MFA
   ```

3. **Enable Azure AD Identity Protection**:
   - Risk-based conditional access
   - Automated response to threats
   - User risk remediation

4. **Implement Microsoft Defender for Identity**:
   - Monitor for suspicious activity
   - Alert on compromised accounts
   - Investigate security incidents

### Long-term Enhancements

1. **Automate with Azure Automation**:
   - Schedule regular operations
   - Reduce manual execution
   - Improve consistency

2. **Integrate with SIEM**:
   - Send logs to security operations
   - Correlate with other events
   - Automated alerting

3. **Implement Self-Service Password Reset**:
   - Reduce IT support burden
   - Improve security (less help desk resets)
   - Better user experience

4. **Regular Security Audits**:
   - Quarterly review of accounts
   - Monthly review of security groups
   - Weekly review of security admin access
   - Daily monitoring of alerts

## Support Contacts

**Security Issues**:
- Report immediately to security admin
- Email: security.admin@school.edu
- Phone: [IT Department]

**Data Protection Officer**:
- For GDPR/compliance questions
- Email: dpo@school.edu

**Microsoft Support**:
- For platform security issues
- Premier support recommended

## Conclusion

Security is paramount when managing student accounts and data. This system implements multiple layers of security:

1. **Prevention**: MFA, strong passwords, access control
2. **Detection**: Comprehensive logging, monitoring
3. **Response**: Email delegation, incident procedures
4. **Recovery**: Backups, retention policies, audit trails

Always follow the principle: **Test thoroughly, act cautiously, monitor continuously**.

---

**Last Updated**: 2025-11-20  
**Version**: 1.0  
**Review Schedule**: Quarterly
