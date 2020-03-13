#Read config file and fill $params
Write-host "Reading Config File..."
Get-Content "config.txt" | foreach-object -begin {$params=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $params.Add($k[0], $k[1]) } }


$SqlServer         = $params.Get_Item("SqlServer")
$SqlUser           = $params.Get_Item("SqlUser")
$connString        = $params.Get_Item("connString")
$SqlDbName         = $params.Get_Item("SqlDbName")
$ResourcegroupName = $params.Get_Item("ResourcegroupName")
$AdxServerName     = $params.Get_Item("AdxServerName")
$Location          = $params.Get_Item("Location")
$SqlUserName       = $params.Get_Item("SqlUserName")
$SqlPass           = $params.Get_Item("SqlPass")
$AdxDbName         = $params.Get_Item("AdxDbName")  
$subscriptionId    = (Get-AzContext).Subscription.id

New-AzResourceGroupDeployment -ResourceGroupName $ResourcegroupName -TemplateFile "template.json" -TemplateParameterFile "parameters.json"


# add Resource group
Write-host "Creating resource group..."
New-AzureRmResourceGroup -Name $ResourcegroupName -Location $Location

#Sql Server

# The ip address range that you want to allow to access your server 
# (leaving at 0.0.0.0 will prevent outside-of-azure connections to your DB)
$startIp = "0.0.0.0"
$endIp = "0.0.0.0"

# Show randomized variables
Write-host "Resource group name is" $ResourcegroupName 
Write-host "Password is" $SqlPass  
Write-host "Server name is" $SqlServer

cls

# Create a server with a system wide unique server name
$server = New-AzSqlServer -ResourceGroupName $ResourcegroupName `
    -ServerName $SqlServer `
    -Location $Location `
    -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SqlUser, $(ConvertTo-SecureString -String $SqlPass -AsPlainText -Force))


# Create a server firewall rule that allows access from the specified IP range
Write-host "Configuring firewall for primary logical server..."
$serverFirewallRule = New-AzSqlServerFirewallRule -ResourceGroupName $ResourcegroupName `
   -ServerName $SqlServer `
   -FirewallRuleName "AllowedIPs" -StartIpAddress $startIp -EndIpAddress $endIp
$serverFirewallRule

# Create Sql Db 
$database = New-AzSqlDatabase  -ResourceGroupName $ResourcegroupName `
    -ServerName $SqlServer `
    -DatabaseName $SqlDbName `
    -RequestedServiceObjectiveName "S0" `


#Build DB Objects
& sqlcmd -S $server.FullyQualifiedDomainName -U $SqlUser -P $SqlPass -d $database.DatabaseName -i "CreateSqlObjects.sql"

#fill Up MachineScoreEvents Table
& sqlcmd -S $server.FullyQualifiedDomainName -U $SqlUser -P $SqlPass -d $database.DatabaseName -Q "exec [dbo].[usp_FillMachineScoreEventsTbl]"


Install-Module -Name Az.Kusto -Confirm:$False -Force


New-AzKustoCluster -ResourceGroupName $ResourcegroupName -Name $AdxServerName -Location  $Location -Sku D13_v2 -Capacity 10