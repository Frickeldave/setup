param(
    [Parameter(Mandatory)]
    [string]$GitUser,
    [Parameter(Mandatory)]
    [string]$GitPat,
    [Parameter(Mandatory)]
    [string]$Username,
    [Parameter(Mandatory)]
    [string]$SecString,
    [switch]$Force
)

. .\manage-wsl.ps1

$DistributionName = "Debian"
$DistributionNickname = "BWI"

# Check if WSL is installed
if (-not (Test-WSLInstalled)) {
    exit 1
}

# If -Force is set, remove existing distribution first
if ($Force) {
    if (Test-DistributionExist -DistributionNickname $DistributionNickname) {
        Write-Host "Force mode: removing existing distribution '$DistributionNickname'..." -ForegroundColor Yellow
        if (-not (Uninstall-Distribution -DistributionNickname $DistributionNickname)) {
            Write-Host "Failed to remove existing distribution. Aborting." -ForegroundColor Red
            exit 1
        }
    }
}

# Check if the desired distribution is already installed
$distributionInstalled = Test-DistributionExist -DistributionNickname $DistributionNickname

# If distribution is not installed, install it
if (-not $distributionInstalled) {
    if (-not (Install-Distribution -DistributionName $DistributionName -DistributionNickname $DistributionNickname)) {
        exit 1
    }
} else {
    Write-Host "Distribution '$DistributionNickname' is already installed." -ForegroundColor Cyan
}
    
# Update and upgrade WSL system
Update-WSLSystem -DistributionNickname $DistributionNickname

# install tools
Install-Tool -DistributionNickname $DistributionNickname -Tools @("git", "curl")

# Create WSL user with same name as current Windows user
New-WSLUser -DistributionNickname $DistributionNickname -Username $($env:USERNAME) -SecString $SecString

Invoke-WSLCommand -DistributionNickname $DistributionNickname -Command "cd ~; mkdir dev; cd dev; git clone https://${GitUser}:${GitPat}@github.com/${GitUser}/sppmodules.git" -CommandDescription "Clone git repo sppmodules" -User $($env:USERNAME)

Write-Host "WSL configuration completed!" -ForegroundColor Green
Write-Host "You can now work with the '$DistributionNickname' distribution." -ForegroundColor Cyan
Write-Host "Start the distribution with: wsl -d $DistributionNickname" -ForegroundColor Cyan