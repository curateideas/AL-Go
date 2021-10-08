<#
This module contains some useful functions for working with app manifests.
#>

. (Join-Path -path $PSScriptRoot -ChildPath "..\AL-Go-Helper.ps1" -Resolve)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$alTemplatePath = Join-Path -Path $here -ChildPath "AppTemplate" 


$validRanges = @{
    "PTE"           = "50000..99999";
    "AppSource App" = "100000..$([int32]::MaxValue)";
    "Test App"      = "50000..$([int32]::MaxValue)" ;
};

function Confirm-IdRanges([string] $templateType, [string]$idrange ) {  
    $validRange = $validRanges.$templateType.Replace('..', '-').Split("-")
    $validStart = [int](stringToInt($validRange[0]))
    $validEnd = [int](stringToInt($validRange[1]))

    $ids = $idrange.Replace('..', '-').Split("-")
    $idStart = [int](stringToInt($ids[0]))
    $idEnd = [int](stringToInt($ids[1]))
    
    if ($ids.Count -ne 2 -or ($idStart) -lt $validStart -or $idStart -gt $idEnd -or $idEnd -lt $validStart -or $idEnd -gt $validEnd -or $idStart -gt $idEnd) { 
        throw "IdRange should be formattet as fromId..toId, and the Id range must be in $($validRange[0]) and $($validRange[1])"
    }

    return $ids
} 

function UpdateManifest
(
    [string]$appJsonFile,
    [string]$name,
    [string]$publisher,
    [string]$version,
    [string[]]$idrange
) 
{
    #Modify app.json
    $appJson = Get-Content "$($alTemplatePath)\app.json" | ConvertFrom-Json

    $appJson.id = [Guid]::NewGuid().ToString()
    $appJson.Publisher = $publisher
    $appJson.Name = $name
    $appJson.Version = $version
    $appJson.idRanges[0].from = $idrange[0]
    $appJson.idRanges[0].to = $idrange[1]
    Set-Content -Path $appJsonFile -Value (ConvertTo-Json -InputObject $appJson -Depth 99)
}

function UpdateALFile 
(
    [string] $alFile,
    [string] $startId
) 
{
    $al = Get-Content -Raw -path "$($alTemplatePath)\HelloWorld.al"
    $al = $al.Replace('50100', $startId)
    Set-Content -Path $alFile -value $al
}

<#
.SYNOPSIS
Creates a simple PTE.
#>
function New-SimplePTE
(
    [string]$destinationPath,
    [string]$name,
    [string]$publisher,
    [string]$version,
    [string[]]$idrange
) 
{
    Write-Host "Creating a new PTE. Path: $destinationPath"
    New-Item  -Path $destinationPath -ItemType Directory -Force;
    New-Item  -Path "$($destinationPath)\.vscode" -ItemType Directory -Force
    Copy-Item -path "$($alTemplatePath)\.vscode\launch.json" -Destination "$($destinationPath)\.vscode\launch.json"

    UpdateManifest -appJsonFile "$($destinationPath)\app.json" -name $name -publisher $publisher -idrange $idrange -version $version
    UpdateALFile -alFile "$($destinationPath)\HelloWorld.al" -startId $idrange[0]
}

function Update-WorkSpaces 
(
    [string] $baseFolder,
    [string] $appName
) 
{
    Get-ChildItem -Path $baseFolder -Filter "*.code-workspace" | 
        ForEach-Object {
            try {
                $workspaceFileName = $_.Name
                $workspaceFile = $_.FullName
                $workspace = Get-Content $workspaceFile | ConvertFrom-Json
                if (-not ($workspace.folders | Where-Object { $_.Path -eq $appName })) {
                    $workspace.folders += @(@{ "path" = $appName })
                }
                $workspace | ConvertTo-Json -Depth 99 | Set-Content -Path $workspaceFile
            }
            catch {
                Throw "Updating the workspace file $workspaceFileName failed due to: $($_.Exception.Message)"
            }
        }
}

# <#
# .SYNOPSIS
# Creates an AppSource app.
# #>
# function CreateSimpleAppSource App
# (
#     [Parameter(Position = 0, Mandatory = $false, ValueFromPipeline = $True)]
#     [psobject]$ChangeSet,
#     [string]$ClientName
# ) {

# }

# <#
# .SYNOPSIS
# Creates a test app.
# #>
# function CreateSimpleTestApp
# (
#     [Parameter(Position = 0, Mandatory = $false, ValueFromPipeline = $True)]
#     [psobject]$ChangeSet,
#     [string]$ClientName
# ) {

# }


Export-ModuleMember -Function New-SimplePTE
# Export-ModuleMember -Function CreateSimpleAppSource App
Export-ModuleMember -Function Confirm-IdRanges
Export-ModuleMember -Function Update-WorkSpaces
