param($Context)

$output = @()

$output += Invoke-DurableActivity -FunctionName 'SQLPoolScale' -Input $Context.Input

$output
