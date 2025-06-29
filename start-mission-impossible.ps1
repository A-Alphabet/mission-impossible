# ============================================================================
# start-mission-impossible.ps1
# ============================================================================
#
# PURPOSE:
#   Starts the Mission Impossible project by launching both backend and frontend
#   development servers. This script manages the lifecycle of both processes and
#   allows for clean shutdown when needed.
#
# USAGE:
#   .\start-mission-impossible.ps1
#
# REQUIRED PORTS:
#   - Port 3001: Backend server (API/Express server)
#   - Port 5173: Frontend server (Vite development server)
#
# NOTES:
#   Make sure both ports 3001 and 5173 are available before running this script.
#   The script will store process references to allow for proper cleanup.
#
# ============================================================================

# Global variables to store process objects for later cleanup
$BackendProcess = $null
$FrontendProcess = $null

# Import helper functions
. .\helpers.ps1

# Global variables for script success tracking
$ScriptSuccessful = $false
$ExitCode = 1

# Main script logic wrapped in comprehensive error handling
try {
    Write-Status "=== Mission Impossible Server Startup ===" -Color Yellow
    
    # Check required ports
    Write-Status "Checking port availability..."
    
    # Check backend port (3001)
    if (-not (Test-PortAvailable -Port 3001)) {
        Write-Error "Port 3001 is already in use. Please stop the process using this port and try again."
        $processInfo = Get-ProcessByPort -Port 3001
        if ($processInfo) {
            Write-Status "Port 3001 is being used by: $($processInfo.ProcessName) (PID: $($processInfo.ProcessId))"
        }
        throw "Port 3001 is not available"
    }
    
    # Check frontend port (5173)
    if (-not (Test-PortAvailable -Port 5173)) {
        Write-Error "Port 5173 is already in use. Please stop the process using this port and try again."
        $processInfo = Get-ProcessByPort -Port 5173
        if ($processInfo) {
            Write-Status "Port 5173 is being used by: $($processInfo.ProcessName) (PID: $($processInfo.ProcessId))"
        }
        throw "Port 5173 is not available"
    }
    
    Write-Status "Both ports 3001 and 5173 are available" -Color Green
    
    # Check if npm is available
    if (-not (Test-CommandExists -Command "npm")) {
        Write-Error "npm is not installed or not in PATH. Please install Node.js and npm first."
        throw "npm is not available"
    }
    
    Write-Status "npm is available" -Color Green
    
    # Start backend server (assuming server directory exists)
    if (Test-Path -Path "server" -PathType Container) {
        Write-Status "Starting backend server on port 3001..."
        $BackendProcess = Start-ProcessAndLog -FilePath "node" -ArgumentList @("server/index.js") -WorkingDirectory (Get-Location) -Background -LogPrefix "Backend"
        
        if ($BackendProcess) {
            Write-Status "Backend process started (PID: $($BackendProcess.Id))" -Color Green
        } else {
            Write-Error "Failed to start backend process"
            throw "Backend process failed to start"
        }
    } else {
        Write-Error "Server directory not found. Please ensure the server folder exists."
        throw "Server directory not found"
    }
    
    # Start frontend server (from root directory)
    if (Test-Path -Path "package.json" -PathType Leaf) {
        Write-Status "Starting frontend server on port 5173..."
        $FrontendProcess = Start-ProcessWithStatus -WorkingDirectory (Get-Location).Path -ArgumentList @("-Command", "npx vite")
        
        if ($FrontendProcess) {
            Write-Status "Frontend process started (PID: $($FrontendProcess.Id))" -Color Green
        } else {
            Write-Error "Failed to start frontend process"
            throw "Frontend process failed to start"
        }
    } else {
        Write-Error "package.json not found in root directory. Please ensure you're in the project root."
        throw "Frontend package.json not found"
    }
    
    # Wait for both servers to be ready
    Write-Status "Waiting for servers to start..."
    
    $backendReady = Wait-PortListening -Port 3001 -TimeoutSeconds 30
    if ($backendReady) {
        Write-Status "Backend server is ready at http://localhost:3001" -Color Green
    } else {
        Write-Error "Backend server failed to start within timeout"
        throw "Backend server startup timeout"
    }
    
    $frontendReady = Wait-PortListening -Port 5173 -TimeoutSeconds 30
    if ($frontendReady) {
        Write-Status "Frontend server is ready at http://localhost:5173" -Color Green
    } else {
        Write-Error "Frontend server failed to start within timeout"
        throw "Frontend server startup timeout"
    }
    
    if ($backendReady -and $frontendReady) {
        Write-Status "=== Mission Impossible servers are running! ===" -Color Green
        Write-Status "Backend: http://localhost:3001" -Color Cyan
        Write-Status "Frontend: http://localhost:5173" -Color Cyan
        Write-Host ""
        Write-Status "Both servers are running in the background."
        
        # Servers started successfully, now wait for user input
        Write-Host ""
        Write-Host "Press Enter to stop both servers..." -ForegroundColor Yellow
        $null = Read-Host
        
        # If we reach here, everything was successful
        $ScriptSuccessful = $true
        $ExitCode = 0
    } else {
        Write-Error "One or more servers failed to start properly"
        throw "Server startup validation failed"
    }
}
catch {
    Write-Error "An error occurred during script execution: $($_.Exception.Message)" -Exception $_.Exception
    $ScriptSuccessful = $false
    $ExitCode = 1
}
finally {
    # Always attempt to stop the Mission Impossible processes, regardless of success or failure
    Write-Status "Executing cleanup procedures..." -Color Yellow
    
    try {
        Stop-MissionImpossible -BackendProcess $BackendProcess -FrontendProcess $FrontendProcess
    }
    catch {
        Write-Error "Error during cleanup: $($_.Exception.Message)" -Exception $_.Exception
        # Ensure we exit with error code if cleanup fails
        if ($ExitCode -eq 0) {
            $ExitCode = 1
        }
    }
    
    # Final status message
    if ($ScriptSuccessful) {
        Write-Status "Script completed successfully." -Color Green
    } else {
        Write-Status "Script completed with errors." -Color Red
    }
    
    # Exit with appropriate code for CI/CD detection
    Write-Status "Exiting with code: $ExitCode" -Color $(if ($ExitCode -eq 0) { "Green" } else { "Red" })
    exit $ExitCode
}
