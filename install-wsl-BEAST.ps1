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

# install tools
Install-Tool -DistributionNickname $DistributionNickname -Tools @("git", "curl", "python3", "ca-certificates", "gnupg", "chromium")
Install-Tool-PWSH -DistributionNickname $DistributionNickname
Install-Tool-Docker -DistributionNickname $DistributionNickname

# Create WSL user with same name as current Windows user
New-WSLUser -DistributionNickname $DistributionNickname -Username $($env:USERNAME) -SecString $SecString

Invoke-WSLCommand -DistributionNickname $DistributionNickname -Command "cd ~; mkdir dev; cd dev; git clone -q https://${GitUser}:${GitPat}@github.com/${GitUser}/BEAST.git" -CommandDescription "Clone BEAST git repo" -User $($env:USERNAME)
Invoke-WSLCommand -DistributionNickname $DistributionNickname -Command "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash > /dev/null 2>&1" -CommandDescription "Install nvm" -User $($env:USERNAME)

# Install Node LTS and project dependencies via nvm using a temp script
$nvm_node_install = @'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts > /dev/null 2>&1
nvm use --lts > /dev/null 2>&1
cd ~/dev/BEAST && npm install --silent 2>&1 | grep -v "^npm notice"
'@ -replace "`r`n", "`n" -replace "`r", "`n"

$nvmBytes = [System.Text.Encoding]::UTF8.GetBytes($nvm_node_install)
[System.IO.File]::WriteAllBytes("nvm-node-install.sh", $nvmBytes)
Write-Host "$(Get-Timestamp) Installing Node.js LTS via nvm and running npm install..." -ForegroundColor Cyan
wsl -d $DistributionNickname -u $($env:USERNAME) -- bash nvm-node-install.sh 2>&1 | Where-Object { $_ -ne '' }
Remove-Item nvm-node-install.sh -Force -ErrorAction SilentlyContinue
Write-Host "$(Get-Timestamp) Node.js and npm install completed." -ForegroundColor Green

Write-Host "$(Get-Timestamp) WSL configuration completed!" -ForegroundColor Green
Write-Host "$(Get-Timestamp) You can now work with the '$DistributionNickname' distribution." -ForegroundColor Cyan
Write-Host "$(Get-Timestamp) Start the distribution with: wsl -d $DistributionNickname" -ForegroundColor Cyan