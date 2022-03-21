using namespace System.Net

param($Request, $TriggerMetadata)

$FunctionName = $Request.Params.FunctionName
$InstanceId = Start-DurableOrchestration -FunctionName $FunctionName -InputObject $Request.Params.Scaling
Write-Host "Started orchestration with ID = '$InstanceId'"

$Response = New-DurableOrchestrationCheckStatusResponse -Request $Request -InstanceId $InstanceId
Push-OutputBinding -Name Response -Value $Response
