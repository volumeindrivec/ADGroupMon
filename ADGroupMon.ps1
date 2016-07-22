param(
    $AlertFrom,
    [string[]]$AlertTo,
    $AlertSmtpServer,
    [string[]]$Groups = 'Domain Admins',
    $CheckInterval = 15,
    $FilePath = "$env:HOMEDRIVE\Logs"
)


function Write-Log{
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true)]$Message,
        $LogPath = "$env:HOMEDRIVE\Logs",
        $LogFile = "$(Split-Path $MyInvocation.ScriptName -Leaf)-$(Get-Date -Format yyyy-MM-dd).log"
    )
    
    if ( -not (Test-Path -Path $LogPath) ){ 
        Write-Output "Path does not exist.  Creating $LogPath"
        New-Item -Path $LogPath -ItemType Directory
    } # End If statement

    Out-File -FilePath $LogPath\$LogFile -Append -NoClobber -InputObject ((Get-Date -Format s) + " - $Message" )
}

Import-Module ActiveDirectory

$x = $true

$Domain = (Get-ADDomain).Name
$AlertProperties = @{
    'From' = $AlertFrom
    'To' = $AlertTo
    'SmtpServer' = $AlertSmtpServer
    'Priority' = 'High'
}

if ( -not (Test-Path -Path $FilePath) ){
    New-Item -Path $FilePath -ItemType Directory
    $Message = "Path does not exist.  Creating $FilePath"
    Write-Output "$(Get-Date -Format G) - $Message"
    Write-Log -Message $Message
} # End If statement

while ($x){
    
    foreach ($Group in $Groups){

        (Get-ADGroup -Identity $Group | Get-ADGroupMember).Name | Out-File "$FilePath\$Group.members.txt"
    
        if (Test-Path "$FilePath\$Group.prevmembers.txt"){
            $Comparison = Compare-Object -ReferenceObject (Get-Content "$FilePath\$Group.prevmembers.txt") -DifferenceObject (Get-Content "$FilePath\$Group.members.txt")

            if ( $Comparison ){
                if ($Comparison.SideIndicator -eq '=>'){
                    $Message = "User $($Comparison.InputObject) was ADDED to the $Group group in the $Domain domain."
                    Write-Log -Message $Message
                    Send-MailMessage @AlertProperties -Subject "$Group has been changed!" -Body $Message
                    Write-Output "$(Get-Date -Format G) - $Message"
                }
                elseif ($Comparison.SideIndicator -eq '<='){
                    $Message = "User $($Comparison.InputObject) was REMOVED from the $Group group in the $Domain domain."
                    Write-Log -Message $Message
                    Send-MailMessage @AlertProperties -Subject "$Group has been changed!" -Body $Message
                    Write-Output "$(Get-Date -Format G) - $Message"
                }
            } 
            else {
                $Message = "NO changes detected in $Group group in the $Domain domain."
                #Write-Log -Message $Message
                Write-Output "$(Get-Date -Format G) - $Message" 
            }        
        }

        Copy-Item -Path "$FilePath\$Group.members.txt" -Destination "$FilePath\$Group.prevmembers.txt"
    }
    

    Start-Sleep -Seconds $CheckInterval

}

