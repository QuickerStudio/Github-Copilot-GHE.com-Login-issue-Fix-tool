# 清除 VS Code 配置文件的 PowerShell 脚本
# 创建日期: 2025年6月9日
# 更新日期: 2025年6月9日 - 移除备份功能

# 定义 VS Code 配置文件的路径
$vscodeDirPath = Join-Path $env:APPDATA "Code"
$vscodeUserDataPath = Join-Path $vscodeDirPath "User"

# 定义需要清除的目录和文件
$configFiles = @(
    "settings.json",
    "keybindings.json",
    "snippets"
)

$configDirectories = @(
    "workspaceStorage",
    "globalStorage"
)

# GitHub Copilot 相关配置和缓存
$copilotPaths = @{
    "CopilotGlobalStorage" = Join-Path $vscodeDirPath "User\globalStorage\github.copilot"
    "CopilotGlobalStorageChatUI" = Join-Path $vscodeDirPath "User\globalStorage\github.copilot-chat"
    "CopilotLocalStorage" = Join-Path $env:LOCALAPPDATA "github-copilot"
    "GitCredentialsHelper" = Join-Path $env:USERPROFILE ".git-credentials"
    "VSCodeSecretStorage" = Join-Path $env:APPDATA "Code\User\secrets"
    "VSCodeAuthSessions" = Join-Path $env:APPDATA "Code\User\sessionStorage"
    "VSCodeCaches" = Join-Path $env:APPDATA "Code\Cache"
    "VSCodeCookies" = Join-Path $env:APPDATA "Code\Cookies"
    "VSCodeCookiesJournal" = Join-Path $env:APPDATA "Code\Cookies-journal"
    "VSCodeNetwork" = Join-Path $env:APPDATA "Code\Network"
    "VSCodeLocalStorage" = Join-Path $env:APPDATA "Code\Local Storage"
}

# 确认是否继续
Write-Host "警告: 此脚本将直接清除 VS Code 的用户配置文件，不会创建备份，此操作不可逆！" -ForegroundColor Red
Write-Host "配置文件位置: $vscodeUserDataPath" -ForegroundColor Cyan
$confirmation = Read-Host "是否继续? (Y/N)"

if ($confirmation -ne "Y" -and $confirmation -ne "y") {
    Write-Host "操作已取消。" -ForegroundColor Green
    exit
}

# 直接清除文件
foreach ($file in $configFiles) {
    $srcPath = Join-Path $vscodeUserDataPath $file
    
    if (Test-Path $srcPath) {
        # 清除文件或目录
        if (Test-Path $srcPath -PathType Container) {
            Remove-Item -Path $srcPath -Recurse -Force
            Write-Host "已清除目录: $file" -ForegroundColor Yellow
        } else {
            Remove-Item -Path $srcPath -Force
            Write-Host "已清除文件: $file" -ForegroundColor Yellow
        }
    } else {
        Write-Host "文件或目录不存在: $file" -ForegroundColor DarkYellow
    }
}

# 清除目录
foreach ($dir in $configDirectories) {
    $srcPath = Join-Path $vscodeUserDataPath $dir
    
    if (Test-Path $srcPath) {
        Remove-Item -Path $srcPath -Recurse -Force
        Write-Host "已清除目录: $dir" -ForegroundColor Yellow
    } else {
        Write-Host "目录不存在: $dir" -ForegroundColor DarkYellow
    }
}

# 处理扩展
$confirmExtensions = Read-Host "是否同时清除已安装的 VS Code 扩展? (Y/N)"
if ($confirmExtensions -eq "Y" -or $confirmExtensions -eq "y") {
    $extensionsDir = Join-Path $env:USERPROFILE ".vscode\extensions"
    
    if (Test-Path $extensionsDir) {
        Remove-Item -Path $extensionsDir -Recurse -Force
        Write-Host "已清除扩展目录" -ForegroundColor Yellow
    } else {
        Write-Host "扩展目录不存在" -ForegroundColor DarkYellow
    }
}

# 处理 GitHub Copilot 配置
$confirmCopilot = Read-Host "是否清除 GitHub Copilot 的配置、缓存和登录验证信息? (Y/N)"
if ($confirmCopilot -eq "Y" -or $confirmCopilot -eq "y") {
    foreach ($key in $copilotPaths.Keys) {
        $path = $copilotPaths[$key]
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "已清除 GitHub Copilot 相关文件: $key" -ForegroundColor Yellow
        } else {
            Write-Host "GitHub Copilot 相关路径不存在: $key" -ForegroundColor DarkYellow
        }
    }
    
    # 清理特定的 Copilot 缓存目录（可能在不同位置）
    $copilotExtIds = @("github.copilot", "github.copilot-chat", "github.vscode-pull-request-github")
    foreach ($extId in $copilotExtIds) {
        $extensionStoragePath = Join-Path $env:APPDATA "Code\User\globalStorage\$extId"
        if (Test-Path $extensionStoragePath) {
            Remove-Item -Path $extensionStoragePath -Recurse -Force
            Write-Host "已清除 Copilot/GitHub 相关扩展存储: $extId" -ForegroundColor Yellow
        }
    }
    
    # 清理 Windows 凭据管理器中的 GitHub Copilot 凭据
    Write-Host "尝试清除 Windows 凭据管理器中的 GitHub Copilot 相关凭据..." -ForegroundColor Cyan
    
    try {
        # 尝试使用 cmdkey 列出并删除凭据
        $credentials = & cmdkey /list | Select-String -Pattern "github|copilot" -Context 0,1
        
        if ($credentials) {
            foreach ($cred in $credentials) {
                if ($cred.Line -match "Target:\s*(.+)") {
                    $target = $matches[1].Trim()
                    # 删除匹配的凭据
                    & cmdkey /delete:$target
                    Write-Host "已移除凭据: $target" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "未找到 GitHub 相关凭据" -ForegroundColor DarkYellow
        }
    } catch {
        Write-Host "清除 Windows 凭据管理器中的 GitHub 凭据时出错: $_" -ForegroundColor Red
    }
    
    # 清理 VS Code 设置中的 Copilot 令牌和配置
    $settingsPath = Join-Path $env:APPDATA "Code\User\settings.json"
    if (Test-Path $settingsPath) {
        try {
            $settingsContent = Get-Content -Path $settingsPath -Raw
            $settings = ConvertFrom-Json $settingsContent -ErrorAction SilentlyContinue
            
            # 检查是否有 Copilot 相关设置
            $hasCopilotSettings = $false
            
            # 获取所有 github.copilot 开头的属性
            $copilotProps = $settings.PSObject.Properties | Where-Object { $_.Name -like "github.copilot*" }
            
            if ($copilotProps -and $copilotProps.Count -gt 0) {
                Write-Host "settings.json 中找到 Copilot 配置项:" -ForegroundColor Yellow
                foreach ($prop in $copilotProps) {
                    Write-Host " - $($prop.Name)" -ForegroundColor Yellow
                    $settings.PSObject.Properties.Remove($prop.Name)
                    $hasCopilotSettings = $true
                }
                
                if ($hasCopilotSettings) {
                    # 将更改写回文件
                    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath
                    Write-Host "已从 settings.json 中移除 Copilot 配置" -ForegroundColor Yellow
                }
            } else {
                Write-Host "未在 settings.json 中找到 Copilot 配置" -ForegroundColor DarkYellow
            }
        } catch {
            Write-Host "处理 settings.json 时出错: $_" -ForegroundColor Red
        }
    }
    
    # 清理 VS Code 状态存储
    $stateStoragePath = Join-Path $env:APPDATA "Code\User\globalState.json"
    if (Test-Path $stateStoragePath) {
        try {
            $stateContent = Get-Content -Path $stateStoragePath -Raw
            $state = ConvertFrom-Json $stateContent -ErrorAction SilentlyContinue
            
            if ($state -and $state.storage) {
                # 查找并删除 Copilot 和 GitHub 相关状态
                $copilotStateKeys = $state.storage.PSObject.Properties |
                    Where-Object { $_.Name -like "*github*" -or $_.Name -like "*copilot*" } |
                    ForEach-Object { $_.Name }
                
                if ($copilotStateKeys -and $copilotStateKeys.Count -gt 0) {
                    foreach ($key in $copilotStateKeys) {
                        $state.storage.PSObject.Properties.Remove($key)
                        Write-Host "已从 VS Code 状态存储中移除: $key" -ForegroundColor Yellow
                    }
                    
                    # 将更改写回文件
                    $state | ConvertTo-Json -Depth 10 -Compress | Set-Content -Path $stateStoragePath
                } else {
                    Write-Host "未在 VS Code 状态存储中找到 GitHub/Copilot 相关条目" -ForegroundColor DarkYellow
                }
            }
        } catch {
            Write-Host "处理 globalState.json 时出错: $_" -ForegroundColor Red
        }
    }
}

# 清理备份文件夹（如果存在）
$backupPattern = Join-Path $env:USERPROFILE "vscode_config_backup_*"
$backupFolders = Get-ChildItem -Path $backupPattern -Directory -ErrorAction SilentlyContinue

if ($backupFolders) {
    $confirmBackupCleanup = Read-Host "发现 VS Code 配置备份文件夹，是否一并清除? (Y/N)"
    if ($confirmBackupCleanup -eq "Y" -or $confirmBackupCleanup -eq "y") {
        foreach ($folder in $backupFolders) {
            Remove-Item -Path $folder.FullName -Recurse -Force
            Write-Host "已清除备份文件夹: $($folder.Name)" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n操作完成！" -ForegroundColor Green
Write-Host "所有 VS Code 配置文件已清除。" -ForegroundColor Cyan
Write-Host "下次启动 VS Code 时将使用默认配置。" -ForegroundColor Cyan
