<#
.Synopsis
   Install SQL Server from ISO file
.DESCRIPTION
   
.EXAMPLE
   
.EXAMPLE
  $Credential = Get-Credential
  $ImagePath = "\\share\SQL Server 2014\sql_server_2014_enterprise.iso"
  $ConfigurationFile = "\\share\SQL Server 2014.ini"
  Install-SqlServer -ComputerName Target -Credential $Credential -ImagePath $ImagePath -ConfigurationFile $ConfigurationFile
   
#>
function Install-SqlServer
{
    [CmdletBinding()]
    
    Param
    (
        # ComputerName
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string[]]
        $ComputerName,

        # Setup Credential
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [pscredential]
        $Credential,
        
        # SQL Server Version
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [ValidateSet(
            "2014"
        )]
        [string]
        $Version = "2014",

        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=3)]
        [string]
        $ImagePath,

        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=4)]
        [string]
        $ConfigurationFile
    )

    Begin
    {

    }
    Process
    {
        $ComputerName|%{
            $cname = $_
            Invoke-Command -ComputerName $cname -Credential $Credential -Authentication Credssp -ScriptBlock{
                $Version = $args[0]
                $ImagePath = $args[1]
                $ConfigurationFile = $args[2]

                Write-Verbose "Install .NET Framework 3.5"
                $install_net_framework_core_result = Install-WindowsFeature -Name NET-Framework-Core -ErrorAction Stop
                if(!$install_net_framework_core_result.Success){
                    Write-Verbose "Failed to install .NET Framework 3.5"
                    return
                }
                Write-Verbose "Successfully Installed .NET Framework 3.5"

                Write-Verbose "Mouting Image path: $ImagePath"
                $image_volume = Mount-DiskImage -ImagePath $ImagePath -Access ReadOnly -PassThru | Get-Volume
                $setup_path = $image_volume.DriveLetter + ":\Setup.exe"
                Resolve-Path $setup_path,$ConfigurationFile -ErrorAction Stop
                & $setup_path /ConfigurationFile=$ConfigurationFile
                $version_number = 12
                $mssql_folder = "C:\Program Files\Microsoft SQL Server\MSSQL$version_number.MSSQLSERVER\MSSQL"
                $binary_path = $mssql_folder + "\Binn\sqlservr.exe" 
                $backup_folder = Join-Path $mssql_folder "Backup"
                Dismount-DiskImage $ImagePath
                Resolve-Path $binary_path -ErrorAction Stop
                New-NetFirewallRule -DisplayName "SQL Server $Version" -Action Allow -Direction Inbound -Profile Domain -Program $binary_path -Protocol TCP
            } -Argument @($Version, $ImagePath, $ConfigurationFile)# -AsJob
        }|Receive-Job -Wait
    }
    End
    {
    }
}