
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$auditScript = Join-Path $projectRoot 'scripts\Compare-AccessAssignments.ps1'
$reportPath = Join-Path $projectRoot 'reports\access-control-audit.csv'

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

# Confirm the audit script exists.
Assert-True `
    -Name 'Access audit script exists' `
    -Condition (Test-Path -LiteralPath $auditScript -PathType Leaf)

if (-not (Test-Path -LiteralPath $auditScript -PathType Leaf)) {
    throw 'Cannot test access assignments because the audit script is missing.'
}

# Generate a fresh audit report from the project CSV files.
& $auditScript | Out-Null

Assert-True `
    -Name 'Access audit report was generated' `
    -Condition (Test-Path -LiteralPath $reportPath -PathType Leaf)

if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw 'Cannot continue because the access audit report was not generated.'
}

$results = @(Import-Csv -LiteralPath $reportPath)

Assert-True `
    -Name 'All five employees are included' `
    -Condition ($results.Count -eq 5)

# Lerato: an unexpected IT administrators membership.
$lerato = @($results | Where-Object { $_.EmployeeID -eq 'A1001' })

Assert-True `
    -Name 'Lerato is flagged for unexpected IT administrator access' `
    -Condition (
        $lerato.Count -eq 1 -and
        $lerato[0].AuditStatus -eq 'NeedsReview' -and
        $lerato[0].Findings -like '*IT-Administrators*'
    )

# Thabo: missing required HR group and no recorded memberships.
$thabo = @($results | Where-Object { $_.EmployeeID -eq 'A1002' })

Assert-True `
    -Name 'Thabo is flagged for missing HR-Users access' `
    -Condition (
        $thabo.Count -eq 1 -and
        $thabo[0].AuditStatus -eq 'NeedsReview' -and
        $thabo[0].Findings -like '*HR-Users*'
    )

Assert-True `
    -Name 'Thabo has no recorded group memberships' `
    -Condition (
        $thabo.Count -eq 1 -and
        $thabo[0].Findings -like '*No group membership records found*'
    )

# Zanele: an unexpected shared-drive membership.
$zanele = @($results | Where-Object { $_.EmployeeID -eq 'A1003' })

Assert-True `
    -Name 'Zanele is flagged for unexpected Sales-SharedDrive access' `
    -Condition (
        $zanele.Count -eq 1 -and
        $zanele[0].AuditStatus -eq 'NeedsReview' -and
        $zanele[0].Findings -like '*Sales-SharedDrive*'
    )

# Naledi: memberships match the configured matrix.
$naledi = @($results | Where-Object { $_.EmployeeID -eq 'A1004' })

Assert-True `
    -Name 'Naledi has no discrepancy under configured rules' `
    -Condition (
        $naledi.Count -eq 1 -and
        $naledi[0].AuditStatus -eq 'NoDiscrepancyUnderConfiguredRules'
    )

# Kabelo: an unexpected Finance group membership.
$kabelo = @($results | Where-Object { $_.EmployeeID -eq 'A1005' })

Assert-True `
    -Name 'Kabelo is flagged for unexpected Finance-Users access' `
    -Condition (
        $kabelo.Count -eq 1 -and
        $kabelo[0].AuditStatus -eq 'NeedsReview' -and
        $kabelo[0].Findings -like '*Finance-Users*'
    )

# Verify aggregate results.
$reviewCount = @(
    $results | Where-Object { $_.AuditStatus -eq 'NeedsReview' }
).Count

$noDiscrepancyCount = @(
    $results |
        Where-Object {
            $_.AuditStatus -eq 'NoDiscrepancyUnderConfiguredRules'
        }
).Count

Assert-True `
    -Name 'Four employees require review' `
    -Condition ($reviewCount -eq 4)

Assert-True `
    -Name 'One employee has no discrepancy under configured rules' `
    -Condition ($noDiscrepancyCount -eq 1)

# Ensure each result has a recommendation.
$missingRecommendations = @(
    $results |
        Where-Object {
            [string]::IsNullOrWhiteSpace($_.Recommendations)
        }
)

Assert-True `
    -Name 'Every employee record has a recommendation or status note' `
    -Condition ($missingRecommendations.Count -eq 0)

Write-Host "`nAccess control audit test summary" -ForegroundColor Cyan
Write-Host "Passed: $script:passed"
Write-Host "Failed: $script:failed"

if ($script:failed -gt 0) {
    throw 'One or more access control audit tests failed.'
}

Write-Host "`nAll access control audit tests passed." -ForegroundColor Green
