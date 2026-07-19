# Privacy Compliance Review (GDPR, CCPA, Global)

## Objective

Audit the codebase for compliance with major privacy regulations including
GDPR (EU), CCPA/CPRA (California), and emerging global privacy laws.

## Review Checklist

### GDPR Compliance

#### Lawful Basis for Processing (Art. 6)

- [ ] Each type of data processing has an identified lawful basis:
  - Consent (freely given, specific, informed, unambiguous)
  - Contract performance
  - Legitimate interest (with documented balancing test)
- [ ] Consent is not bundled with terms of service acceptance
- [ ] Consent can be withdrawn as easily as it was given

#### Data Subject Rights

- [ ] **Right to Access (Art. 15)**: Users can request all data held about them
- [ ] **Right to Rectification (Art. 16)**: Users can correct inaccurate data
- [ ] **Right to Erasure (Art. 17)**: Users can request deletion of their data
  - Check: What happens to related records when a user deletes their account?
  - Check: Are there referential integrity issues with deletion?
- [ ] **Right to Portability (Art. 20)**: Users can export data in machine-readable format
- [ ] **Right to Object (Art. 21)**: Users can object to processing based on legitimate interest
- [ ] **Right to Restriction (Art. 18)**: Users can request processing be limited

#### Data Protection by Design (Art. 25)

- [ ] Privacy is built into the system architecture, not bolted on
- [ ] Default settings are the most privacy-protective option
- [ ] Data fields use pseudonymization where possible

#### Records of Processing (Art. 30)

- [ ] Processing activities are documented (even if informally in code comments)
- [ ] Data flows to third parties are documented

#### International Data Transfers (Art. 44-49)

- [ ] Identify where data is stored and processed geographically
- [ ] Document processing locations for all third-party services
- [ ] Appropriate transfer mechanisms in place (SCCs, adequacy decisions)

### CCPA/CPRA Compliance (California)

- [ ] **Right to Know**: Users can request what personal information is collected
- [ ] **Right to Delete**: Users can request deletion of personal information
- [ ] **Right to Opt-Out of Sale**: If any data "selling" occurs (broadly defined)
  - Note: Sharing data with ad networks or analytics counts as "selling"
- [ ] **Right to Non-Discrimination**: Users exercising rights are not penalized
- [ ] **Sensitive Personal Information**: Special handling where applicable

### Cookie & Tracking Compliance

- [ ] Cookie consent banner present (required for EU visitors)
- [ ] Essential vs non-essential cookies are distinguished
- [ ] Third-party cookies are identified and consent-gated
- [ ] Local storage used for tracking purposes is treated as cookies
- [ ] Do Not Track (DNT) header is respected or documented as not supported

### Children's Privacy (COPPA / Age Gates)

- [ ] Age verification or gate exists if platform is accessible to minors
- [ ] If users under 13 (or 16 in EU) can sign up, special handling exists
- [ ] Parental consent mechanisms if applicable

### Privacy Policy Alignment

- [ ] Code behavior matches what the privacy policy promises
- [ ] New data collection not yet reflected in privacy policy is flagged
- [ ] Data retention in code matches stated retention periods

## Emerging Regulations to Watch

Flag if the codebase has potential issues with:

- Brazil LGPD
- India DPDP Act
- UK Data Protection Act 2018
- Canada PIPEDA
- State-level US laws (Virginia VCDPA, Colorado CPA, Connecticut CTDPA)

## Severity Guide

- **CRITICAL**: No deletion path for user data, selling data without opt-out
- **HIGH**: Missing consent mechanisms, non-compliant international transfers
- **MEDIUM**: Incomplete data subject rights implementation, cookie compliance gaps
- **LOW**: Documentation gaps, emerging regulation preparation
