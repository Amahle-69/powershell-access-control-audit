
[CmdletBinding()]
param(
    [string]$EmployeesCsvPath,
    [string]$AccessMatrixPath,
    [string]$MembershipsCsvPath,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

# Locate the project root.
$projectRoot = Split-Path -Parent $PSScriptRoot

# Use project defaults unless alternate paths are supplied.
if ([string]::IsNullOrWhiteSpace($EmployeesCsvPath)) {
    $EmployeesCsvPath = Join-Path $projectRoot 'data\employees.csv'
}

if ([string]::IsNullOrWhiteSpace($AccessMatrixPath)) {
    $AccessMatrixPath = Join-Path $projectRoot 'data\approved-access-matrix.csv'
}

if ([string]::IsNullOrWhiteSpace($MembershipsCsvPath)) {
    $MembershipsCsvPath = Join-Path $projectRoot 'data\assigned-group-memberships.csv'
}

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $reportDirectory = Join-Path $projectRoot 'reports'
    $ReportPath = Join-Path $reportDirectory 'access-control-audit.csv'
}
else {
    $reportDirectory = Split-Path -Parent $ReportPath
}

# Verify CSV headers, including when a file contains only a header row.
function Assert-CsvHeaders {
    param(
        [string]$Path,
        [string[]]$RequiredHeaders
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required CSV file not found: $Path"
    }

    $firstLine = Get-Content -LiteralPath $Path -TotalCount 1

    if ([string]::IsNullOrWhiteSpace($firstLine)) {
        throw "CSV file is empty or has no header: $Path"
    }

    # Remove a possible UTF-8 byte-order mark.
    $firstLine = $firstLine.TrimStart([char]0xFEFF)

    $headers = @(
        $firstLine.Split(',') |
            ForEach-Object { $_.Trim().Trim('"') }
    )

    $missingHeaders = @(
        $RequiredHeaders |
            Where-Object { $headers -notcontains $_ }
    )

    if ($missingHeaders.Count -gt 0) {
        throw "Missing required columns in '$Path': $($missingHeaders -join ', ')"
    }
}

# Confirm that all three input files have the required columns.
Assert-CsvHeaders -Path $EmployeesCsvPath -RequiredHeaders @(
    'EmployeeID',
    'FirstName',
    'LastName',
    'Department',
    'UserPrincipalName'
)

Assert-CsvHeaders -Path $AccessMatrixPath -RequiredHeaders @(
    'Department',
    'RequiredGroup'
)

Assert-CsvHeaders -Path $MembershipsCsvPath -RequiredHeaders @(
    'EmployeeID',
    'GroupName'
)

# Import the CSV data.
$employees = @(Import-Csv -LiteralPath $EmployeesCsvPath)
$accessRules = @(Import-Csv -LiteralPath $AccessMatrixPath)
$memberships = @(Import-Csv -LiteralPath $MembershipsCsvPath)

if ($employees.Count -eq 0) {
    throw 'The employee CSV contains no employee records.'
}

if ($accessRules.Count -eq 0) {
    throw 'The approved access matrix contains no rules.'
}

# Validate employee identity fields.
foreach ($employee in $employees) {
    foreach ($field in @(
        'EmployeeID',
        'FirstName',
        'LastName',
        'Department'
    )) {
        if ([string]::IsNullOrWhiteSpace([string]$employee.$field)) {
            throw "Employee record contains a missing required field: $field"
        }
    }
}

# Avoid comparing ambiguous employee records.
$duplicateEmployeeIDs = @(
    $employees |
        Group-Object -Property {
            ([string]$_.EmployeeID).Trim().ToUpperInvariant()
        } |
        Where-Object { $_.Count -gt 1 }
)

if ($duplicateEmployeeIDs.Count -gt 0) {
    $duplicateNames = @(
        $duplicateEmployeeIDs | ForEach-Object { $_.Name }
    )

    throw "Duplicate employee IDs in employee CSV: $($duplicateNames -join ', ')"
}

# Validate that the access matrix has usable rules.
foreach ($rule in $accessRules) {
    if (
        [string]::IsNullOrWhiteSpace([string]$rule.Department) -or
        [string]::IsNullOrWhiteSpace([string]$rule.RequiredGroup)
    ) {
        throw 'The access matrix contains a blank department or required group.'
    }
}

# Validate recorded membership rows.
foreach ($membership in $memberships) {
    if (
        [string]::IsNullOrWhiteSpace([string]$membership.EmployeeID) -or
        [string]::IsNullOrWhiteSpace([string]$membership.GroupName)
    ) {
        throw 'The memberships CSV contains a blank EmployeeID or GroupName.'
    }
}

$results = @()

foreach ($employee in $employees) {
    $employeeID = ([string]$employee.EmployeeID).Trim()
    $department = ([string]$employee.Department).Trim()

    $findings = [System.Collections.Generic.List[string]]::new()
    $recommendations = [System.Collections.Generic.List[string]]::new()

    # Find the approved access rules for this department.
    $requiredGroups = @(
        $accessRules |
            Where-Object {
                ([string]$_.Department).Trim() -ieq $department
            } |
            ForEach-Object {
                ([string]$_.RequiredGroup).Trim()
            } |
            Sort-Object -Unique
    )

    # Find the recorded memberships for this employee.
    $assignedRecords = @(
        $memberships |
            Where-Object {
                ([string]$_.EmployeeID).Trim() -ieq $employeeID
            }
    )

    $assignedGroups = @(
        $assignedRecords |
            ForEach-Object { ([string]$_.GroupName).Trim() } |
            Sort-Object -Unique
    )

    # Identify duplicate rows for the same employee/group pair.
    $duplicateMemberships = @(
        $assignedRecords |
            Group-Object -Property {
                ([string]$_.GroupName).Trim().ToUpperInvariant()
            } |
            Where-Object { $_.Count -gt 1 }
    )

    if ($requiredGroups.Count -eq 0) {
        $findings.Add('No approved access rules found for department.')
        $recommendations.Add(
            'Confirm the department and obtain an approved access matrix before assessing group membership.'
        )
    }
    else {
        # Required groups not present in the recorded memberships.
        $missingGroups = @(
            $requiredGroups |
                Where-Object { $assignedGroups -notcontains $_ }
        )

        # Recorded memberships not listed as approved for this department.
        $unexpectedGroups = @(
            $assignedGroups |
                Where-Object { $requiredGroups -notcontains $_ }
        )

        if ($missingGroups.Count -gt 0) {
            $findings.Add(
                "Missing required groups: $($missingGroups -join ', ')"
            )

            $recommendations.Add(
                'Verify the employee role and approved access request before considering any group assignment.'
            )
        }

        if ($unexpectedGroups.Count -gt 0) {
            $findings.Add(
                "Unexpected group memberships: $($unexpectedGroups -join ', ')"
            )

            $recommendations.Add(
                'Check business justification, approvals, and any authorised access exceptions.'
            )
        }
    }

    if ($assignedRecords.Count -eq 0) {
        $findings.Add('No group membership records found.')
        $recommendations.Add(
            'Confirm that membership data was exported correctly and review required access with the responsible team.'
        )
    }

    if ($duplicateMemberships.Count -gt 0) {
        $duplicateGroupNames = @(
            $duplicateMemberships | ForEach-Object { $_.Name }
        )

        $findings.Add(
            "Duplicate membership records: $($duplicateGroupNames -join ', ')"
        )

        $recommendations.Add(
            'Check the source export for duplicated employee/group records.'
        )
    }

    if ($findings.Count -gt 0) {
        $auditStatus = 'NeedsReview'
        $findingsText = $findings -join '; '
        $recommendationsText = $recommendations -join '; '
    }
    else {
        $auditStatus = 'NoDiscrepancyUnderConfiguredRules'
        $findingsText = 'None under configured rules'
        $recommendationsText = 'No discrepancy was identified by the configured checks; this does not prove that all access is appropriate.'
    }

    $results += [pscustomobject]@{
        EmployeeID         = $employee.EmployeeID
        FirstName          = $employee.FirstName
        LastName           = $employee.LastName
        Department         = $department
        UserPrincipalName  = $employee.UserPrincipalName
        AssignedGroups     = if ($assignedGroups.Count -gt 0) {
            $assignedGroups -join '; '
        }
        else {
            '(none recorded)'
        }
        RequiredGroups     = if ($requiredGroups.Count -gt 0) {
            $requiredGroups -join '; '
        }
        else {
            '(no approved rules)'
        }
        AuditStatus        = $auditStatus
        Findings           = $findingsText
        Recommendations   = $recommendationsText
    }
}

# Export the audit report.
if (
    -not [string]::IsNullOrWhiteSpace($reportDirectory) -and
    -not (Test-Path -LiteralPath $reportDirectory -PathType Container)
) {
    New-Item -ItemType Directory -Path $reportDirectory -Force |
        Out-Null
}

$results |
    Export-Csv -LiteralPath $ReportPath -NoTypeInformation -Encoding UTF8

$reviewCount = @(
    $results | Where-Object { $_.AuditStatus -eq 'NeedsReview' }
).Count

$noDiscrepancyCount = @(
    $results |
        Where-Object {
            $_.AuditStatus -eq 'NoDiscrepancyUnderConfiguredRules'
        }
).Count

Write-Host "`nAccess control audit completed." -ForegroundColor Green
Write-Host "Employees reviewed: $($employees.Count)"
Write-Host "Membership records: $($memberships.Count)"
Write-Host "Employees needing review: $reviewCount"
Write-Host "No discrepancy under configured rules: $noDiscrepancyCount"
Write-Host "Report saved to: $ReportPath"
Write-Host 'No access permissions or group memberships were changed.'

$results |
    Format-Table EmployeeID, FirstName, LastName, AuditStatus, Findings -Wrap -AutoSize
