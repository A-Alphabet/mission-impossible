# PowerShell Helper Functions for Deployment and Process Management
# This script contains reusable utility functions for cleaner deployment logic

#region Status and Logging Functions

function Write-Status {
    <#
    .SYNOPSIS
    Writes status messages with timestamp and formatting
    
    .PARAMETER Message
    The status message to display
    
    .PARAMETER Color
    The console color for the message (default: Green)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$Color = [ConsoleColor]::Green
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [INFO] $Message" -ForegroundColor $Color
}

function Write-Error {
    <#
    .SYNOPSIS
    Writes error messages with timestamp and formatting
    
    .PARAMETER Message
    The error message to display
    
    .PARAMETER Exception
    Optional exception object to include details
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [System.Exception]$Exception = $null
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [ERROR] $Message" -ForegroundColor Red
    
    if ($Exception) {
        Write-Host "Exception Details: $($Exception.Message)" -ForegroundColor Red
        if ($Exception.InnerException) {
            Write-Host "Inner Exception: $($Exception.InnerException.Message)" -ForegroundColor Red
        }
    }
}

#endregion

#region Port Management Functions

function Test-PortAvailable {
    <#
    .SYNOPSIS
    Tests if a specific port is available on localhost
    
    .PARAMETER Port
    The port number to test
    
    .PARAMETER Protocol
    The protocol to test (TCP or UDP, default: TCP)
    
    .RETURNS
    $true if port is available, $false if in use
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("TCP", "UDP")]
        [string]$Protocol = "TCP"
    )
    
    try {
        if ($Protocol -eq "TCP") {
            $tcpListener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
            $tcpListener.Start()
            $tcpListener.Stop()
            return $true
        }
        else {
            $udpClient = New-Object System.Net.Sockets.UdpClient($Port)
            $udpClient.Close()
            return $true
        }
    }
    catch {
        return $false
    }
}

function Wait-PortListening {
    <#
    .SYNOPSIS
    Waits for a port to become available (listening) on localhost
    
    .PARAMETER Port
    The port number to wait for
    
    .PARAMETER TimeoutSeconds
    Maximum time to wait in seconds (default: 30)
    
    .PARAMETER IntervalSeconds
    Interval between checks in seconds (default: 1)
    
    .RETURNS
    $true if port becomes available within timeout, $false otherwise
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30,
        
        [Parameter(Mandatory = $false)]
        [int]$IntervalSeconds = 1
    )
    
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($TimeoutSeconds)
    
    Write-Status "Waiting for port $Port to become available (timeout: ${TimeoutSeconds}s)..."
    
    while ((Get-Date) -lt $endTime) {
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connection = $tcpClient.BeginConnect("localhost", $Port, $null, $null)
            $success = $connection.AsyncWaitHandle.WaitOne(1000, $false)
            
            if ($success) {
                $tcpClient.EndConnect($connection)
                $tcpClient.Close()
                Write-Status "Port $Port is now listening!"
                return $true
            }
            
            $tcpClient.Close()
        }
        catch {
            # Port not yet available, continue waiting
        }
        
        Start-Sleep -Seconds $IntervalSeconds
    }
    
    Write-Error "Timeout waiting for port $Port to become available"
    return $false
}

#endregion

#region Process Management Functions

function Start-ProcessAndLog {
    <#
    .SYNOPSIS
    Starts a process with logging and optional background execution
    
    .PARAMETER FilePath
    Path to the executable
    
    .PARAMETER ArgumentList
    Arguments to pass to the process
    
    .PARAMETER WorkingDirectory
    Working directory for the process
    
    .PARAMETER Background
    Whether to run in background (non-blocking)
    
    .PARAMETER LogPrefix
    Prefix for log messages
    
    .RETURNS
    Process object if successful, $null otherwise
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [string[]]$ArgumentList = @(),
        
        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory = (Get-Location).Path,
        
        [Parameter(Mandatory = $false)]
        [switch]$Background,
        
        [Parameter(Mandatory = $false)]
        [string]$LogPrefix = "Process"
    )
    
    try {
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = $FilePath
        $processStartInfo.WorkingDirectory = $WorkingDirectory
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.CreateNoWindow = $true
        
        if ($ArgumentList.Count -gt 0) {
            $processStartInfo.Arguments = $ArgumentList -join " "
        }
        
        Write-Status "$LogPrefix - Starting: $FilePath $($processStartInfo.Arguments)"
        Write-Status "$LogPrefix - Working Directory: $WorkingDirectory"
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        $process.EnableRaisingEvents = $true
        
        # Event handlers for output
        $outputHandler = {
            if (-not [string]::IsNullOrEmpty($Event.SourceEventArgs.Data)) {
                Write-Host "[$LogPrefix] [OUT] $($Event.SourceEventArgs.Data)" -ForegroundColor Cyan
            }
        }
        
        $errorHandler = {
            if (-not [string]::IsNullOrEmpty($Event.SourceEventArgs.Data)) {
                Write-Host "[$LogPrefix] [ERR] $($Event.SourceEventArgs.Data)" -ForegroundColor Yellow
            }
        }
        
        Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action $outputHandler | Out-Null
        Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action $errorHandler | Out-Null
        
        $success = $process.Start()
        
        if ($success) {
            $process.BeginOutputReadLine()
            $process.BeginErrorReadLine()
            
            Write-Status "$LogPrefix - Started successfully (PID: $($process.Id))"
            
            if (-not $Background) {
                Write-Status "$LogPrefix - Waiting for completion..."
                $process.WaitForExit()
                Write-Status "$LogPrefix - Completed with exit code: $($process.ExitCode)"
                
                if ($process.ExitCode -ne 0) {
                    Write-Error "$LogPrefix - Process failed with exit code: $($process.ExitCode)"
                }
            }
            
            return $process
        }
        else {
            Write-Error "$LogPrefix - Failed to start process"
            return $null
        }
    }
    catch {
        Write-Error "$LogPrefix - Exception starting process" -Exception $_.Exception
        return $null
    }
}

function Start-ProcessWithStatus {
    <#
    .SYNOPSIS
    Starts a PowerShell process with specified working directory and command line arguments
    
    .PARAMETER WorkingDirectory
    The working directory for the process
    
    .PARAMETER ArgumentList
    Array of command line arguments to pass to PowerShell
    
    .RETURNS
    Process object if successful, $null on failure
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,
        
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList
    )
    
    try {
        # Validate working directory exists
        if (-not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) {
            Write-Error "Working directory does not exist: $WorkingDirectory"
            return $null
        }
        
        Write-Status "Starting PowerShell process..."
        Write-Status "Working Directory: $WorkingDirectory"
        Write-Status "Arguments: $($ArgumentList -join ' ')"
        
        # Start the process using Start-Process
        $process = Start-Process -FilePath "powershell.exe" `
                                -ArgumentList $ArgumentList `
                                -WorkingDirectory $WorkingDirectory `
                                -WindowStyle Normal `
                                -PassThru
        
        if ($process) {
            Write-Status "PowerShell process started successfully (PID: $($process.Id))"
            return $process
        }
        else {
            Write-Error "Failed to start PowerShell process - Start-Process returned null"
            return $null
        }
    }
    catch {
        Write-Error "Exception occurred while starting PowerShell process: $($_.Exception.Message)" -Exception $_.Exception
        return $null
    }
}

function Stop-ChildProcesses {
    <#
    .SYNOPSIS
    Stops all child processes of the current process or specified process
    
    .PARAMETER ParentProcessId
    Parent process ID (default: current process)
    
    .PARAMETER Force
    Whether to force kill processes
    
    .PARAMETER Recursive
    Whether to recursively stop all descendants
    #>
    param(
        [Parameter(Mandatory = $false)]
        [int]$ParentProcessId = $PID,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        
        [Parameter(Mandatory = $false)]
        [switch]$Recursive
    )
    
    try {
        Write-Status "Stopping child processes of PID $ParentProcessId..."
        
        # Get all processes
        $allProcesses = Get-WmiObject -Class Win32_Process
        
        # Find child processes
        $childProcesses = $allProcesses | Where-Object { $_.ParentProcessId -eq $ParentProcessId }
        
        if ($childProcesses.Count -eq 0) {
            Write-Status "No child processes found for PID $ParentProcessId"
            return
        }
        
        Write-Status "Found $($childProcesses.Count) child process(es)"
        
        foreach ($childProcess in $childProcesses) {
            try {
                $processId = $childProcess.ProcessId
                $processName = $childProcess.Name
                
                Write-Status "Stopping process: $processName (PID: $processId)"
                
                if ($Recursive) {
                    # Recursively stop grandchildren first
                    Stop-ChildProcesses -ParentProcessId $processId -Force:$Force -Recursive
                }
                
                if ($Force) {
                    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                }
                else {
                    Stop-Process -Id $processId -ErrorAction SilentlyContinue
                }
                
                # Wait a moment for graceful shutdown
                Start-Sleep -Milliseconds 500
                
                # Check if process still exists
                $stillRunning = Get-Process -Id $processId -ErrorAction SilentlyContinue
                if ($stillRunning) {
                    Write-Status "Force stopping stubborn process: $processName (PID: $processId)"
                    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                }
                else {
                    Write-Status "Successfully stopped: $processName (PID: $processId)"
                }
            }
            catch {
                Write-Error "Failed to stop process $($childProcess.Name) (PID: $($childProcess.ProcessId))" -Exception $_.Exception
            }
        }
        
        Write-Status "Child process cleanup completed"
    }
    catch {
        Write-Error "Failed to stop child processes" -Exception $_.Exception
    }
}

function Stop-MissionImpossible {
    <#
    .SYNOPSIS
    Stops the Mission Impossible backend and frontend processes gracefully
    
    .PARAMETER BackendProcess
    The backend process object to stop
    
    .PARAMETER FrontendProcess
    The frontend process object to stop
    
    .DESCRIPTION
    This function checks if the provided backend and frontend processes are still running
    and stops them using Stop-Process with the -Force parameter for reliable termination.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [System.Diagnostics.Process]$BackendProcess = $null,
        
        [Parameter(Mandatory = $false)]
        [System.Diagnostics.Process]$FrontendProcess = $null
    )
    
    Write-Status "Initiating Mission Impossible shutdown sequence..." -Color Yellow
    
    $processesStoppedCount = 0
    
    # Stop Backend Process
    if ($BackendProcess -and -not $BackendProcess.HasExited) {
        try {
            Write-Status "Stopping backend process (PID: $($BackendProcess.Id))..."
            Stop-Process -Id $BackendProcess.Id -Force -ErrorAction Stop
            
            # Wait a moment and verify it's stopped
            Start-Sleep -Milliseconds 1000
            
            if ($BackendProcess.HasExited) {
                Write-Status "Backend process stopped successfully" -Color Green
                $processesStoppedCount++
            }
            else {
                Write-Status "Backend process may still be running" -Color Yellow
            }
        }
        catch {
            Write-Error "Failed to stop backend process (PID: $($BackendProcess.Id))" -Exception $_.Exception
        }
    }
    elseif ($BackendProcess -and $BackendProcess.HasExited) {
        Write-Status "Backend process has already exited" -Color Cyan
    }
    else {
        Write-Status "No backend process to stop" -Color Cyan
    }
    
    # Stop Frontend Process
    if ($FrontendProcess -and -not $FrontendProcess.HasExited) {
        try {
            Write-Status "Stopping frontend process (PID: $($FrontendProcess.Id))..."
            Stop-Process -Id $FrontendProcess.Id -Force -ErrorAction Stop
            
            # Wait a moment and verify it's stopped
            Start-Sleep -Milliseconds 1000
            
            if ($FrontendProcess.HasExited) {
                Write-Status "Frontend process stopped successfully" -Color Green
                $processesStoppedCount++
            }
            else {
                Write-Status "Frontend process may still be running" -Color Yellow
            }
        }
        catch {
            Write-Error "Failed to stop frontend process (PID: $($FrontendProcess.Id))" -Exception $_.Exception
        }
    }
    elseif ($FrontendProcess -and $FrontendProcess.HasExited) {
        Write-Status "Frontend process has already exited" -Color Cyan
    }
    else {
        Write-Status "No frontend process to stop" -Color Cyan
    }
    
    # Summary
    if ($processesStoppedCount -gt 0) {
        Write-Status "Successfully stopped $processesStoppedCount process(es)" -Color Green
    }
    else {
        Write-Status "No processes were actively stopped" -Color Cyan
    }
    
    Write-Status "Mission Impossible shutdown sequence completed" -Color Yellow
}

#endregion

#region Utility Functions

function Get-ProcessByPort {
    <#
    .SYNOPSIS
    Gets the process that is using a specific port
    
    .PARAMETER Port
    The port number to check
    
    .RETURNS
    Process information if found, $null otherwise
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port
    )
    
    try {
        $netstatOutput = netstat -ano | Select-String ":$Port "
        
        if ($netstatOutput) {
            $line = $netstatOutput[0].Line
            $columns = $line -split '\s+' | Where-Object { $_ -ne '' }
            
            if ($columns.Count -ge 5) {
                $processId = [int]$columns[4]
                $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
                
                if ($process) {
                    return @{
                        Process = $process
                        ProcessId = $processId
                        ProcessName = $process.ProcessName
                        Port = $Port
                    }
                }
            }
        }
        
        return $null
    }
    catch {
        Write-Error "Failed to get process for port $Port" -Exception $_.Exception
        return $null
    }
}

function Test-CommandExists {
    <#
    .SYNOPSIS
    Tests if a command exists in the current environment
    
    .PARAMETER Command
    The command name to test
    
    .RETURNS
    $true if command exists, $false otherwise
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )
    
    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

#endregion

# Functions are available when dot-sourced
# (Export-ModuleMember is not needed for dot-sourcing)

# Example usage at the end of the script
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    Write-Status "Helper functions loaded successfully!"
    Write-Status "Available functions:"
    Write-Host "  - Write-Status / Write-Error" -ForegroundColor White
    Write-Host "  - Test-PortAvailable" -ForegroundColor White
    Write-Host "  - Wait-PortListening" -ForegroundColor White
    Write-Host "  - Start-ProcessAndLog" -ForegroundColor White
    Write-Host "  - Stop-ChildProcesses" -ForegroundColor White
    Write-Host "  - Get-ProcessByPort" -ForegroundColor White
    Write-Host "  - Test-CommandExists" -ForegroundColor White
}
