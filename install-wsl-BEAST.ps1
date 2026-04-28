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
$DistributionNickname = "BEAST"

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

# Create WSL user with same name as current Windows user
New-WSLUser -DistributionNickname $DistributionNickname -Username $($env:USERNAME) -SecString $SecString

# install tools
Install-Tool -DistributionNickname $DistributionNickname -Tools @("git", "curl", "python3", "ca-certificates", "gnupg", "chromium")
Install-Tool-PWSH -DistributionNickname $DistributionNickname
Install-Tool-Docker -DistributionNickname $DistributionNickname
Install-Tool-Node -DistributionNickname $DistributionNickname -Username $($env:USERNAME)
Install-Tool-ClaudeCode -DistributionNickname $DistributionNickname -Username $($env:USERNAME) -GitPat $GitPat
Invoke-WSLCommand -DistributionNickname $DistributionNickname -Command "cd ~; mkdir dev; cd dev; git clone -q https://${GitUser}:${GitPat}@github.com/${GitUser}/BEAST.git" -CommandDescription "Clone BEAST git repo" -User $($env:USERNAME)
Invoke-WSLCommand -DistributionNickname $DistributionNickname -Command 'cd ~/dev/BEAST && npm install --silent 2>&1 | grep -v "^npm notice"' -CommandDescription "npm install in BEAST" -User $($env:USERNAME)
Invoke-WSLCommand -DistributionNickname $DistributionNickname -Command 'cd ~/dev/BEAST && npx playwright install chromium' -CommandDescription "Install Playwright Chromium in BEAST" -User $($env:USERNAME)

Write-Host "$(Get-Timestamp) WSL configuration completed!" -ForegroundColor Green
Write-Host "$(Get-Timestamp) You can now work with the '$DistributionNickname' distribution." -ForegroundColor Cyan
Write-Host "$(Get-Timestamp) Start the distribution with: wsl -d $DistributionNickname" -ForegroundColor Cyan