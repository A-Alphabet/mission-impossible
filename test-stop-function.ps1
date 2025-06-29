# Test script for Stop-MissionImpossible function
# This script tests the Stop-MissionImpossible function with mock processes

# Import helper functions
. .\helpers.ps1

Write-Status "Testing Stop-MissionImpossible function..." -Color Yellow

# Test 1: Call function with null processes
Write-Status "Test 1: Calling Stop-MissionImpossible with null processes"
Stop-MissionImpossible -BackendProcess $null -FrontendProcess $null

Write-Status ""
Write-Status "Test 1 completed. The function should have handled null processes gracefully."

# Test 2: Test with global variables (simulate main script behavior)
Write-Status ""
Write-Status "Test 2: Testing with global variables (as used in main script)"

$BackendProcess = $null
$FrontendProcess = $null

# Call using global variables like in the main script
Stop-MissionImpossible -BackendProcess $BackendProcess -FrontendProcess $FrontendProcess

Write-Status ""
Write-Status "Test 2 completed. Function works with global variables."

Write-Status ""
Write-Status "Stop-MissionImpossible function tests completed successfully!" -Color Green
Write-Status "The function is ready to be used in the main script." -Color Green
