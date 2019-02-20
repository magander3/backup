 # Script to backup vCenter Server Appliance Database
# Author: Magnus Andersson - Sr Staff Solutions Engineer @Nutanix
# Version 1.1
# Created 2018-02-18
#
#--------------------------------------------
# User Defined Variables Sections Starts Here
#
# Specify vCenter Server, vCenter Server User name and vCenter Server Password
$vcsa="vcenter.npx05.local"
$vcsauser="vcsabkpuser@vsphere.local"
$vcsapasswd="Secret!!11"
# 
# Backup location
$bkpserver="IP/vcsabackups/"
$bkpdir=get-date -uformat %Y-%m-%d
$bkpLocation=$bkpserver+$bkpdir
#
# Specify backup location user and password
$LocationUser="ftps-user"
$LocationPasswd="Secret!!11"
#
# Specify backup type where Fullbackup is 1 and Seatbackup is 2
$BackupType=2
#
# Specify backup password - needed when performing restore
$bkpPassword="Secret!!11"
#
# Specify backup localtion type where you must specify HTTP, HTTPS, SCP, FTP or FTPS
$LocationType="FTPS"
#
# Specify Backup Comment
$Comment="vCenter Server Appliance center.npx05.local backup"
#
# User Defined Variables Sections Ends Here
#--------------------------------------------
# 
#
# Define vCenter Server Appliance connection string
#$vcsa=$vcsaserver+":"+$vcsaport
#
# Import Module VMware.VimAutomation.Cis.Core
Import-module VMware.VimAutomation.Cis.Core
#
# #--------------------------------------------
# Import Backup-VCSAToFile Function Created By Brian Graf - https://www.brianjgraf.com/2016/11/18/vsphere-6-5-automate-vcsa-backup/
Function Backup-VCSAToFile {
    param (
        [Parameter(ParameterSetName=’FullBackup’)]
        [switch]$FullBackup,
        [Parameter(ParameterSetName=’SeatBackup’)]
        [switch]$SeatBackup,
        [ValidateSet('FTPS', 'HTTP', 'SCP', 'HTTPS', 'FTP')]
        $LocationType = "FTP",
        $Location,
        $LocationUser,
        [VMware.VimAutomation.Cis.Core.Types.V1.Secret]$LocationPassword,
        [VMware.VimAutomation.Cis.Core.Types.V1.Secret]$BackupPassword,
        $Comment = "Backup job",
        [switch]$ShowProgress
    )
    Begin {
        if (!($global:DefaultCisServers)){ 
            [System.Windows.Forms.MessageBox]::Show("It appears you have not created a connection to the CisServer. You will now be prompted to enter your vCenter credentials to continue" , "Connect to CisServer") | out-null
            $Connection = Connect-CisServer $global:DefaultVIServer 
        } else {
            $Connection = $global:DefaultCisServers
        }
        if ($FullBackup) {$parts = @("common","seat")}
        if ($SeatBackup) {$parts = @("seat")}
    }
    Process{
        $BackupAPI = Get-CisService com.vmware.appliance.recovery.backup.job
        $CreateSpec = $BackupAPI.Help.create.piece.CreateExample()
        $CreateSpec.parts = $parts
        $CreateSpec.backup_password = $BackupPassword
        $CreateSpec.location_type = $LocationType
        $CreateSpec.location = $Location
        $CreateSpec.location_user = $LocationUser
        $CreateSpec.location_password = $LocationPassword
        $CreateSpec.comment = $Comment
        try {
            $BackupJob = $BackupAPI.create($CreateSpec)
        }
        catch {
            Write-Error $Error[0].exception.Message
        }
            

        If ($ShowProgress){
            do {
                $BackupAPI.get("$($BackupJob.ID)") | select id, progress, state
                $progress = ($BackupAPI.get("$($BackupJob.ID)").progress)
                Write-Progress -Activity "Backing up VCSA"  -Status $BackupAPI.get("$($BackupJob.ID)").state -PercentComplete ($BackupAPI.get("$($BackupJob.ID)").progress) -CurrentOperation "$progress% Complete"
                start-sleep -seconds 5
            } until ($BackupAPI.get("$($BackupJob.ID)").progress -eq 100 -or $BackupAPI.get("$($BackupJob.ID)").state -ne "INPROGRESS")

            $BackupAPI.get("$($BackupJob.ID)") | select id, progress, state
        } 
        Else {
            $BackupJob | select id, progress, state
        }
    }
    End {}
}
#
# #--------------------------------------------
# Create passwords
[VMware.VimAutomation.Cis.Core.Types.V1.Secret]$BackupPassword=$bkpPassword
[VMware.VimAutomation.Cis.Core.Types.V1.Secret]$LocationPassword=$LocationPasswd
#
# Connect to vCenter Server Appliance
Connect-CisServer -Server $vcsa -User $vcsauser -Password $vcsapasswd 
#
# Start the backup
If ($BackupType -eq 1) {
	Backup-VCSAToFile -BackupPassword $BackupPassword -LocationType $LocationType -Location $bkpLocation -LocationUser $LocationUser -LocationPassword $locationPassword -Comment $Comment -Fulbackup ShowProgress
	}
	Else {
	Backup-VCSAToFile -BackupPassword $BackupPassword -LocationType $LocationType -Location $bkpLocation -LocationUser $LocationUser -LocationPassword $locationPassword -Comment $Comment -Seatbackup -ShowProgress
	}
#
# Disconnect from vCenter Server Appliance
disconnect-CisServer $vcsa -confirm:$false
#
