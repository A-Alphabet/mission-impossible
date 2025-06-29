function Test-PortAvailable {
    param(
        [int]$Port
    )
    
    try {
        $tcpListener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
        $tcpListener.Start()
        $tcpListener.Stop()
        return $true
    }
    catch {
        return $false
    }
}

function Get-ProcessUsingPort {
    param(
        [int]$Port
    )
    
    try {
        $netstat = netstat -ano | Where-Object { $_ -match ":${Port}\s" }
        if ($netstat) {
            $pid = ($netstat -split '\s+')[-1]
            $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
            return $process
        }
    }
    catch {
        return $null
    }
    return $null
}

function Show-PortConflictInstructions {
    param(
        [int]$Port,
        [System.Diagnostics.Process]$Process
    )
    
    Write-Host "⚠️  PORT CONFLICT DETECTED" -ForegroundColor Red
    Write-Host "Port ${Port} is currently in use" -ForegroundColor Yellow
    
    if ($Process) {
        Write-Host "Process using port ${Port}:" -ForegroundColor Cyan
        Write-Host "  Name: $($Process.ProcessName)" -ForegroundColor White
        Write-Host "  PID: $($Process.Id)" -ForegroundColor White
        Write-Host "  Path: $($Process.Path)" -ForegroundColor White
        Write-Host ""
        
        Write-Host "To resolve this conflict, you can:" -ForegroundColor Green
        Write-Host "1. Stop the process manually:" -ForegroundColor White
        Write-Host "   taskkill /PID $($Process.Id) /F" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. Or if it's a development server, stop it gracefully (Ctrl+C in its terminal)" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "Unable to identify the process using port ${Port}" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To resolve this conflict:" -ForegroundColor Green
        Write-Host "1. Find processes using the port:" -ForegroundColor White
        Write-Host "   netstat -ano | findstr :${Port}" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. Stop the process using its PID:" -ForegroundColor White
        Write-Host "   taskkill /PID <PID> /F" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "3. Alternatively, you can configure your application to use different ports" -ForegroundColor White
    Write-Host ""
}

# Main execution
Write-Host "🔍 Checking port availability..." -ForegroundColor Cyan
Write-Host ""

$requiredPorts = @(3001, 5173)
$conflictFound = $false

foreach ($port in $requiredPorts) {
    Write-Host "Checking port ${port}..." -ForegroundColor White
    
    if (Test-PortAvailable -Port $port) {
        Write-Host "✅ Port ${port} is available" -ForegroundColor Green
    } else {
        $conflictFound = $true
        $process = Get-ProcessUsingPort -Port $port
        Show-PortConflictInstructions -Port $port -Process $process
    }
    Write-Host ""
}

if ($conflictFound) {
    Write-Host "❌ Port conflicts detected. Please resolve the conflicts above before starting the application." -ForegroundColor Red
    Write-Host ""
    Write-Host "After resolving conflicts, run this script again to verify ports are free." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "✅ All required ports (3001, 5173) are available!" -ForegroundColor Green
    Write-Host "You can now start your application safely." -ForegroundColor White
    exit 0
}
