# Support Runbook

## Overview
This document outlines standard procedures for handling customer support requests for Chrome Tab Manager (TabPilot).

## Support Channels
- Primary: Email support@tabpilot.app
- Secondary: Website contact form
- Tertiary: Twitter @TabPilotApp (for general inquiries only)
- Response Time Goal: Within 24 hours on business days

## Common Issue Categories

### 1. Purchase & Licensing Issues
#### Lost Purchase Recovery
**Trigger**: User claims they purchased but app shows unlicensed
**Verification Steps**:
1. Ask for purchase email address
2. Check payment processor records (Dodo Payments) for email
3. If found: 
   - Guide user to enter email in Preferences → Account
   - Or have them click "Verify License" in Preferences
   - Explain cache may take up to 7 days to refresh
4. If not found:
   - Ask for alternative emails they might have used
   - Check for typos in email
   - If still not found: Escalate to billing investigation

#### Refund Requests
**Trigger**: User requests refund within refund period
**Procedure**:
1. Verify purchase via email in payment processor
2. Check if within refund window (30 days from purchase)
3. If eligible:
   - Process refund via Dodo Payments dashboard
   - Send confirmation email with refund ID
   - Inform user app will revert to free mode
   - Provide link to reinstall free version if needed
4. If ineligible:
   - Explain refund policy politely
   - Offer alternatives (technical support, feature explanation)

#### License Verification Failures
**Trigger**: App shows unlicensed despite purchase
**Troubleshooting Steps**:
1. Have user check network connection
2. Guide to Preferences → License → "Verify Now"
3. If fails, ask them to:
   - Confirm they're using the purchase email
   - Check for typos/case sensitivity
   - Try license key if provided in purchase email
4. If still failing:
   - Check payment processor for transaction status
   - Look for pending/fraud flags
   - Contact payment provider if needed
5. Resolution:
   - If verified: App should unlock immediately
   - If payment issue: Refund or retry payment
   - If system issue: Escalate to engineering

### 2. Technical Issues
#### Installation Problems
**Trigger**: App won't install or launch
**Common Causes & Fixes**:
- **Gatekeeper blocking**: 
  - Instructions: Right-click app → Open → Confirm
  - Or: System Settings → Privacy & Security → Allow Anyway
- **Corrupted download**:
  - Have user verify SHA-256 checksum
  - Redownload from official site
- **Incompatible macOS version**:
   - Check requirements (macOS 14 Sonoma or later)
   - Suggest updating OS or using older compatible version
- **Insufficient permissions**:
  - Ensure app is in /Applications folder
  - Not running from disk image or Downloads folder

#### Update Failures
**Trigger**: Sparkle update fails or won't install
**Troubleshooting**:
1. Check network connectivity
2. Verify update signatures (if technically inclined)
3. Clear Sparkle cache: 
   - Delete `~/Library/Application Support/org.sparkle-project.TabPilot/`
4. Try manual download from website
5. Check if antivirus/firewall blocking
6. As last resort: Download fresh DMG from website

#### Chrome Interaction Issues
**Trigger**: App not detecting Chrome tabs or failing to close them
**Common Causes**:
- **Chrome not running**: Obvious but often overlooked
- **Chrome profile issues**:
  - TabPilot automatically scans ALL Chrome profiles (Default, Work, Personal, etc.)
  - Each window is tagged with its profile name in the sidebar
  - Use the profile filter in the Windows section to focus on one profile
  - If tabs from a specific profile aren't appearing, check that Chrome windows for that profile are open
- **Accessibility permissions**:
  - Guide to System Settings → Privacy & Security → Accessibility
  - Ensure TabPilot is checked
- **Chrome version incompatibility**:
  - Check supported Chrome versions
  - Suggest updating Chrome
- **Multiple Chrome instances**:
  - User may have Chrome helper processes running
  - Suggest restarting computer

#### False Positives/Negatives
**Trigger**: App misses obvious duplicates or flags non-duplicates
**Investigation**:
1. Ask for specific examples
2. Check URL normalization settings:
   - Preferences → Duplicates → Ignore tracking parameters
   - Preferences → Duplicates → Strip query parameters
3. Test with sample URLs provided by user
4. If bug confirmed: Create ticket for engineering
5. If expected behavior: Explain matching logic

### 3. Usage Questions
#### How It Works
**Standard Explanation**:
- TabPilot scans all open Chrome windows
- Identifies tabs with identical URLs (after normalization)
- Shows groups of duplicate tabs
- Allows user to close extras while keeping one
- Uses smart selection (oldest/newest based on preference)

#### Best Practices
**For Different User Types**:
- **Casual Users**: 
  - Run weekly when Chrome feels slow
  - Use "Clean All Duplicates" for simplicity
  - Set keep preference to "Oldest" (usually what they want)
- **Researchers/Students**:
  - Use review plan to keep specific versions
  - Consider protecting research domains temporarily
  - Export tab list before major cleanup for reference
- **Developers**:
  - Use smart select to keep newest documentation
  - Protect localhost/dev domains
  - Use filters to isolate specific work contexts
- **Power Users**:
  - Leverage search/filter for targeted cleanup
  - Use selection tools for bulk operations
  - Consider enabling auto-cleanup (Pro feature)

#### Feature Questions
**Common Inquiries**:
- **"Does it work with multiple Chrome profiles?"**
  - Yes. TabPilot scans all Chrome profiles simultaneously — Default, Work, Personal, and any custom profiles you have created. Each window in the sidebar is labeled with its profile name. Use the profile filter at the top of the Windows section to view tabs from a specific profile only. Profile detection uses Chrome's Local State file and Accessibility API to map windows to profiles.
- **"Can it close pinned tabs?"**
  - Yes, but shows warning in review plan
- **"What about tab groups?"**
  - Currently treats all tabs equally; group awareness planned
- **"Does it track my browsing?"**
  - No, all processing is local. See privacy policy.
- **"Can I schedule automatic cleanups?"**
  - Yes, in Preferences → Auto-Cleanup (Pro feature)

## Escalation Procedures

### When to Escalate to Engineering
- Repeated technical issues not resolved by standard troubleshooting
- Suspected bugs in duplicate detection algorithm
- Security concerns or vulnerability reports
- Feature requests requiring product decision
- Performance issues on specific hardware configurations

### Information to Include in Escalation
1. User's macOS version
2. User's Chrome version
3. Exact steps to reproduce issue
4. Console logs if available
5. Screenshots or screen recording (if appropriate)
6. What user expected vs what happened
7. Any error messages shown

## Communication Guidelines

### Tone & Style
- Friendly but professional
- Avoid technical jargon unless user demonstrates expertise
- Always explain what you're doing and why
- Acknowledge frustration before solving problem
- Confirm understanding before proceeding

### Response Templates

**Initial Response**:
```
Hi [Name],

Thanks for reaching out to TabPilot support! I'm happy to help you with [issue].

To get started, could you please [ask for needed information]?

Best regards,
[Your Name]
TabPilot Support
```

**Resolution Response**:
```
Hi [Name],

I'm glad we could get this resolved for you! To summarize what we did:

[Brief summary of steps taken and outcome]

If you have any other questions or run into further issues, please don't hesitate to reach out.

Happy tab managing!
[Your Name]
TabPilot Support
```

**Follow-Up Needed**:
```
Hi [Name],

I'm looking into [issue] and will get back to you by [timeframe] with an update.

In the meantime, please [any temporary workaround or info to gather].

Thanks for your patience!
[Your Name]
TabPilot Support
```

## Metrics to Track
- First response time
- Resolution time
- Issue category distribution
- Customer satisfaction (via follow-up survey)
- Knowledge base article effectiveness
- Escalation rate to engineering

## Knowledge Base Articles to Create
1. "How to verify your TabPilot license"
2. "Troubleshooting installation issues on macOS"
3. "Understanding duplicate detection: What counts as a duplicate?"
4. "Using protected domains to safeguard important tabs"
5. "How TabPilot's undo feature works"
6. "Exporting and importing your tab lists"
7. "Setting up automatic tab cleanup"
8. "What to do if TabPilot isn't detecting your Chrome tabs"
9. "Refund policy and how to request a refund"
10. "Privacy facts: What TabPilot does and doesn't collect"

## Review & Update Schedule
- Review this runbook quarterly
- Update after major releases
- Add new articles as common issues emerge
- Retire obsolete articles
- Share useful insights with product team for UX improvements