param($scaling)


$spPassword = ConvertTo-SecureString -String $env:SQL_ELASTIC_SCALE_SP_PASS -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $env:SQL_ELASTIC_SCALE_SP_ID, $spPassword
$SubscriptionId = $env:SQL_POOL_SUBSCRIPTION_ID
$resourceGroupName = $env:SQL_POOL_RESOURCE_GROUP_NAME
$poolName = $env:SQL_POOL_NAME
$serverName = $env:SQL_SERVER_NAME

"SQL Elastic $poolName is scaling $scaling!"

# Connect to the Azure service principal
Connect-AzAccount -ServicePrincipal -Credential $Credential -Tenant $env:TENANT_ID | Out-null
Set-AzContext -SubscriptionId $subscriptionId | Out-null


# Get current max DTU percentage Average in 5 minutes

$metricvalue = Get-Azmetric -ResourceId "/subscriptions/$($(Get-AzContext).Subscription.Id)/resourceGroups/$resourceGroupName/providers/Microsoft.Sql/servers/$serverName/elasticPools/$poolName" -TimeGrain 00:05:00 -MetricNames "dtu_consumption_percent" -DetailedOutput -AggregationType Average
$dtuPercentage = ($metricvalue.Data.average | Measure-Object -Maximum).Maximum
"DTU percentage is $dtuPercentage%"

$currentDTU = (Get-AzSqlElasticPool -ResourceGroupName $resourceGroupName -ServerName $serverName).DTU

"Current DTU of $poolName is $currentDTU"

#check scaling parameters

$maxDtuRange = [int]::Parse($env:MAX_DTU_RANGE)
$minDtuRange = [int]::Parse($env:MIN_DTU_RANGE)
$scaleMargin = [int]::Parse($env:SCALE_MARGIN)
$scaleDtu = $currentDTU*($dtuPercentage/100) + $scaleMargin
"True Scale DTU of $poolName will be $scaleDtu"
$standardEditionDtuArray = 50,100,200,300,400,800,1200,1600,2000,2500,3000
$scaleStatus = "Unknown"
$standardEditionDtu =0
#find position of the scale dtu
$standardEditionDtuArray += $scaleDtu
$standardEditionDtuArray = $standardEditionDtuArray | Sort-Object
$standardEditionDtuIndex = [array]::IndexOf($standardEditionDtuArray,$scaleDtu)

#scale up
if ( ($scaling -match "up" ) -and ($scaleDtu -ge $currentDTU))
{
  if($standardEditionDtuIndex+1 -le $standardEditionDtuArray.length){
  
  $standardEditionDtu = $standardEditionDtuArray[$standardEditionDtuIndex+1]
  if(($standardEditionDtu -ge $maxDtuRange) -and ($standardEditionDtuArray.Contains($maxDtuRange))){ 
    $standardEditionDtu = $maxDtuRange
  }
  "Dtu of $poolName will set to $standardEditionDtu"
  $scaleStatus = (Set-AzSqlElasticPool -ResourceGroupName $resourceGroupName -ServerName $serverName -ElasticPoolName $poolName -Dtu $standardEditionDtu -DatabaseDtuMax $standardEditionDtu).State
}
else {
  "Can't scale, Dtu is out of range!"
}
#scale down
}elseif ( ($scaling -match "down") -and ($scaleDtu -le $currentDTU) ){
  if($standardEditionDtuIndex-1 -ge 0){
    $standardEditionDtu = $standardEditionDtuArray[$standardEditionDtuIndex-1]
    if(($standardEditionDtu -le $minDtuRange) -and ($standardEditionDtuArray.Contains($minDtuRange))){
     $standardEditionDtu = $minDtuRange
    }
    "Dtu of $poolName will set to $standardEditionDtu"
    $scaleStatus = (Set-AzSqlElasticPool -ResourceGroupName $resourceGroupName -ServerName $serverName -ElasticPoolName $poolName -Dtu $standardEditionDtu -DatabaseDtuMax $standardEditionDtu).State
  }
  else {
    "Can't scale, Dtu is out of range!"
  }
}
#Can't scale
else{
    "Unknown action, the pool didn't scale"
}


$afterScaleDTU = (Get-AzSqlElasticPool -ResourceGroupName $resourceGroupName -ServerName $serverName).DTU

"Dtu of $poolName is set to $afterScaleDTU"
"The scale is $scaleStatus"


