# Automatic WSL Installation Script
# This script checks if WSL is installed, installs a distribution, and updates it

# Helper function to get timestamp in format yyyy-MM-dd HH:mm:ss.fff
function Get-Timestamp {
    return (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
}

# Function to check if WSL is installed and working
function Test-WSLInstalled {
    [OutputType([bool])]
    param()
    
    Write-Host "$(Get-Timestamp) Checking if WSL is installed..." -ForegroundColor Green
    try {
        # Try to get WSL status
        wsl --list --verbose > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$(Get-Timestamp) WSL is already installed." -ForegroundColor Green
            return $true
        } else {
            Write-Host "$(Get-Timestamp) WSL is not installed or not functional." -ForegroundColor Yellow
            Write-Host "$(Get-Timestamp) Please enable WSL manually through system settings or run the following command as administrator:" -ForegroundColor Cyan
            Write-Host "$(Get-Timestamp) dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart" -ForegroundColor Gray
            Write-Host "$(Get-Timestamp) and" -ForegroundColor Cyan
            Write-Host "$(Get-Timestamp) dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart" -ForegroundColor Gray
            Write-Host "$(Get-Timestamp) Then restart your computer." -ForegroundColor Cyan
            return $false
        }
    } catch {
        Write-Host "$(Get-Timestamp) WSL is not installed or not functional." -ForegroundColor Yellow
        Write-Host "$(Get-Timestamp) Please enable WSL manually through system settings or run the following command as administrator:" -ForegroundColor Cyan
        Write-Host "$(Get-Timestamp) dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart" -ForegroundColor Gray
        Write-Host "$(Get-Timestamp) and" -ForegroundColor Cyan
        Write-Host "$(Get-Timestamp) dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart" -ForegroundColor Gray
        Write-Host "$(Get-Timestamp) Then restart your computer." -ForegroundColor Cyan
        return $false
    }
}

# Function to check if distribution name is already taken
function Test-DistributionExist {
    [OutputType([bool])]
    param(
        [string]$DistributionNickname
    )
    
    Write-Host "$(Get-Timestamp) Checking if distribution '$DistributionNickname' is already installed..." -ForegroundColor Cyan
    try {
        $installedDistros = wsl --list --quiet 2>&1 | ForEach-Object { $_ -replace '[^\x20-\x7E\u00C0-\u024F]', '' } | Where-Object { $_ -ne '' }
        # Check content of output
        if ($installedDistros -match $DistributionNickname) {
            Write-Host "$(Get-Timestamp) Distribution '$DistributionNickname' is already installed." -ForegroundColor Green
            return $true
        } else {
            Write-Host "$(Get-Timestamp) Distribution '$DistributionNickname' is not installed." -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "$(Get-Timestamp) Distribution '$DistributionNickname' is not installed." -ForegroundColor Yellow
        return $false
    }
}

# Function to install distribution
function Install-Distribution {
    [OutputType([bool])]
    param(
        [string]$DistributionName,
        [string]$DistributionNickname
    )
    
    Write-Host "$(Get-Timestamp) Installing distribution '$DistributionName' with nickname '$DistributionNickname'..." -ForegroundColor Cyan
    
    # First check if the distribution is available
    try {
        wsl --list --online | Select-String -Pattern $DistributionName > $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$(Get-Timestamp) Distribution '$DistributionName' is available." -ForegroundColor Green
            
            # Install distribution
            wsl --install -d $DistributionName --name $DistributionNickname --no-launch
            
            Write-Host "$(Get-Timestamp) Distribution '$DistributionName' successfully installed with nickname '$DistributionNickname'." -ForegroundColor Green
            return $true
        } else {
            Write-Host "$(Get-Timestamp) Distribution '$DistributionName' is not available." -ForegroundColor Red
            Write-Host "$(Get-Timestamp) Available distributions can be displayed with 'wsl --list --online'." -ForegroundColor Cyan
            return $false
        }
    } catch {
        Write-Host "$(Get-Timestamp) Error installing distribution '$DistributionName'." -ForegroundColor Red
        Write-Host "$(Get-Timestamp) Trying alternative method..." -ForegroundColor Yellow
        
        # Alternative method: Direct installation via winget if possible
        Write-Host "$(Get-Timestamp) Please install the distribution manually through the Microsoft Store." -ForegroundColor Cyan
        Write-Host "$(Get-Timestamp) Search for '$DistributionName' in the Microsoft Store and install it." -ForegroundColor Cyan
        Write-Host "$(Get-Timestamp) Then you can run this script again." -ForegroundColor Cyan
        return $false
    }
}

# Function to install tools in the distribution
function Install-Tool {
    [OutputType([void])]
    param(
        [string]$DistributionNickname,
        [Parameter(Mandatory)]
        [string[]]$Tools
    )
    
    Write-Host "$(Get-Timestamp) Installing tools in distribution..." -ForegroundColor Cyan
    try {
        foreach ($tool in $Tools) {
            Write-Host "$(Get-Timestamp) Installing $tool..." -ForegroundColor Cyan
            wsl -d $DistributionNickname -u root -- bash -lc "apt-get update && apt-get install -y $tool" 2>&1 | Out-Null
            Write-Host "$(Get-Timestamp) $tool installed successfully." -ForegroundColor Green
        }
        
        Write-Host "$(Get-Timestamp) All tools installed." -ForegroundColor Green
    } catch {
        Write-Warning "$(Get-Timestamp) Error during tool installation: $_"
        Write-Host "$(Get-Timestamp) You can perform this manually later with:" -ForegroundColor Cyan
        Write-Host "$(Get-Timestamp) wsl -d $DistributionNickname" -ForegroundColor Gray
        foreach ($tool in $Tools) {
            Write-Host "$(Get-Timestamp) sudo apt install $tool -y" -ForegroundColor Gray
        }
    }
}

function Install-Docker {
    [OutputType([void])]
    param(
        [string]$DistributionNickname
    )
    
    # Use single-quoted here-string to preserve shell variables and command substitutions
    $content = @'
sudo install -m 0755 -d /etc/apt/keyrings &&
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc &&
sudo chmod a+r /etc/apt/keyrings/docker.asc &&
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian trixie stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null &&
sudo apt update &&
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y &&
sudo usermod -aG docker $USER &&
echo "✅ Docker installed successfully"
'@ -replace "`r`n", "`n" -replace "`r", ""

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
    [System.IO.File]::WriteAllBytes("docker-install.sh", $bytes)

    Write-Host "$(Get-Timestamp) Executing Docker installation script" -ForegroundColor Cyan
    wsl -d $DistributionNickname -u root -- bash docker-install.sh > $null 2>&1
    Remove-Item docker-install.sh -Force -ErrorAction SilentlyContinue
    Write-Host "$(Get-Timestamp) Docker installation completed" -ForegroundColor Green
}

function Install-Tool-PWSH {
    [OutputType([void])]
    param(
        [string]$DistributionNickname
    )
    # install-pwsh.ps1 (quiet)
    $latest = Invoke-RestMethod https://api.github.com/repos/PowerShell/PowerShell/releases/latest
    $version = $latest.tag_name -replace '^v'
    Write-Host "$(Get-Timestamp) Downloading PowerShell $version" -ForegroundColor Cyan
    $url = "https://github.com/PowerShell/PowerShell/releases/download/$($latest.tag_name)/powershell_${version}-1.deb_amd64.deb"

    $content = @"
curl -s -L -o pwsh.deb '$url' > /dev/null 2>&1 &&
dpkg -i --force-depends pwsh.deb &&
sed -i '/Package: powershell/,/Depends:/s/libicu74[^;]*;/libicu76;/g' /var/lib/dpkg/status &&
apt-get install -f -y > /dev/null 2>&1 &&
rm pwsh.deb &&
echo "✅ PowerShell ${version} installed"
"@ -replace "`r`n", "`n" -replace "`r", ""

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
    [System.IO.File]::WriteAllBytes("pwsh-update.sh", $bytes)

    Write-Host "$(Get-Timestamp) Executing installation script" -ForegroundColor Cyan
    wsl -d $DistributionNickname -u root -- bash pwsh-update.sh > $null 2>&1
    Remove-Item pwsh-update.sh -Force -ErrorAction SilentlyContinue
    Write-Host "$(Get-Timestamp) PowerShell Update abgeschlossen" -ForegroundColor Green
}

function Install-Tool-Docker {
    [OutputType([void])]
    param(
        [string]$DistributionNickname
    )
    
    # Use single-quoted here-string to preserve shell variables and command substitutions
    $content = @'
sudo install -m 0755 -d /etc/apt/keyrings &&
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc &&
sudo chmod a+r /etc/apt/keyrings/docker.asc &&
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian trixie stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null &&
sudo apt update &&
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y &&
sudo usermod -aG docker $USER &&
echo "✅ Docker installed successfully"
'@ -replace "`r`n", "`n" -replace "`r", ""

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
    [System.IO.File]::WriteAllBytes("docker-install.sh", $bytes)

    Write-Host "$(Get-Timestamp) Executing Docker installation script" -ForegroundColor Cyan
    wsl -d $DistributionNickname -u root -- bash docker-install.sh > $null 2>&1
    Remove-Item docker-install.sh -Force -ErrorAction SilentlyContinue
    Write-Host "$(Get-Timestamp) Docker installation completed" -ForegroundColor Green
}

# Function to update and upgrade WSL system
function Update-WSLSystem {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [string]$DistributionNickname
    )
    
    if ($PSCmdlet.ShouldProcess("WSL distribution $DistributionNickname", "Update and upgrade")) {
        Write-Host "$(Get-Timestamp) Updating and upgrading WSL system..." -ForegroundColor Cyan
        try {
            wsl -d $DistributionNickname -u root -- bash -lc "apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && apt-get autoremove -y && apt-get autoclean" 2>&1 | Out-Null
            Write-Host "$(Get-Timestamp) WSL system updated and upgraded successfully." -ForegroundColor Green
        } catch {
            Write-Warning "$(Get-Timestamp) Error during WSL system update and upgrade: $_"
            Write-Host "$(Get-Timestamp) You can perform this manually later with:" -ForegroundColor Cyan
            Write-Host "$(Get-Timestamp) wsl -d $DistributionNickname" -ForegroundColor Gray
            Write-Host "$(Get-Timestamp) sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y" -ForegroundColor Gray
        }
    }
}

# Function to update distribution (kept for backward compatibility)
function Update-Distribution {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [string]$DistributionNickname
    )
    
    if ($PSCmdlet.ShouldProcess("WSL distribution $DistributionNickname", "Update")) {
        Write-Host "$(Get-Timestamp) Updating distribution..." -ForegroundColor Cyan
        try {
            wsl -d $DistributionNickname -u root -- bash -lc "apt-get update && apt-get upgrade -y"
            Write-Host "$(Get-Timestamp) Distribution updated successfully." -ForegroundColor Green
        } catch {
            Write-Warning "$(Get-Timestamp) Error during distribution update: $_"
            Write-Host "$(Get-Timestamp) You can perform this manually later with:" -ForegroundColor Cyan
            Write-Host "$(Get-Timestamp) wsl -d $DistributionNickname" -ForegroundColor Gray
            Write-Host "$(Get-Timestamp) sudo apt update && sudo apt upgrade -y" -ForegroundColor Gray
        }
    }
}

# Function to create a new user in the distribution
function New-WSLUser {
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$DistributionNickname,
        [Parameter(Mandatory)]
        [string]$Username,
        [Parameter(Mandatory)]
        [string]$SecString
    )
    
    Write-Host "$(Get-Timestamp) Creating user '$Username' in '$DistributionNickname'..." -ForegroundColor Cyan
    try {
        # Create user with SecString using chpasswd
        # For bash, we need to escape single quotes by ending the quote, adding an escaped quote, and starting a new quote
        # Example: 'SecString' becomes '\'''
        $escapedSecString = $SecString -replace "'", "'\'''"
        $command = "useradd -m -s /bin/bash ${Username} && echo '${Username}:${escapedSecString}' | chpasswd"
        wsl -d $DistributionNickname -u root -- bash -lc "$command"
        Write-Host "$(Get-Timestamp) User '$Username' created successfully." -ForegroundColor Green
    } catch {
        Write-Warning "$(Get-Timestamp) Error creating user: $_"
    }
}

# Function to execute a custom command in the distribution
function Invoke-WSLCommand {
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$DistributionNickname,
        [Parameter(Mandatory)]
        [string]$Command,
        [Parameter(Mandatory)]
        [string]$CommandDescription,
        [string]$User = "root"
    )
    
    Write-Host "$(Get-Timestamp) Executing command in '$DistributionNickname': $CommandDescription" -ForegroundColor Cyan
    try {
        wsl -d $DistributionNickname -u $User -- bash -lc $Command
        Write-Host "$(Get-Timestamp) Command executed successfully." -ForegroundColor Green
    } catch {
        Write-Warning "$(Get-Timestamp) Error executing command: $_"
    }
}

# Function to uninstall a WSL distribution
function Uninstall-Distribution {
    [OutputType([bool])]
    param(
        [string]$DistributionNickname
    )
    
    Write-Host "$(Get-Timestamp) Uninstalling distribution '$DistributionNickname'..." -ForegroundColor Cyan
    
    try {
        # Check if distribution exists before attempting to uninstall
        if (Test-DistributionExist -DistributionNickname $DistributionNickname) {
            # Unregister the distribution
            wsl --unregister $DistributionNickname
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "$(Get-Timestamp) Distribution '$DistributionNickname' successfully uninstalled." -ForegroundColor Green
                return $true
            } else {
                Write-Host "$(Get-Timestamp) Failed to uninstall distribution '$DistributionNickname'." -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "$(Get-Timestamp) Distribution '$DistributionNickname' is not installed." -ForegroundColor Yellow
            return $true
        }
    } catch {
        Write-Host "$(Get-Timestamp) Error uninstalling distribution '$DistributionNickname': $_" -ForegroundColor Red
        return $false
    }
}
