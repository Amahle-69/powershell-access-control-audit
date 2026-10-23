
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$auditScript = Join-Path $projectRoot 'scripts\Compare-AccessAssignments.ps1'

if (-not (Test-Path -LiteralPath $auditScript -PathType Leaf)) {
    throw "Access audit script not found: $auditScript"
}

$testRoot = Join-Path $env:TEMP (
    'AccessControlEdgeTests-' + [guid]::NewGuid().ToString('N')
)

New-Item -ItemType Directory -Path $testRoot -Force |
    Out-Null

$script:passed = 0
$script:failed = 0

function Assert-True {
    param(
        [string]$Name,
        [bool]$Condition
    )

    if ($Condition) {
        Write-Host "[PASS] $Name" -ForegroundColor Green
        $script:passed++
    }
    else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:failed++
    }
}

function Write-TestCsv {
    param(
        [string]$Name,
        [string]$Content
    )

    $path = Join-Path $testRoot $Name
    [System.IO.File]::WriteAllText($path, $Content)
    return $path
}

function Invoke-ExpectedAuditFailure {
    param(
        [string]$Name,
        [string]$EmployeesPath,
        [string]$MatrixPath,
        [string]$MembershipsPath,
        [string]$ExpectedMessage
    )

    $reportPath = Join-Path $testRoot (
        'report-' + [guid]::NewGuid().ToString('N') + '.csv'
    )

    $caughtMessage = ''

    try {
        & $auditScript `
            -EmployeesCsvPath $EmployeesPath `
            -AccessMatrixPath $MatrixPath `
            -MembershipsCsvPath $MembershipsPath `
            -ReportPath $reportPath | Out-Null
    }
    catch {
        $caughtMessage = $_.Exception.Message
    }

    $expectedFailure = (
        -not [string]::IsNullOrWhiteSpace($caughtMessage) -and
        $caughtMessage -like "*$ExpectedMessage*"
    )

    Assert-True -Name $Name -Condition $expectedFailure
}

try {
    # Prepare a valid one-employee test dataset.
    $validEmployees = Write-TestCsv -Name 'valid-employees.csv' -Content @"
EmployeeID,FirstName,LastName,Department,UserPrincipalName
A9001,Amahle,Hadebe,Finance,amahle.hadebe@example.com
"@

    $validMatrix = Write-TestCsv -Name 'valid-matrix.csv' -Content @"
Department,RequiredGroup
Finance,Finance-Users
"@

    $validMemberships = Write-TestCsv -Name 'valid-memberships.csv' -Content @"
EmployeeID,GroupName
A9001,Finance-Users
"@

    # Test 1: Missing required headers.
    $missingHeaders = Write-TestCsv -Name 'missing-headers.csv' -Content @"
EmployeeID,FirstName
A9001,Amahle
"@

    Invoke-ExpectedAuditFailure `
        -Name 'Missing employee CSV headers are rejected' `
        -EmployeesPath $missingHeaders `
        -MatrixPath $validMatrix `
        -MembershipsPath $validMemberships `
        -ExpectedMessage 'Missing required columns'

    # Test 2: Duplicate employee IDs.
    $duplicateEmployees = Write-TestCsv -Name 'duplicate-employees.csv' -Content @"
EmployeeID,FirstName,LastName,Department,UserPrincipalName
A9001,Amahle,Hadebe,Finance,amahle.hadebe@example.com
A9001,Thabo,Ndlovu,Finance,thabo.ndlovu@example.com
"@

    Invoke-ExpectedAuditFailure `
        -Name 'Duplicate employee IDs are rejected' `
        -EmployeesPath $duplicateEmployees `
        -MatrixPath $validMatrix `
        -MembershipsPath $validMemberships `
        -ExpectedMessage 'Duplicate employee IDs in employee CSV'

    # Test 3: Blank employee ID in membership data.
    $blankMembershipID = Write-TestCsv -Name 'blank-membership-id.csv' -Content @"
EmployeeID,GroupName
,Finance-Users
"@

    Invoke-ExpectedAuditFailure `
        -Name 'Membership rows with a blank employee ID are rejected' `
        -EmployeesPath $validEmployees `
        -MatrixPath $validMatrix `
        -MembershipsPath $blankMembershipID `
        -ExpectedMessage 'blank EmployeeID or GroupName'

    # Test 4: Blank group name in membership data.
    $blankGroupName = Write-TestCsv -Name 'blank-group-name.csv' -Content @"
EmployeeID,GroupName
A9001,
"@

    Invoke-ExpectedAuditFailure `
        -Name 'Membership rows with a blank group name are rejected' `
        -EmployeesPath $validEmployees `
        -MatrixPath $validMatrix `
        -MembershipsPath $blankGroupName `
        -ExpectedMessage 'blank EmployeeID or GroupName'

    # Test 5: Duplicate employee/group membership rows.
    $duplicateMemberships = Write-TestCsv -Name 'duplicate-memberships.csv' -Content @"
EmployeeID,GroupName
A9001,Finance-Users
A9001,Finance-Users
"@

    $duplicateReport = Join-Path $testRoot 'duplicate-membership-report.csv'

    & $auditScript `
        -EmployeesCsvPath $validEmployees `
        -AccessMatrixPath $validMatrix `
        -MembershipsCsvPath $duplicateMemberships `
        -ReportPath $duplicateReport | Out-Null

    $duplicateResults = @(Import-Csv -LiteralPath $duplicateReport)

    $duplicateRecord = @(
        $duplicateResults | Where-Object { $_.EmployeeID -eq 'A9001' }
    )

    Assert-True `
        -Name 'Duplicate membership rows are flagged for review' `
        -Condition (
            $duplicateRecord.Count -eq 1 -and
            $duplicateRecord[0].AuditStatus -eq 'NeedsReview' -and
            $duplicateRecord[0].Findings -like '*Duplicate membership records*'
        )
}
finally {
    # Remove only the temporary directory created by this test.
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Host "`nAccess control edge-case test summary" -ForegroundColor Cyan
Write-Host "Passed: $script:passed"
Write-Host "Failed: $script:failed"

if ($script:failed -gt 0) {
    throw 'One or more access control edge-case tests failed.'
}

Write-Host "`nAll access control edge-case tests passed." -ForegroundColor Green
