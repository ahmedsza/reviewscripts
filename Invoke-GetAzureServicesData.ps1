<#
.SYNOPSIS
    Parent script that orchestrates data collection by calling individual report scripts.

.DESCRIPTION
    Calls the following report scripts in sequence:
      - Get-ResourceGroupReport
      - Get-MySqlFlexibleServerReport
      - Get-MySqlFlexibleServerDatabaseReport
      - Get-AppServiceReportDiagnostics
      - Get-AppServiceReport

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER AppServiceName
    The name of the Azure App Service.

.PARAMETER MySqlServerName
    The name of the MySQL Flexible Server.

.PARAMETER DatabaseName
    The name of the MySQL database.

.PARAMETER OutputDirectory
    Directory where reports will be saved. Defaults to the current directory.

.PARAMETER Subscription
    Optional. The Azure subscription ID or name.

.PARAMETER Slot
    Optional. The App Service deployment slot name (used by Get-AppServiceReportDiagnostics).

.PARAMETER ActivityLogDays
    Optional. Number of days of activity logs to retrieve for the resource group report (1-365). Defaults to 30.

.EXAMPLE
    .\ParentGetData.ps1 -ResourceGroup "myRG" -AppServiceName "myApp" -MySqlServerName "myServer" -DatabaseName "myDb"

.EXAMPLE
    .\ParentGetData.ps1 -ResourceGroup "myRG" -AppServiceName "myApp" -MySqlServerName "myServer" -DatabaseName "myDb" -OutputDirectory "C:\Reports" -Subscription "my-sub-id"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$AppServiceName,

    [Parameter(Mandatory = $true)]
    [string]$MySqlServerName,

    [Parameter(Mandatory = $true)]
    [string]$DatabaseName,

    [string]$OutputDirectory = (Get-Location).Path,

    [string]$Subscription,

    [string]$Slot,

    [ValidateRange(1, 365)]
    [int]$ActivityLogDays = 30
)

$ScriptDir = $PSScriptRoot

function Invoke-Script {
    param(
        [string]$Name,
        [hashtable]$Params
    )
    $scriptPath = Join-Path $ScriptDir "$Name.ps1"
    Write-Host "`n==> Running $Name..." -ForegroundColor Cyan
    & $scriptPath @Params
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        Write-Warning "$Name exited with code $LASTEXITCODE"
    }
}

# Common optional params
$commonOptional = @{}
if ($Subscription) { $commonOptional['Subscription'] = $Subscription }

# 1. Resource Group Report
Invoke-Script -Name 'Get-ResourceGroupReport' -Params (@{
    ResourceGroup   = $ResourceGroup
    OutputDirectory = $OutputDirectory
    ActivityLogDays = $ActivityLogDays
} + $commonOptional)

# 2. MySQL Flexible Server Report
Invoke-Script -Name 'Get-MySqlFlexibleServerReport' -Params (@{
    ServerName      = $MySqlServerName
    ResourceGroup   = $ResourceGroup
    OutputDirectory = $OutputDirectory
} + $commonOptional)

# 3. MySQL Flexible Server Database Report
Invoke-Script -Name 'Get-MySqlFlexibleServerDatabaseReport' -Params (@{
    ServerName      = $MySqlServerName
    ResourceGroup   = $ResourceGroup
    DatabaseName    = $DatabaseName
    OutputDirectory = $OutputDirectory
} + $commonOptional)

# 4. App Service Diagnostics Report
$diagParams = @{
    AppServiceName  = $AppServiceName
    ResourceGroup   = $ResourceGroup
    OutputDirectory = $OutputDirectory
} + $commonOptional
if ($Slot) { $diagParams['Slot'] = $Slot }
Invoke-Script -Name 'Get-AppServiceReportDiagnostics' -Params $diagParams

# 5. App Service Report
Invoke-Script -Name 'Get-AppServiceReport' -Params (@{
    AppServiceName  = $AppServiceName
    ResourceGroup   = $ResourceGroup
    OutputDirectory = $OutputDirectory
} + $commonOptional)

Write-Host "`nAll reports completed. Output directory: $OutputDirectory" -ForegroundColor Green
