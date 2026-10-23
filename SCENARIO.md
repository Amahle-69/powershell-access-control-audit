
#  PowerShell Access Control Audit

## 1. Business Scenario

Mahlangu Business Solutions is a fictional company with employees working in Finance, Human Resources, IT, and Operations.

The company uses security groups to organise access to shared resources and job-related systems. The IT Support team needs a way to compare employee group memberships with an approved access matrix.

The goal is to identify access discrepancies that may require investigation by an authorised administrator.

## 2. Business Problem

Employee responsibilities can change when they join a department, transfer to another role, or take on new duties. Group memberships may not always reflect those changes.

Examples include:

- An employee having membership in a group that is not approved for their department.
- An employee missing a group required for their role.
- An employee appearing to have access beyond their job responsibilities.
- Incomplete employee or group membership records that prevent a reliable comparison.

These conditions can indicate a need for review. They do not automatically prove that access is unauthorised, because legitimate exceptions may exist.

## 3. Proposed Solution

Develop a PowerShell audit tool that imports fictional employee records, an approved department-to-group access matrix, and recorded group memberships from CSV files.

The tool will compare assigned groups with the approved groups for each employee's department. It will report missing required groups, unexpected group memberships, and incomplete or inconsistent data.

The first version will run locally using fictional records and will not grant or remove permissions.

## 4. Project Objectives

- Import structured CSV files using PowerShell's Import-Csv command.
- Validate employee records and required CSV columns.
- Represent approved group access by department.
- Compare assigned memberships with the approved access matrix.
- Identify required groups that appear to be missing.
- Flag group memberships that are not listed as approved for the employee's department.
- Generate a report with findings and recommended next steps.
- Handle duplicate, missing, or inconsistent records.
- Test expected access and access discrepancies.
- Track and publish the project using Git and GitHub.
- Prepare the design for future integration with Active Directory in an authorised lab.

## 5. Fictional Department Access Matrix

The initial approved access matrix will use the following rules:

| Department | Required security group |
|---|---|
| Finance | Finance-Users |
| Human Resources | HR-Users |
| IT | IT-Users |
| IT | Helpdesk-Operators |
| Operations | Operations-Users |

These are fictional group names for the demonstration. The matrix is a simplified example and does not represent a real company's access policy.

The audit will treat a group not listed as approved for an employee's department as an unexpected membership requiring review. It will not automatically conclude that the membership is malicious or unauthorised.

## 6. Fictional Employee Scenarios

### Scenario A: Potentially excessive access

Lerato Mthembu works in Finance. Her recorded memberships include `Finance-Users` and `IT-Administrators`.

The audit should identify `IT-Administrators` as unexpected under the example Finance access matrix and recommend verification by an authorised administrator.

### Scenario B: Missing required access

Thabo Ndlovu works in Human Resources. His record contains no assigned group memberships.

The audit should flag the missing `HR-Users` membership for review. It should not automatically assign the group.

### Scenario C: Unexpected group membership

Zanele Dlamini works in IT. Her recorded memberships include `IT-Users`, `Helpdesk-Operators`, and `Sales-SharedDrive`.

The audit should flag `Sales-SharedDrive` because it is not listed as approved for IT in the sample matrix.

### Scenario D: Access matching the matrix

Naledi Mokoena works in Finance and has the `Finance-Users` group.

The audit should report no discrepancy under the configured access rules.

### Scenario E: Cross-department group membership

Kabelo Sithole works in Operations but has both `Operations-Users` and `Finance-Users`.

The audit should flag `Finance-Users` as unexpected under the example matrix and recommend checking whether there is a valid business exception.

All employee details and group names in this project are fictional.

## 7. Planned Workflow

1. Import employee records.
2. Import the approved department-to-group access matrix.
3. Import recorded employee group memberships.
4. Validate the input files and required fields.
5. Compare each employee's recorded memberships with the required groups for their department.
6. Identify missing and unexpected memberships.
7. Generate a CSV audit report.
8. Review the results and document any known limitations.

## 8. Technology Stack

- Scripting language: Windows PowerShell 5.1-compatible scripting
- Editor: Visual Studio Code
- Data interchange: CSV and Import-Csv
- Version control: Git
- Repository hosting: GitHub
- Planned integration: Active Directory Domain Services in an authorised lab

## 9. Safety and Scope

The first version is a local simulation using fictional data.

It will not connect to a production directory or create, grant, revoke, or modify group memberships.

The audit will produce findings and recommendations for human review. Any future Active Directory integration will require an authorised environment, appropriate permissions, additional testing, and safeguards for permission-changing operations.

## 10. Limitations

- The access matrix is simplified and fictional.
- An unexpected group membership is a discrepancy to investigate, not proof of unauthorised access.
- An employee may have a legitimate exception that is not represented in the sample matrix.
- The accuracy of the audit depends on the quality and completeness of the input files.
- The report does not replace approval processes or security policy.

## 11. Expected Outcome

The completed project should demonstrate how PowerShell can help an IT Support or security team compare recorded group memberships against an approved access matrix, identify discrepancies, and prepare a structured report.

The deliverables will include fictional CSV data, a PowerShell audit script, automated tests, sample reports, and documentation describing the results.
