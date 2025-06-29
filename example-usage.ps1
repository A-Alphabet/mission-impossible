# Example Usage of Helper Functions
# This script demonstrates how to use the helper functions

# First, dot-source the helper functions
. .\helpers.ps1

# Example 1: Status and Error logging
Write-Status "Starting deployment process..."
Write-Status "Checking prerequisites..." -Color Yellow

# Example 2: Port availability checking
if (Test-PortAvailable -Port 3000) {
    Write-Status "Port 3000 is available for frontend"
} else {
    Write-Error "Port 3000 is already in use"
}

if (Test-PortAvailable -Port 3001) {
    Write-Status "Port 3001 is available for backend"
} else {
    Write-Error "Port 3001 is already in use"
}

# Example 3: Command existence checking
if (Test-CommandExists -Command "npm") {
    Write-Status "npm is available"
} else {
    Write-Error "npm is not installed or not in PATH"
}

if (Test-CommandExists -Command "node") {
    Write-Status "Node.js is available"
} else {
    Write-Error "Node.js is not installed or not in PATH"
}

# Example 4: Start a process in background (commented out for safety)
# $frontendProcess = Start-ProcessAndLog -FilePath "npm" -ArgumentList @("run", "dev") -Background -LogPrefix "Frontend"
# if ($frontendProcess) {
#     Write-Status "Frontend started successfully with PID: $($frontendProcess.Id)"
#     
#     # Wait for the port to become available
#     if (Wait-PortListening -Port 5173 -TimeoutSeconds 30) {
#         Write-Status "Frontend is now accessible at http://localhost:5173"
#     }
# }

# Example 5: Check what process is using a port (if any)
$processInfo = Get-ProcessByPort -Port 80
if ($processInfo) {
    Write-Status "Port 80 is being used by: $($processInfo.ProcessName) (PID: $($processInfo.ProcessId))"
} else {
    Write-Status "Port 80 is not in use"
}

Write-Status "Example completed successfully!"
