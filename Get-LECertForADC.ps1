<#
.SYNOPSIS
    Create a new or update an existing Let's Encrypt certificate for one or more domains and add it to a store then update the SSL bindings for a ADC
.DESCRIPTION
    The script will utilize Posh-ACME to create a new or update an existing certificate for one or more domains. If generated successfully the script will add the certificate to the ADC and update the SSL binding for a web site. This script is for use with a Citrix ADC (v11.x and up). The script will validate the dns records provided. For example, the domain(s) listed must be configured with the same IP Address that is configured (via NAT) to a Content Switch. Or Use DNS verification if a WildCard domain was specified.
.PARAMETER Help
    Display the detailed information about this script
.PARAMETER CleanADC
    Clean-up the ADC configuration made within this script, for when somewhere it gone wrong
.PARAMETER RemoveTestCertificates
    Remove all the Test/Staging certificates signed by the "Fake LE Intermediate X1" staging intermediate
.PARAMETER ManagementURL
    Management URL, used to connect to the ADC
.PARAMETER Username
    ADC Username with enough access to configure it
.PARAMETER Password
    ADC Username password
.PARAMETER Credential
    Use a PSCredential object instead of a Username or password. Use "Get-Credential" to generate a credential object
    C:\PS> $Credential = Get-Credential
.PARAMETER CsVipName
    Name of the HTTP ADC Content Switch used for the domain validation
.PARAMETER CsVipBinding
    ADC Content Switch binding used for the validation
    Default: 11
.PARAMETER SvcName
    ADC Load Balance service name
    Default "svc_letsencrypt_cert_dummy"
.PARAMETER SvcDestination
    IP Address used for the ADC Service (leave default 1.2.3.4, only change when already used
.PARAMETER LbName
    ADC Load Balance VIP name
    Default: "lb_letsencrypt_cert"
.PARAMETER RspName
    ADC Responder Policy name
    Default: "rsp_letsencrypt"
.PARAMETER RsaName
    ADC Responder Action name
    Default: "rsa_letsencrypt"
.PARAMETER CspName
    ADC Content Switch Policy name
    Default: "csp_NSCertCsp"
.PARAMETER CertKeyNameToUpdate
    ADC SSL Certkey name currently in use, that needs to be renewed
.PARAMETER RemovePrevious
    If the new certificate was updated successfully, remove the previous files.
    This parameter works only if -CertKeyNameToUpdate was specified and previous files are found. Else this setting will be ignored!
.PARAMETER CertDir
    Directory where to store the certificates
.PARAMETER PfxPassword
    Specify a password for the PFX certificate, if not specified a new password is generated at the end
.PARAMETER KeyLength
    Specify the KeyLength of the new to be generated certificate
    Default: 2048
.PARAMETER EmailAddress
    The email address used to request the certificates and receive a notification when the certificates (almost) expires
.PARAMETER CN
    (Common Name) The Primary (first) dns record for the certificate
    Example: "domain.com"
.PARAMETER SAN
    (Subject Alternate Name) every following domain listed in this certificate. separated via an comma , and between quotes "".
    Example: "sts.domain.com","www.domain.com","vpn.domain.com"
    Example Wildcard: "*.domain.com","*.pub.domain.com"
    NOTE: Only a DNS verification is possible when using WildCards!
.PARAMETER FriendlyName
    The display name of the certificate, if not specified the CN will used. You can specify an empty value if required.
    Example (Empty display name) : ""
    Example (Set your own name) : "Custom Name"
.PARAMETER Production
    Use the production Let's encrypt server, without this parameter the staging (test) server will be used
.PARAMETER DisableIPCheck
    If you want to skip the IP Address verification, specify this parameter
.PARAMETER CleanPoshACMEStorage
    Force cleanup of the Posh-Acme certificates located in "%LOCALAPPDATA%\Posh-ACME"
.PARAMETER ConfigFile
    Use an existing or save all the "current" parameters to a json file of your choosing for later reuse of the same parameters.
.PARAMETER AutoRun
    This parameter is used to make sure you are deliberately using the parameters from the config file and run the script automatically.
.PARAMETER IPv6
    If specified, the script will try run with IPv6 checks (EXPERIMENTAL)
.PARAMETER UpdateIIS
    If specified, the script will try to add the generated certificate to the personal computer store and bind it to the site
.PARAMETER IISSiteToUpdate
    Select a IIS Site you want to add the certificate to.
    Default value when not specifying this parameter is "Default Web Site".
.PARAMETER SendMail
    Specify this parameter if you want to send a mail at the end, don't forget to specify SMTPTo, SMTPFrom, SMTPServer and if required SMTPCredential
.PARAMETER SMTPTo
    Specify one or more email addresses.
    Email addresses can be specified as "user.name@domain.com" or "User Name <user.name@domain.com>"
    If specifying multiple email addresses, separate them wit a comma.
.PARAMETER SMTPFrom
    Specify the Email address where mails are send from
    The email address can be specified as "user.name@domain.com" or "User Name <user.name@domain.com>"
.PARAMETER SMTPServer
    Specify the SMTP Mail server fqdn or IP-address
.PARAMETER SMTPCredential
    Specify the Mail server credentials, only if credentials are required to send mails
.PARAMETER DisableLogging
    Turn off logging to logfile. Default ON
.PARAMETER LogLocation
    Specify the log file name, default "<Current Script Dir>\GenLeCertForNS_log.txt"
.PARAMETER LogLevel
    The Log level you want to have specified.
    With LogLevel: Error; Only Error (E) data will be written or shown.
    With LogLevel: Warning; Only Error (E) and Warning (W) data will be written or shown.
    With LogLevel: Info; Only Error (E), Warning (W) and Info (I) data will be written or shown.
    With LogLevel: Debug; All, Error (E), Warning (W), Info (I) and Debug (D) data will be written or shown.
    You can also define a (Global) variable in your script $LogLevel, the function will use this level instead (if not specified with the command)
    Default value: Info
.EXAMPLE
    .\GenLeCertForNS.ps1 -CreateUserPermissions -CreateApiUser -CsVipName "CSVIPNAME" -ApiUsername "le-user" -ApiPassword "LEP@ssw0rd" -CPName "MinLePermissionGroup" -Username nsroot -Password "nsroot" -ManagementURL https://citrixadc.domain.local
    This command will create a Command Policy with the minimum set of permissions, you need to run this once to create (or when you want to change something).
    Be sure to run the script next with the same parameters as specified when running this command, the same for -SvcName (Default "svc_letsencrypt_cert_dummy"), -LbName (Default: "lb_letsencrypt_cert"), -RspName (Default: "rsp_letsencrypt"), -RsaName (Default: "rsa_letsencrypt"), -CspName (Default: "csp_NSCertCsp")
    Next time you want to generate certificates you can specify the new user  -Username le-user -Password "LEP@ssw0rd"
.EXAMPLE
    .\GenLeCertForNS.ps1 -CN "domain.com" -EmailAddress "hostmaster@domain.com" -SAN "sts.domain.com","www.domain.com","vpn.domain.com" -PfxPassword "P@ssw0rd" -CertDir "C:\Certificates" -ManagementURL "http://192.168.100.1" -CsVipName "cs_domain.com_http" -Password "P@ssw0rd" -Username "nsroot" -CertKeyNameToUpdate "san_domain_com" -LogLevel Debug -Production
    Generate a (Production) certificate for hostname "domain.com" with alternate names : "sts.domain.com, www.domain.com, vpn.domain.com". Using the email address "hostmaster@domain.com". At the end storing the certificates  in "C:\Certificates" and uploading them to the ADC. The Content Switch "cs_domain.com_http" will be used to validate the certificates.
.EXAMPLE
    .\GenLeCertForNS.ps1 -CN "domain.com" -EmailAddress "hostmaster@domain.com" -SAN "*.domain.com","*.test.domain.com" -PfxPassword "P@ssw0rd" -CertDir "C:\Certificates" -ManagementURL "http://192.168.100.1" -Password "P@ssw0rd" -Username "nsroot" -CertKeyNameToUpdate "san_domain_com" -LogLevel Debug -Production
    Generate a (Production) Wildcard (*) certificate for hostname "domain.com" with alternate names : "*.domain.com, *.test.domain.com. Using the email address "hostmaster@domain.com". At the end storing the certificates  in "C:\Certificates" and uploading them to the ADC.
    NOTE: Only a DNS verification is possible when using WildCards!
.EXAMPLE
    .\GenLeCertForNS.ps1 -CleanADC -ManagementURL "http://192.168.100.1" -CsVipName "cs_domain.com_http" -Password "P@ssw0rd" -Username "nsroot"
    Cleaning left over configuration from this script when something went wrong during a previous attempt to generate new certificates.
.EXAMPLE
    .\GenLeCertForNS.ps1 -RemoveTestCertificates -ManagementURL "http://192.168.100.1" -Password "P@ssw0rd" -Username "nsroot"
    Removing ALL the test certificates from your ADC.
.EXAMPLE
    .\GenLeCertForNS.ps1 -ConfigFile ".\GenLe-Config.json"
    Running the script with previously saved parameters.
.NOTES
    File Name : GenLeCertForNS.ps1
    Version   : v2.8.0
    Author    : John Billekens
    Requires  : PowerShell v5.1 and up
                ADC 11.x and up
                Run As Administrator
                Posh-ACME 3.15.1 (Will be installed via this script) Thank you @rmbolger for providing the HTTP validation method!
                Microsoft .NET Framework 4.7.1 or later (when using Posh-ACME/WildCard certificates)
.LINK
    https://blog.j81.nl
#>

[cmdletbinding(DefaultParameterSetName = "LECertificates")]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
param(
    [Parameter(ParameterSetName = "Help", Mandatory = $true)]
    [alias("h")]
    [Switch]$Help,

    [Parameter(ParameterSetName = "CleanADC", Mandatory = $true)]
    [alias("CleanNS")]
    [Switch]$CleanADC,

    [Parameter(ParameterSetName = "CleanTestCertificate", Mandatory = $true)]
    [Switch]$RemoveTestCertificates,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanTestCertificate", Mandatory = $false)]
    [Switch]$CleanPoshACMEStorage,

    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $true)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $true)]
    [Parameter(ParameterSetName = "LECertificates", Mandatory = $true)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $true)]
    [Parameter(ParameterSetName = "CleanTestCertificate", Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [alias("URL", "NSManagementURL")]
    [String]$ManagementURL,

    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $false)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $false)]
    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanTestCertificate", Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [alias("User", "NSUsername", "ADCUsername")]
    [String]$Username,

    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $false)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $false)]
    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanTestCertificate", Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {
            if ($_ -is [SecureString]) {
                return $true
            } elseif ($_ -is [String]) {
                return $true
            } else {
                throw "You passed an unexpected object type for the credential (-Password)"
            }
        })][alias("NSPassword", "ADCPassword")]
    [object]$Password,

    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $false)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $false)]
    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanTestCertificate", Mandatory = $false)]
    [alias("NSCredential", "ADCCredential")]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$CN,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [String[]]$SAN = @(),

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [String]$FriendlyName,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [ValidateSet('http', 'dns', IgnoreCase = $true)]
    [String]$ValidationMethod,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [alias("NSCertNameToUpdate")]
    [String]$CertKeyNameToUpdate,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Switch]$RemovePrevious,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$CertDir,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [ValidateScript( {
            if ($_ -is [SecureString]) {
                return $true
            } elseif ($_ -is [String]) {
                return $true
            } else {
                throw "You passed an unexpected object type for the credential (-PfxPassword)"
            }
        })][object]$PfxPassword = $null,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $true)]
    [String]$EmailAddress,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [ValidateScript( {
            if ($_ -lt 2048 -Or $_ -gt 4096 -Or ($_ % 128) -ne 0) {
                throw "Unsupported RSA key size. Must be 2048-4096 in 8 bit increments."
            } else {
                $true
            }
        })][int32]$KeyLength = 2048,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "AutoRun", Mandatory = $false)]
    [Switch]$Production,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanTestCertificate", Mandatory = $false)]
    [Switch]$DisableLogging,

    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $false)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $false)]
    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanTestCertificate", Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [alias("LogLocation")]
    [String]$LogFile = "<DEFAULT>",

    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $false)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $false)]
    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanTestCertificate", Mandatory = $false)]
    [ValidateSet("Error", "Warning", "Info", "Debug", "None", IgnoreCase = $false)]
    [String]$LogLevel = "Info",
   
    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $false)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $false)]
    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [alias("SaveNSConfig")]
    [Switch]$SaveADCConfig,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Switch]$SendMail,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [String[]]$SMTPTo,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [String]$SMTPFrom,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]$SMTPCredential = [System.Management.Automation.PSCredential]::Empty,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [String]$SMTPServer,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Switch]$DisableIPCheck,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Switch]$IPv6,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Switch]$UpdateIIS,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [String]$IISSiteToUpdate = "Default Web Site",
    
    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $true)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $false)]
    [Parameter(ParameterSetName = "LECertificates", Mandatory = $true)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [alias("NSCsVipName")]
    [String]$CsVipName,

    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $false)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $false)]
    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [alias("NSCspName")]
    [String]$CspName = "csp_letsencrypt",

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [alias("NSCsVipBinding")]
    [String]$CsVipBinding = 11,

    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $false)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $false)]
    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [alias("NSSvcName")]
    [String]$SvcName = "svc_letsencrypt_cert_dummy",

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [alias("NSSvcDestination")]
    [String]$SvcDestination = "1.2.3.4",

    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $false)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $false)]
    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [alias("NSLbName")]
    [String]$LbName = "lb_letsencrypt_cert",

    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $false)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $false)]
    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [alias("NSRspName")]
    [String]$RspName = "rsp_letsencrypt",

    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $false)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $false)]
    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "CleanADC", Mandatory = $false)]
    [alias("NSRsaName")]
    [String]$RsaName = "rsa_letsencrypt",

    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $true)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $true)]
    [Switch]$CreateUserPermissions,

    [Parameter(ParameterSetName = "CommandPolicy", Mandatory = $false)]
    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $false)]
    [String]$NSCPName = "script-GenLeCertForNS",

    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $true)]
    [Switch]$CreateApiUser,

    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$ApiUsername,

    [Parameter(ParameterSetName = "CommandPolicyUser", Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {
            if ($_ -is [SecureString]) {
                return $true
            } elseif ($_ -is [String]) {
                return $true
            } else {
                throw "You passed an unexpected object type for the credential (-ApiPassword)"
            }
        })]
    [object]$ApiPassword,

    [Parameter(ParameterSetName = "LECertificates", Mandatory = $false)]
    [Parameter(ParameterSetName = "AutoRun", Mandatory = $true)]
    [String]$ConfigFile = $null,

    [Parameter(ParameterSetName = "AutoRun", Mandatory = $true)]
    [Switch]$AutoRun = $false
)

#requires -version 5.1
#Requires -RunAsAdministrator
$ScriptVersion = "2.8.0"
$PoshACMEVersion = "3.17.0"
$VersionURI = "https://drive.google.com/uc?export=download&id=1WOySj40yNHEza23b7eZ7wzWKymKv64JW"

#region Functions

function Write-ToLogFile {
    <#
.SYNOPSIS
    Write messages to a log file.
.DESCRIPTION
    Write info to a log file.
.PARAMETER Message
    The message you want to have written to the log file.
.PARAMETER Block
    If you have a (large) block of data you want to have written without Date/Component tags, you can specify this parameter.
.PARAMETER E
    Define the Message as an Error message.
.PARAMETER W
    Define the Message as a Warning message.
.PARAMETER I
    Define the Message as an Informational message.
    Default value: This is the default value for all messages if not otherwise specified.
.PARAMETER D
    Define the Message as a Debug Message
.PARAMETER Component
    If you want to have a Component name in your log file, you can specify this parameter.
    Default value: Name of calling script
.PARAMETER DateFormat
    The date/time stamp used in the LogFile.
    Default value: "yyyy-MM-dd HH:mm:ss:ffff"
.PARAMETER NoDate
    If NoDate is defined, no date string will be added to the log file.
    Default value: False
.PARAMETER Show
    Show the Log Entry only to console.
.PARAMETER LogFile
    The FileName of your log file.
    You can also define a (Global) variable in your script $LogFile, the function will use this path instead (if not specified with the command).
    Default value: <ScriptRoot>\Log.txt or if $PSScriptRoot is not available .\Log.txt
.PARAMETER Delimiter
    Define your Custom Delimiter of the log file.
    Default value: <TAB>
.PARAMETER LogLevel
    The Log level you want to have specified.
    With LogLevel: Error; Only Error (E) data will be written or shown.
    With LogLevel: Warning; Only Error (E) and Warning (W) data will be written or shown.
    With LogLevel: Info; Only Error (E), Warning (W) and Info (I) data will be written or shown.
    With LogLevel: Debug; All, Error (E), Warning (W), Info (I) and Debug (D) data will be written or shown.
    With LogLevel: None; Nothing will be written to disk or screen.
    You can also define a (Global) variable in your script $LogLevel, the function will use this level instead (if not specified with the command)
    Default value: Info
.PARAMETER NoLogHeader
    Specify parameter if you don't want the log file to start with a header.
    Default value: False
.PARAMETER WriteHeader
    Only Write header with info to the log file.
.PARAMETER ExtraHeaderInfo
    Specify a string with info you want to add to the log header.
.PARAMETER NewLog
    Force to start a new log, previous log will be removed.
.EXAMPLE
    Write-ToLogFile "This message will be written to a log file"
    To write a message to a log file just specify the following command, it will be a default informational message.
.EXAMPLE
    Write-ToLogFile -E "This message will be written to a log file"
    To write a message to a log file just specify the following command, it will be a error message type.
.EXAMPLE
    Write-ToLogFile "This message will be written to a log file" -NewLog
    To start a new log file (previous log file will be removed)
.EXAMPLE
    Write-ToLogFile "This message will be written to a log file"
    If you have the variable $LogFile defined in your script, the Write-ToLogFile function will use that LofFile path to write to.
    E.g. $LogFile = "C:\Path\LogFile.txt"
.NOTES
    Function Name : Write-ToLogFile
    Version       : v0.2.6
    Author        : John Billekens
    Requires      : PowerShell v5.1 and up
.LINK
    https://blog.j81.nl
#>
    #requires -version 5.1

    [CmdletBinding(DefaultParameterSetName = "Info")]
    Param (
        [Parameter(ParameterSetName = "Error", Mandatory = $true, Position = 0)]
        [Parameter(ParameterSetName = "Warning", Mandatory = $true, Position = 0)]
        [Parameter(ParameterSetName = "Info", Mandatory = $true, Position = 0)]
        [Parameter(ParameterSetName = "Debug", Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias("M")]
        [string[]]$Message,

        [Parameter(ParameterSetName = "Block", Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("B")]
        [object[]]$Block,

        [Parameter(ParameterSetName = "Block", Mandatory = $false)]
        [Alias("BI")]
        [Switch]$BlockIndent,

        [Parameter(ParameterSetName = "Error")]
        [Switch]$E,

        [Parameter(ParameterSetName = "Warning")]
        [Switch]$W,

        [Parameter(ParameterSetName = "Info")]
        [Switch]$I,

        [Parameter(ParameterSetName = "Debug")]
        [Switch]$D,

        [Parameter(ParameterSetName = "Error")]
        [Parameter(ParameterSetName = "Warning")]
        [Parameter(ParameterSetName = "Info")]
        [Parameter(ParameterSetName = "Debug")]
        [Alias("C")]
        [String]$Component = $(try { $(Split-Path -Path $($MyInvocation.ScriptName) -Leaf) } catch { "LOG" }),

        [Parameter(ParameterSetName = "Error")]
        [Parameter(ParameterSetName = "Warning")]
        [Parameter(ParameterSetName = "Info")]
        [Parameter(ParameterSetName = "Debug")]
        [Alias("ND")]
        [Switch]$NoDate,

        [Parameter(ParameterSetName = "Error")]
        [Parameter(ParameterSetName = "Warning")]
        [Parameter(ParameterSetName = "Info")]
        [Parameter(ParameterSetName = "Debug")]
        [ValidateNotNullOrEmpty()]
        [Alias("DF")]
        [String]$DateFormat = "yyyy-MM-dd HH:mm:ss:ffff",

        [Parameter(ParameterSetName = "Error")]
        [Parameter(ParameterSetName = "Warning")]
        [Parameter(ParameterSetName = "Info")]
        [Parameter(ParameterSetName = "Debug")]
        [Parameter(ParameterSetName = "Block")]
        [Alias("S")]
        [Switch]$Show,

        [String]$LogFile = "Log.txt",

        [Parameter(ParameterSetName = "Error")]
        [Parameter(ParameterSetName = "Warning")]
        [Parameter(ParameterSetName = "Info")]
        [Parameter(ParameterSetName = "Debug")]
        [String]$Delimiter = "`t",

        [Parameter(ParameterSetName = "Error")]
        [Parameter(ParameterSetName = "Warning")]
        [Parameter(ParameterSetName = "Info")]
        [Parameter(ParameterSetName = "Debug")]
        [ValidateSet("Error", "Warning", "Info", "Debug", "None", IgnoreCase = $false)]
        [String]$LogLevel,

        [Parameter(ParameterSetName = "Error")]
        [Parameter(ParameterSetName = "Warning")]
        [Parameter(ParameterSetName = "Info")]
        [Parameter(ParameterSetName = "Debug")]
        [Parameter(ParameterSetName = "Block")]
        [Alias("NH", "NoHead")]
        [Switch]$NoLogHeader,
        
        [Parameter(ParameterSetName = "Head")]
        [Alias("H", "Head")]
        [Switch]$WriteHeader,

        [Alias("HI")]
        [String]$ExtraHeaderInfo = $null,

        [Alias("NL")]
        [Switch]$NewLog
    )
    $RootPath = $(if ($psISE) { Split-Path -Path $psISE.CurrentFile.FullPath } else { $(if ($global:PSScriptRoot.Length -gt 0) { $global:PSScriptRoot } else { $global:pwd.Path }) })

    # Set Message Type to Informational if nothing is defined.
    if ((-Not $I) -and (-Not $W) -and (-Not $E) -and (-Not $D) -and (-Not $Block) -and (-Not $WriteHeader)) {
        $I = $true
    }
    #Check if a log file is defined in a Script. If defined, get value.
    try {
        $LogFileVar = Get-Variable -Scope Script -Name LogFile -ValueOnly -ErrorAction Stop
        if (-Not [String]::IsNullOrWhiteSpace($LogFileVar)) {
            $LogFile = $LogFileVar
            
        }
    } catch {
        #Continue, no script variable found for LogFile
    }
    #Check if a LogLevel is defined in a script. If defined, get value.
    try {
        if ([String]::IsNullOrEmpty($LogLevel) -and (-Not $Block) -and (-Not $WriteHeader)) {
            $LogLevelVar = Get-Variable -Scope Global -Name LogLevel -ValueOnly -ErrorAction Stop
            $LogLevel = $LogLevelVar
        }
    } catch { 
        if ([String]::IsNullOrEmpty($LogLevel) -and (-Not $Block)) {
            $LogLevel = "Info"
        }
    }
    if (-Not ($LogLevel -eq "None")) {
        #Check if LogFile parameter is empty
        if ([String]::IsNullOrWhiteSpace($LogFile)) {
            if (-Not $Show) {
                Write-Warning "Messages not written to log file, LogFile path is empty!"
            }
            #Only Show Entries to Console
            $Show = $true
        } else {
            #If Not Run in a Script "$PSScriptRoot" wil only contain "\" this will be changed to the current directory
            $ParentPath = Split-Path -Path $LogFile -Parent -ErrorAction SilentlyContinue
            if (([String]::IsNullOrEmpty($ParentPath)) -Or ($ParentPath -eq "\")) {
                $LogFile = $(Join-Path -Path $RootPath -ChildPath $(Split-Path -Path $LogFile -Leaf))
            }
        }
        Write-Verbose "LogFile: $LogFile"
        #Define Log Header
        if (-Not $Show) {
            if (
                (-Not ($NoLogHeader -eq $True) -and (-Not (Test-Path -Path $LogFile -ErrorAction SilentlyContinue))) -Or 
                (-Not ($NoLogHeader -eq $True) -and ($NewLog)) -Or
                ($WriteHeader)) {
                $LogHeader = @"
**********************
LogFile: $LogFile
Start time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Username: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)
RunAs Admin: $((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
Machine: $($Env:COMPUTERNAME) ($([System.Environment]::OSVersion.VersionString))
PSCulture: $($PSCulture)
PSVersion: $($PSVersionTable.PSVersion)
PSEdition: $($PSVersionTable.PSEdition)
PSCompatibleVersions: $($PSVersionTable.PSCompatibleVersions -join ', ')
BuildVersion: $($PSVersionTable.BuildVersion)
PSCommandPath: $($PSCommandPath)
LanguageMode: $($ExecutionContext.SessionState.LanguageMode)
"@
                if (-Not [String]::IsNullOrEmpty($ExtraHeaderInfo)) {
                    $LogHeader += "`r`n"
                    $LogHeader += $ExtraHeaderInfo.TrimEnd("`r`n")
                }
                $LogHeader += "`r`n**********************`r`n`r`n"

            } else {
                $LogHeader = $null
            }
        }
    } else {
        Write-Verbose "LogLevel is set to None!"
    }
    #Define date string to start log message with. If NoDate is defined no date string will be added to the log file.
    if (-Not ($LogLevel -eq "None")) {
        if (-Not ($NoDate) -and (-Not $Block) -and (-Not $WriteHeader)) {
            $DateString = "{0}{1}" -f $(Get-Date -Format $DateFormat), $Delimiter
        } else {
            $DateString = $null
        }
        if (-Not [String]::IsNullOrEmpty($Component) -and (-Not $Block) -and (-Not $WriteHeader)) {
            $Component = " {0}[{1}]{0}" -f $Delimiter, $Component.ToUpper()
        } else {
            $Component = "{0}{0}" -f $Delimiter
        }
        #Define the log sting for the Message Type
        if ($Block -Or $WriteHeader) {
            $WriteLog = $true
        } elseif ($E -and (($LogLevel -eq "Error") -Or ($LogLevel -eq "Warning") -Or ($LogLevel -eq "Info") -Or ($LogLevel -eq "Debug"))) {
            Write-Verbose -Message "LogType: [Error], LogLevel: [$LogLevel]"
            $MessageType = "ERROR"
            $WriteLog = $true
        } elseif ($W -and (($LogLevel -eq "Warning") -Or ($LogLevel -eq "Info") -Or ($LogLevel -eq "Debug"))) {
            Write-Verbose -Message "LogType: [Warning], LogLevel: [$LogLevel]"
            $MessageType = "WARN "
            $WriteLog = $true
        } elseif ($I -and (($LogLevel -eq "Info") -Or ($LogLevel -eq "Debug"))) {
            Write-Verbose -Message "LogType: [Info], LogLevel: [$LogLevel]"
            $MessageType = "INFO "
            $WriteLog = $true
        } elseif ($D -and (($LogLevel -eq "Debug"))) {
            Write-Verbose -Message "LogType: [Debug], LogLevel: [$LogLevel]"
            $MessageType = "DEBUG"
            $WriteLog = $true
        } else {
            Write-Verbose -Message "No Log entry is made LogType: [Error: $E, Warning: $W, Info: $I, Debug: $D] LogLevel: [$LogLevel]"
            $WriteLog = $false
        }
    } else {
        $WriteLog = $false
    }
    #Write the line(s) of text to a file.
    if ($WriteLog) {
        if ($WriteHeader) {
            $LogString = $LogHeader
        } elseif ($Block) {
            if ($BlockIndent) {
                $BlockLineStart = "{0}{0}{0}" -f $Delimiter
            } else {
                $BlockLineStart = ""
            }
            if ($Block -is [System.String]) {
                $LogString = "{0]{1}" -f $BlockLineStart, $Block.Replace("`r`n", "`r`n$BlockLineStart")
            } else {
                $LogString = "{0}{1}" -f $BlockLineStart, $($Block | Out-String).Replace("`r`n", "`r`n$BlockLineStart")
            }
            $LogString = "$($LogString.TrimEnd("$BlockLineStart").TrimEnd("`r`n"))`r`n"
        } else {
            $LogString = "{0}{1}{2}{3}" -f $DateString, $MessageType, $Component, $($Message | Out-String)
        }
        if ($Show) {
            "$($LogString.TrimEnd("`r`n"))"
            Write-Verbose -Message "Data shown in console, not written to file!"

        } else {
            if (($LogHeader) -and (-Not $WriteHeader)) {
                $LogString = "{0}{1}" -f $LogHeader, $LogString
            }
            try {
                if ($NewLog) {
                    try {
                        Remove-Item -Path $LogFile -Force -ErrorAction Stop
                        Write-Verbose -Message "Old log file removed"
                    } catch {
                        Write-Verbose -Message "Could not remove old log file, trying to append"
                    }
                }
                [System.IO.File]::AppendAllText($LogFile, $LogString, [System.Text.Encoding]::Unicode)
                Write-Verbose -Message "Data written to LogFile:`r`n         `"$LogFile`""
            } catch {
                #If file cannot be written, give an error
                Write-Error -Category WriteError -Message "Could not write to file `"$LogFile`""
            }
        }
    } else {
        Write-Verbose -Message "Data not written to file!"
    }
}

function Invoke-ADCRestApi {
    <#
    .SYNOPSIS
        Invoke NetScaler NITRO REST API
    .DESCRIPTION
        Invoke NetScaler NITRO REST API
    .PARAMETER Session
        An existing custom NetScaler Web Request Session object returned by Connect-NetScaler
    .PARAMETER Method
        Specifies the method used for the web request
    .PARAMETER Type
        Type of the NS appliance resource
    .PARAMETER Resource
        Name of the NS appliance resource, optional
    .PARAMETER Action
        Name of the action to perform on the NS appliance resource
    .PARAMETER Arguments
        One or more arguments for the web request, in hashtable format
    .PARAMETER Query
        Specifies a query that can be send  in the web request
    .PARAMETER Filters
        Specifies a filter that can be send to the remote server, in hashtable format
    .PARAMETER Payload
        Payload  of the web request, in hashtable format
    .PARAMETER GetWarning
        Switch parameter, when turned on, warning message will be sent in 'message' field and 'WARNING' value is set in severity field of the response in case there is a warning.
        Turned off by default
    .PARAMETER OnErrorAction
        Use this parameter to set the onerror status for nitro request. Applicable only for bulk requests.
        Acceptable values: "EXIT", "CONTINUE", "ROLLBACK", default to "EXIT"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSObject]$Session,

        [Parameter(Mandatory = $true)]
        [ValidateSet('DELETE', 'GET', 'POST', 'PUT')]
        [String]$Method,

        [Parameter(Mandatory = $true)]
        [String]$Type,

        [String]$Resource,

        [String]$Action,

        [hashtable]$Arguments = @{ },

        [ValidateCount(1, 1)]
        [hashtable]$Query = @{ },

        [Switch]$Stat = $false,

        [ValidateScript( { $Method -eq 'GET' })]
        [hashtable]$Filters = @{ },

        [ValidateScript( { $Method -ne 'GET' })]
        [hashtable]$Payload = @{ },

        [Switch]$GetWarning = $false,

        [ValidateSet('EXIT', 'CONTINUE', 'ROLLBACK')]
        [String]$OnErrorAction = 'EXIT',
        
        [Switch]$Clean
    )
    # Based on https://github.com/devblackops/NetScaler
    if ([String]::IsNullOrEmpty($($Session.ManagementURL))) {
        try { Write-ToLogFile -E -C Invoke-ADCRestApi -M "Probably not logged into the Citrix ADC!" } catch { }
        throw "ERROR. Probably not logged into the ADC"
    }
    if ($Stat) {
        $uri = "$($Session.ManagementURL)/nitro/v1/stat/$Type"
    } else {
        $uri = "$($Session.ManagementURL)/nitro/v1/config/$Type"
    }
    if (-not ([String]::IsNullOrEmpty($Resource))) {
        $uri += "/$Resource"
    }
    if ($Method -ne 'GET') {
        if (-not ([String]::IsNullOrEmpty($Action))) {
            $uri += "?action=$Action"
        }

        if ($Arguments.Count -gt 0) {
            $queryPresent = $true
            if ($uri -like '*?action*') {
                $uri += '&args='
            } else {
                $uri += '?args='
            }
            $argsList = @()
            foreach ($arg in $Arguments.GetEnumerator()) {
                $argsList += "$($arg.Name):$([System.Uri]::EscapeDataString($arg.Value))"
            }
            $uri += $argsList -join ','
        }
    } else {
        $queryPresent = $false
        if ($Arguments.Count -gt 0) {
            $queryPresent = $true
            $uri += '?args='
            $argsList = @()
            foreach ($arg in $Arguments.GetEnumerator()) {
                $argsList += "$($arg.Name):$([System.Uri]::EscapeDataString($arg.Value))"
            }
            $uri += $argsList -join ','
        }
        if ($Filters.Count -gt 0) {
            $uri += if ($queryPresent) { '&filter=' } else { '?filter=' }
            $filterList = @()
            foreach ($filter in $Filters.GetEnumerator()) {
                $filterList += "$($filter.Name):$([System.Uri]::EscapeDataString($filter.Value))"
            }
            $uri += $filterList -join ','
        }
        if ($Query.Count -gt 0) {
            $uri += $Query.GetEnumerator() | Foreach-Object { "?$($_.Name)=$([System.Uri]::EscapeDataString($_.Value))" }
        }
    }
    try { Write-ToLogFile -D -C Invoke-ADCRestApi -M "URI: `"$uri`", METHOD: `"$method`"" } catch { }

    $jsonPayload = $null
    if ($Method -ne 'GET') {
        $warning = if ($GetWarning) { 'YES' } else { 'NO' }
        $hashtablePayload = @{ }
        $hashtablePayload.'params' = @{'warning' = $warning; 'onerror' = $OnErrorAction; <#"action"=$Action#> }
        $hashtablePayload.$Type = $Payload
        $jsonPayload = ConvertTo-Json -InputObject $hashtablePayload -Depth 100 -Compress
        try { Write-ToLogFile -D -C Invoke-ADCRestApi -M "JSON Payload: $($jsonPayload | ConvertTo-Json -Compress)" } catch { }
    }

    $response = $null
    $restError = $null
    try {
        $restError = @()
        $restParams = @{
            Uri           = $uri
            ContentType   = 'application/json'
            Method        = $Method
            WebSession    = $Session.WebSession
            ErrorVariable = 'restError'
            Verbose       = $false
        }

        if ($Method -ne 'GET') {
            $restParams.Add('Body', $jsonPayload)
        }

        $response = Invoke-RestMethod @restParams

        if ($response) {
            if ($response.severity -eq 'ERROR') {
                try { Write-ToLogFile -E -C Invoke-ADCRestApi -M "Got an ERROR response: $($response| ConvertTo-Json -Compress)" } catch { }
                throw "Error. See log"
            } else {
                try { Write-ToLogFile -D -C Invoke-ADCRestApi -M "Response: $($response | ConvertTo-Json -Compress)" } catch { }
                if ($Method -eq "GET") { 
                    if ($Clean -and (-not ([String]::IsNullOrEmpty($Type)))) {
                        return $response | Select-Object -ExpandProperty $Type -ErrorAction SilentlyContinue
                    } else {
                        return $response 
                    }
                }
            }
        }
    } catch [Exception] {
        if ($Type -eq 'reboot' -and $restError[0].Message -eq 'The underlying connection was closed: The connection was closed unexpectedly.') {
            try { Write-ToLogFile -I -C Invoke-ADCRestApi -M "Connection closed due to reboot." } catch { }
        } else {
            try { Write-ToLogFile -E -C Invoke-ADCRestApi -M "Caught an error. Exception Message: $($_.Exception.Message)" } catch { }
            throw $_
        }
    }
}

function Connect-ADC {
    <#
    .SYNOPSIS
        Establish a session with Citrix NetScaler.
    .DESCRIPTION
        Establish a session with Citrix NetScaler.
    .PARAMETER ManagementURL
        The URI/URL to connect to, E.g. "https://citrixadc.domain.local".
    .PARAMETER Credential
        The credential to authenticate to the NetScaler with.
    .PARAMETER Timeout
        Timeout in seconds for session object.
    .PARAMETER PassThru
        Return the NetScaler session object.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [String]$ManagementURL,

        [parameter(Mandatory)]
        [PSCredential]$Credential,

        [int]$Timeout = 3600,

        [Switch]$PassThru
    )
    # Based on https://github.com/devblackops/NetScaler
    try { Write-ToLogFile -I -C Connect-ADC -M "Connecting to $ManagementURL..." } catch { }
    if ($ManagementURL -like "https://*") {
        try { Write-ToLogFile -D -C Connect-ADC -M "Connection is SSL, Trusting all certificates." } catch { }
        $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
        $Provider.CreateCompiler() | Out-Null
        $Params = New-Object System.CodeDom.Compiler.CompilerParameters
        $Params.GenerateExecutable = $false
        $Params.GenerateInMemory = $true
        $Params.IncludeDebugInformation = $false
        $Params.ReferencedAssemblies.Add("System.DLL") > $null
        $TASource = @'
            namespace Local.ToolkitExtensions.Net.CertificatePolicy
            {
                public class TrustAll : System.Net.ICertificatePolicy
                {
                    public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                    {
                        return true;
                    }
                }
            }
'@ 
        $TAResults = $Provider.CompileAssemblyFromSource($Params, $TASource)
        $TAAssembly = $TAResults.CompiledAssembly
        $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
        [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
        [System.Net.ServicePointManager]::SecurityProtocol = 
        [System.Net.SecurityProtocolType]::Tls13 -bor `
            [System.Net.SecurityProtocolType]::Tls12 -bor `
            [System.Net.SecurityProtocolType]::Tls11
    }
    try {
        $login = @{
            login = @{
                Username = $Credential.Username;
                password = $Credential.GetNetworkCredential().Password
                timeout  = $Timeout
            }
        }
        $loginJson = ConvertTo-Json -InputObject $login -Compress
        $saveSession = @{ }
        $params = @{
            Uri             = "$ManagementURL/nitro/v1/config/login"
            Method          = 'POST'
            Body            = $loginJson
            SessionVariable = 'saveSession'
            ContentType     = 'application/json'
            ErrorVariable   = 'restError'
            Verbose         = $false
        }
        $response = Invoke-RestMethod @params

        if ($response.severity -eq 'ERROR') {
            try { Write-ToLogFile -E -C Connect-ADC -M "Caught an error. Response: $($response | Select-Object message,severity,errorcode | ConvertTo-Json -Compress)" } catch { }
            Write-Error "Error. See log"
            TerminateScript 1 "Error. See log"
        } else {
            try { Write-ToLogFile -D -C Connect-ADC -M "Response: $($response | Select-Object message,severity,errorcode | ConvertTo-Json -Compress)" } catch { }
        }
    } catch [Exception] {
        throw $_
    }
    $session = [PSObject]@{
        ManagementURL = [String]$ManagementURL;
        WebSession    = [Microsoft.PowerShell.Commands.WebRequestSession]$saveSession;
        Username      = $Credential.Username;
        Version       = "UNKNOWN";
    }
    try {
        try { Write-ToLogFile -D -C Connect-ADC -M "Trying to retrieve the ADC version" } catch { }
        $params = @{
            Uri           = "$ManagementURL/nitro/v1/config/nsversion"
            Method        = 'GET'
            WebSession    = $Session.WebSession
            ContentType   = 'application/json'
            ErrorVariable = 'restError'
            Verbose       = $false
        }
        $response = Invoke-RestMethod @params
        try { Write-ToLogFile -D -C Connect-ADC -M "Response: $($response | ConvertTo-Json -Compress)" } catch { }
        $version = $response.nsversion.version.Split(",")[0]
        if (-not ([String]::IsNullOrWhiteSpace($version))) {
            $session.version = $version
        }
        try { Write-ToLogFile -I -C Connect-ADC -M "Connected" } catch { }
        try { Write-ToLogFile -I -C Connect-ADC -M "Connected to Citrix ADC $ManagementURL, as user $($Credential.Username), ADC Version $($session.Version)" } catch { }
    } catch {
        try { Write-ToLogFile -E -C Connect-ADC -M "Caught an error. Exception Message: $($_.Exception.Message)" } catch { }
        try { Write-ToLogFile -E -C Connect-ADC -M "Response: $($response | ConvertTo-Json -Compress)" } catch { }
    }
    if ($PassThru) {
        return $session
    }
}

function ConvertTo-TxtValue {
    [cmdletbinding()]
    param(
        [String]$KeyAuthorization
    ) 
    $keyAuthBytes = [Text.Encoding]::UTF8.GetBytes($KeyAuthorization)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    $keyAuthHash = $sha256.ComputeHash($keyAuthBytes)
    $base64 = [Convert]::ToBase64String($keyAuthHash)
    $txtValue = ($base64.Split('=')[0]).Replace('+', '-').Replace('/', '_')
    return $txtValue
}

function Get-ADCCurrentCertificate {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Session,

        [Parameter(Mandatory = $true)]
        [String]$Name
    )
    try {
        Write-ToLogFile -I -C Get-ADCCurrentCertificate -M "Trying to retrieve current certificate data from the Citrix ADC."
        $adcCert = Invoke-ADCRestApi -Session $Session -Method GET -Type sslcertkey -Resource $Name -ErrorAction SilentlyContinue
        $currentCert = $adcCert.sslcertkey
        Write-ToLogFile -D -C Get-ADCCurrentCertificate -M "Certificate match:"
        $currentCert | Select-Object certkey, subject, status, clientcertnotbefore, clientcertnotafter | ForEach-Object {
            Write-ToLogFile -D -C Get-ADCCurrentCertificate -M "$($_ | ConvertTo-Json -Compress)"
        }#[System.Security.Cryptography.X509Certificates.X509Certificate2]([System.Convert]::FromBase64String($response.systemfile.filecontent))
        if ($currentCert.certKey -eq $Name) {
            $payload = @{"filename" = "$(($currentCert.cert).Replace('/nsconfig/ssl/',''))"; "filelocation" = "/nsconfig/ssl/" }
            $response = Invoke-ADCRestApi -Session $Session -Method GET -Type systemfile -Arguments $payload -ErrorAction SilentlyContinue
            if (-Not ([String]::IsNullOrWhiteSpace($response.systemfile.filecontent))) {
                ##TODO Doesn't work with encrypted certificates
                Write-ToLogFile -D -C Get-ADCCurrentCertificate -M "Certificate available, getting the details."
                $content = [System.Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($response.systemfile.filecontent))
                $Pattern = '(?smi)^-{2,}BEGIN CERTIFICATE-{2,}.*?-{2,}END CERTIFICATE-{2,}'
                $result = [Regex]::Match($content, $Pattern)
                $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
                $Cert.Import([byte[]][char[]]$($result[0].Value))
                $CertCN = $cert.Subject.Replace("CN=", "")
                Write-ToLogFile -I -C Get-ADCCurrentCertificate -M "CN: $($CertCN)"
                $san = $cert.DnsNameList.Unicode
                Write-ToLogFile -I -C Get-ADCCurrentCertificate -M "SAN: $($san | ConvertTo-Json -Compress)"
            } else {
                Write-Warning "Could not retrieve the certificate"
                Write-ToLogFile -W -C Get-ADCCurrentCertificate -M "Could not retrieve the certificate."
            }
        } else {
            Write-ToLogFile -D -C Get-ADCCurrentCertificate -M "Certificate `"$Name`" not found."
        }
    } catch {
        Write-Warning "Could not retrieve certificate info"
        Write-ToLogFile -W -C Get-ADCCurrentCertificate -M "Could not retrieve certificate info."
        Write-Warning "Details: $($_.Exception.Message | Out-String)"
        Write-ToLogFile -W -C Get-ADCCurrentCertificate -M "Details: $($_.Exception.Message | Out-String)"
        $CertCN = $null
        $san = $null
    }
    Write-ToLogFile -I -C Get-ADCCurrentCertificate -M "Finished."
    return [pscustomobject] @{
        CN          = $CertCN
        SAN         = $san
        Certificate = $Cert
    }
}

function Get-ADCCurrentCertKeyInfo {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Session,

        [Parameter(Mandatory = $true)]
        [String]$Name
    )
    Process {
        try {
            Write-ToLogFile -I -C Get-ADCCurrentCertKeyInfo -M "Trying to retrieve current certificate data from the Citrix ADC."
            $adcCert = Invoke-ADCRestApi -Session $Session -Method GET -Type sslcertkey -Resource $Name -ErrorAction SilentlyContinue
            Write-ToLogFile -D -C Get-ADCCurrentCertKeyInfo -M "Certificate match:"
            $adcCert.sslcertkey | Select-Object certkey, subject, status, clientcertnotbefore, clientcertnotafter | ForEach-Object {
                Write-ToLogFile -D -C Get-ADCCurrentCertKeyInfo -M "$($_ | ConvertTo-Json -Compress)"
            } 
            return $adcCert.sslcertkey
        } catch {
            return $null
        }
    }
}


function Invoke-CheckScriptVersions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$URI
    )
    try {
        Write-ToLogFile -D -C Invoke-CheckScriptVersions -M "Retrieving data for URI: $URI"
        $AvailableVersions = Invoke-RestMethod -Method Get -UseBasicParsing -Uri $URI -ErrorAction SilentlyContinue
        Write-ToLogFile -D -C Invoke-CheckScriptVersions -M "Successfully retrieved the requested data"
    } catch {
        Write-ToLogFile -D -C Invoke-CheckScriptVersions -M "Could not retrieve version info. Exception Message: $($_.Exception.Message)"
        $AvailableVersions = $null
    }
    return $AvailableVersions
}

function ResolveFullPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$FilePath,

        [Parameter(Mandatory = $false, Position = 1)]
        [String]$FileNamePrefix
    )
    $Path = Split-Path -Path $FilePath -Parent -ErrorAction SilentlyContinue
    if ([String]::IsNullOrEmpty($Path)) {
        if ([String]::IsNullOrEmpty($PSScriptRoot)) {
            $Path = "."
        } else {
            $Path = "$PSScriptRoot"
        }
    }
    $Path = Resolve-Path $Path
    $FileName = "{0}{1}" -f $FileNamePrefix, $(Split-Path -Path $FilePath -Leaf)
    $FilePath = Join-Path -Path $Path -ChildPath $FileName
    Return $FilePath
}

function ConvertTo-PlainText {
    [CmdletBinding()]
    param    (
        [parameter(Mandatory = $true)]
        [System.Security.SecureString]$SecureString
    )
    Process {
        $BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString);
        try {
            $result = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR);
        } finally {
            [Runtime.InteropServices.Marshal]::FreeBSTR($BSTR);
            
        }
        return $result
    }
}

function Register-FatalError {
    [cmdletbinding()]
    param (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [int]$ExitCode,

        [Parameter(Position = 1)]
        [String]$ExitMessage = $null,

        [Switch]$ExitNow
    )
    if (Script:ScriptFatalError.Error) {
        $ExitMessage = $Script:ScriptFatalError.Message
        $ExitCode = $Script:ScriptFatalError.ExitCode
    }
    Write-ToLogFile -E -C Register-FatalError -M "[$ExitCode] $ExitMessage"
    if (-Not $ExitNow) {
        Write-ToLogFile -E -C Register-FatalError -M "Registering error only, continuing to cleanup."
        $Script:ScriptFatalError.Message = $ExitMessage
        $Script:ScriptFatalError.ExitCode = $ExitCode
        $Script:ScriptFatalError.Error = $true
        $Script:CleanADC = $true
    } else {
        Write-Error $ExitMessage
        TerminateScript -ExitCode $ExitCode -ExitMessage $ExitMessage
    }
}
function TerminateScript {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [int]$ExitCode,

        [Parameter(Position = 1)]
        [String]$ExitMessage = $null
    )
    if (-Not [String]::IsNullOrEmpty($ExitMessage)) {
        Write-ToLogFile -I -C Final -M "$ExitMessage"
    }
    if ($Script:Parameters.settings.SendMail) {
        Write-ToLogFile -I -C Final -M "Script Terminated, Sending mail. ExitCode: $ExitCode"
        if (-Not ($ExitCode -eq 0)) {
            $SMTPSubject = "GenLeCertForNS Finished with an Error - $CN"
            $SMTPBody = @"
GenLeCertForNS Finished with an Error!
$ExitMessage

Check log for errors and more details.
"@
        } else {
            $SMTPSubject = "GenLeCertForNS Finished Successfully - $CN"
            $SMTPBody = @"
GenLeCertForNS Finished Successfully

$($MailData | Out-String)
"@
        }
        try {
            Write-Host -ForeGroundColor White "`r`nEmail"
            Write-Host -ForeGroundColor White -NoNewLine " -Sending Mail..........: "
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            $message = New-Object System.Net.Mail.MailMessage
            $message.From = $($Parameters.settings.SMTPFrom)
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            foreach ($to in $Parameters.settings.SMTPTo.Split(",")) {
                $message.To.Add($to)
            }
            $message.Subject = $SMTPSubject
            $message.IsBodyHTML = $false
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            $message.Body = $SMTPBody
            try {
                $message.Attachments.Add($(New-Object System.Net.Mail.Attachment $Parameters.settings.LogFile))
            } catch {
                Write-ToLogFile -E -C SendMail -M "Could not attach LogFile, Error Details: $($_.Exception.Message)"
                Write-Host -ForeGroundColor Red -NoNewLine " Could not attach LogFile "
            }
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            $smtp = New-Object Net.Mail.SmtpClient($($Script:Parameters.settings.SMTPServer))
            if (-Not ($SMTPCredential -eq [PSCredential]::Empty)) {
                $smtp.Credentials = $SMTPCredential
            }
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            try {
                $smtp.Send($message)
                Write-Host -ForeGroundColor Green " OK"
            } catch {
                Write-Host -ForeGroundColor Red "Failed, Could not send mail"
                Write-ToLogFile -E -C SendMail -M "Could not send mail: $($_.Exception.Message)"
            }
        } catch {
            Write-ToLogFile -E -C SendMail -M "Could not send mail: $($_.Exception.Message)"
            Write-Host -ForeGroundColor Red "ERROR, Could not send mail: $($_.Exception.Message)"
        }
        
    } else {
        Write-ToLogFile -I -C Final -M "Script Terminated, ExitCode: $ExitCode"
    }

    if ($ExitCode -eq 0) {
        Write-Host -ForegroundColor Green "`r`nFinished! $ExitMessage`r`n"
    } else {
        Write-Host -ForegroundColor Red "`r`nFinished with Errors! $ExitMessage`r`n"
    }
    exit $ExitCode
}

function Save-ADCConfig {
    [cmdletbinding()]
    param (
        [Switch]$SaveADCConfig
    )
    Write-Host -ForeGroundColor White "`r`nADC Configuration"
    Write-Host -ForeGroundColor White -NoNewLine " -Config Saved..........: "
    if ($SaveADCConfig) {
        Write-ToLogFile -I -C SaveADCConfig -M "Saving ADC configuration.  (`"-SaveADCConfig`" Parameter set)"
        Invoke-ADCRestApi -Session $ADCSession -Method POST -Type nsconfig -Action save
        Write-Host -ForeGroundColor Green "Saved!"
    } else {
        Write-Host -ForeGroundColor Yellow "NOT Saved! (`"-SaveADCConfig`" Parameter not defined)"
        Write-ToLogFile -I -C SaveADCConfig -M "ADC configuration NOT Saved! (`"-SaveADCConfig`" Parameter not defined)"
        $MailData += "`r`nIMPORTANT: Your Citrix ADC configuration was NOT saved!`r`n"
    }
}

function Invoke-ADCCleanup {
    [CmdletBinding()]
    param (
        [Switch]$Full
    )
    process {
        Write-ToLogFile -I -C Invoke-ADCCleanup -M "Cleaning the Citrix ADC Configuration."
        Write-Host -ForeGroundColor White "`r`nADC - Cleanup"
        Write-Host -ForeGroundColor White -NoNewLine " -Cleanup type..........: "
        if ($Full) {
            Write-Host -ForegroundColor Cyan "Full"
        } else {
            Write-Host -ForegroundColor Cyan "Full"
        }
        Write-Host -ForeGroundColor White -NoNewLine " -Cleanup...............: "
        Write-ToLogFile -I -C Invoke-ADCCleanup -M "Trying to login into the Citrix ADC."
        $ADCSession = Connect-ADC -ManagementURL $Parameters.settings.ManagementURL -Credential $Credential -PassThru
        try {
            Write-ToLogFile -I -C Invoke-ADCCleanup -M "Checking if a binding exists for `"$($Parameters.settings.CspName)`"."
            try {
                $Filters = @{"policyname" = "$($Parameters.settings.CspName)" }
                $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type csvserver_cspolicy_binding -Resource "$($Parameters.settings.CsVipName)" -Filters $Filters -ErrorAction SilentlyContinue
            } catch { }
            if ($response.csvserver_cspolicy_binding.policyname -eq $($Parameters.settings.CspName)) {
                Write-ToLogFile -I -C Invoke-ADCCleanup -M "Binding exists, removing Content Switch LoadBalance Binding."
                $Arguments = @{"name" = "$($Parameters.settings.CsVipName)"; "policyname" = "$($Parameters.settings.CspName)"; "priority" = "$($Parameters.settings.CsVipBinding)"; }
                $null = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type csvserver_cspolicy_binding -Arguments $Arguments
            } else {
                Write-ToLogFile -I -C Invoke-ADCCleanup -M "No binding found."
            }
        } catch {
            Write-ToLogFile -W -C Invoke-ADCCleanup -M "Not able to remove the Content Switch LoadBalance Binding. Exception Message: $($_.Exception.Message)"
            Write-Host -ForeGroundColor Yellow " WARNING: Not able to remove the Content Switch LoadBalance Binding"
            Write-Host -ForeGroundColor White -NoNewLine " -Cleanup...............: "
        }
        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
        try {
            Write-ToLogFile -I -C Invoke-ADCCleanup -M "Checking if Content Switch Policy `"$($Parameters.settings.CspName)`" exists."
            try {
                $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type cspolicy -Resource "$($Parameters.settings.CspName)"
            } catch { }
            if ($response.cspolicy.policyname -eq $($Parameters.settings.CspName)) {
                Write-ToLogFile -I -C Invoke-ADCCleanup -M "Content Switch Policy exist, removing Content Switch Policy."
                $null = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type cspolicy -Resource "$($Parameters.settings.CspName)"
                Write-ToLogFile -I -C Invoke-ADCCleanup -M "Removed Content Switch Policy successfully."
            } else {
                Write-ToLogFile -I -C Invoke-ADCCleanup -M "Content Switch Policy not found."
            }
        } catch {
            Write-ToLogFile -E -C Invoke-ADCCleanup -M "Not able to remove the Content Switch Policy. Exception Message: $($_.Exception.Message)"
            Write-Host -ForeGroundColor Yellow " WARNING: Not able to remove the Content Switch Policy"
            Write-Host -ForeGroundColor White -NoNewLine " -Cleanup...............: "
        }
        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
        try {
            Write-ToLogFile -I -C Invoke-ADCCleanup -M "Checking if Load Balance VIP `"$($Parameters.settings.LbName)`" exists."
            try {
                $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type lbvserver -Resource "$($Parameters.settings.LbName)"
            } catch { }
            if ($response.lbvserver.name -eq $($Parameters.settings.LbName)) {
                Write-ToLogFile -I -C Invoke-ADCCleanup -M "Load Balance VIP exist, removing the Load Balance VIP."
                $null = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type lbvserver -Resource "$($Parameters.settings.LbName)"
            } else {
                Write-ToLogFile -I -C Invoke-ADCCleanup -M "Load Balance VIP not found."
            }
        } catch {
            Write-ToLogFile -E -C Invoke-ADCCleanup -M "Not able to remove the Load Balance VIP. Exception Message: $($_.Exception.Message)"
            Write-Host -ForeGroundColor Yellow " WARNING: Not able to remove the Load Balance VIP"
            Write-Host -ForeGroundColor White -NoNewLine " -Cleanup...............: "
        }
        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
        try {
            Write-ToLogFile -I -C Invoke-ADCCleanup -M "Checking if Load Balance Service `"$($Parameters.settings.SvcName)`" exists."
            try {
                $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type service -Resource "$($Parameters.settings.SvcName)"
            } catch { }
            if ($response.service.name -eq $($Parameters.settings.SvcName)) {
                Write-ToLogFile -I -C Invoke-ADCCleanup -M "Load Balance Service exist, removing Service `"$($Parameters.settings.SvcName)`"."
                $null = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type service -Resource "$($Parameters.settings.SvcName)"
            } else {
                Write-ToLogFile -I -C Invoke-ADCCleanup -M "Load Balance Service not found."
            }
        } catch {
            Write-ToLogFile -E -C Invoke-ADCCleanup -M "Not able to remove the Service. Exception Message: $($_.Exception.Message)"
            Write-Host -ForeGroundColor Yellow " WARNING: Not able to remove the Service"
            Write-Host -ForeGroundColor White -NoNewLine " -Cleanup...............: "
        }
        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
        try {
            Write-ToLogFile -I -C Invoke-ADCCleanup -M "Checking if Load Balance Server `"$($Parameters.settings.SvcDestination)`" exists."
            try {
                $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type server -Resource "$($Parameters.settings.SvcDestination)"
            } catch { }
            if ($response.server.name -eq $($Parameters.settings.SvcDestination)) {
                Write-ToLogFile -I -C Invoke-ADCCleanup -M "Load Balance Server exist, removing Load Balance Server `"$($Parameters.settings.SvcDestination)`"."
                $null = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type server -Resource "$($Parameters.settings.SvcDestination)"
            } else {
                Write-ToLogFile -I -C Invoke-ADCCleanup -M "Load Balance Server not found."
            }
        } catch {
            Write-ToLogFile -E -C Invoke-ADCCleanup -M "Not able to remove the Server. Exception Message: $($_.Exception.Message)"
            Write-Host -ForeGroundColor Yellow " WARNING: Not able to remove the Server"
            Write-Host -ForeGroundColor White -NoNewLine " -Cleanup...............: "
        }

        Write-ToLogFile -I -C Invoke-ADCCleanup -M "Checking if there are Responder Policies starting with the name `"$($Parameters.settings.RspName)`"."
        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
        try {
            $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type responderpolicy -Filter @{name = "/$($Parameters.settings.RspName)/" }
        } catch {
            Write-ToLogFile -E -C Invoke-ADCCleanup -M "Failed to retrieve Responder Policies. Exception Message: $($_.Exception.Message)"
        }
        if (-Not([String]::IsNullOrEmpty($($response.responderpolicy)))) {
            Write-ToLogFile -D -C Invoke-ADCCleanup -M "Responder Policies found:"
            $response.responderpolicy | Select-Object name, action, rule | ForEach-Object {
                Write-ToLogFile -D -C Invoke-ADCCleanup -M "$($_ | ConvertTo-Json -Compress)"
            }
            ForEach ($ResponderPolicy in $response.responderpolicy) {
                try {
                    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                    Write-ToLogFile -I -C Invoke-ADCCleanup -M "Checking if policy `"$($ResponderPolicy.name)`" is bound to Load Balance VIP."
                    $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type responderpolicy_binding -Resource "$($ResponderPolicy.name)"
                    ForEach ($ResponderBinding in $response.responderpolicy_binding) {
                        try {
                            if ($null -eq $ResponderBinding.responderpolicy_lbvserver_binding.priority) {
                                Write-ToLogFile -I -C Invoke-ADCCleanup -M "Responder Policy not bound."
                            } else {
                                Write-ToLogFile -D -C Invoke-ADCCleanup -M "ResponderBinding: $($ResponderBinding | ConvertTo-Json -Compress)"
                                $args = @{"bindpoint" = "REQUEST" ; "policyname" = "$($ResponderBinding.responderpolicy_lbvserver_binding.name)"; "priority" = "$($ResponderBinding.responderpolicy_lbvserver_binding.priority)"; }
                                Write-ToLogFile -I -C Invoke-ADCCleanup -M "Trying to unbind with the following arguments: $($args | ConvertTo-Json -Compress)"
                                $null = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type lbvserver_responderpolicy_binding -Arguments $args -Resource $($Parameters.settings.LbName)
                                Write-ToLogFile -I -C Invoke-ADCCleanup -M "Responder Policy unbound successfully."
                            }
                        } catch {
                            Write-ToLogFile -E -C Invoke-ADCCleanup -M "Failed to unbind Responder. Exception Message: $($_.Exception.Message)"
                        }
                    }
                } catch {
                    Write-ToLogFile -E -C Invoke-ADCCleanup -M "Something went wrong while Retrieving data. Exception Message: $($_.Exception.Message)"
                }
                try {
                    Write-ToLogFile -I -C Invoke-ADCCleanup -M "Trying to remove the Responder Policy `"$($ResponderPolicy.name)`"."
                    $null = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type responderpolicy -Resource "$($ResponderPolicy.name)"
                    Write-ToLogFile -I -C Invoke-ADCCleanup -M "Responder Policy removed successfully."
                } catch {
                    Write-ToLogFile -E -C Invoke-ADCCleanup -M "Failed to remove the Responder Policy. Exception Message: $($_.Exception.Message)"
                }
            }
        } else {
            Write-ToLogFile -I -C Invoke-ADCCleanup -M "No Responder Policies found."
        }
        Write-ToLogFile -I -C Invoke-ADCCleanup -M "Checking if there are Responder Actions starting with the name `"$($Parameters.settings.RsaName)`"."
        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
        try {
            $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type responderaction -Filter @{name = "/$($Parameters.settings.RsaName)/" }
        } catch {
            Write-ToLogFile -E -C Invoke-ADCCleanup -M "Failed to retrieve Responder Actions. Exception Message: $($_.Exception.Message)"
        }
        if (-Not([String]::IsNullOrEmpty($($response.responderaction)))) {
            Write-ToLogFile -D -C Invoke-ADCCleanup -M "Responder Actions found:"
            $response.responderaction | Select-Object name, target | ForEach-Object {
                Write-ToLogFile -D -C Invoke-ADCCleanup -M "$($_ | ConvertTo-Json -Compress)"
            }
            ForEach ($ResponderAction in $response.responderaction) {
                try {
                    Write-ToLogFile -I -C Invoke-ADCCleanup -M "Trying to remove the Responder Action `"$($ResponderAction.name)`""
                    $response = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type responderaction -Resource "$($ResponderAction.name)"
                    Write-ToLogFile -I -C Invoke-ADCCleanup -M "Responder Action removed successfully."
                } catch {
                    Write-ToLogFile -E -C Invoke-ADCCleanup -M "Failed to remove the Responder Action. Exception Message: $($_.Exception.Message)"
                }
            }
        } else {
            Write-ToLogFile -I -C Invoke-ADCCleanup -M "No Responder Actions found."
        }
        Write-Host -ForeGroundColor Green " Completed"
        Write-ToLogFile -I -C Invoke-ADCCleanup -M "Finished cleaning up."        
    }
}

function Invoke-AddInitialADCConfig {
    [CmdletBinding()]
    param (
        
    )
   
    process {
        try {
            Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Trying to login into the Citrix ADC."
            Write-Host -ForeGroundColor White "`r`nADC - Configure Prerequisites"
            $ADCSession = Connect-ADC -ManagementURL $Parameters.settings.ManagementURL -Credential $Credential -PassThru
            Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Enabling required ADC Features: Load Balancer, Responder, Content Switch and SSL."
            Write-Host -ForeGroundColor White -NoNewLine " -Prerequisites.........: "
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            $FeaturesRequired = @("LB", "RESPONDER", "CS", "SSL")
            $response = try { Invoke-ADCRestApi -Session $ADCSession -Method GET -Type nsfeature -ErrorAction SilentlyContinue } catch { $null }
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            $FeaturesToBeEnabled = @()
            foreach ($Feature in $FeaturesRequired) {
                if ($Feature -in $response.nsfeature.feature) {
                    Write-ToLogFile -D -C Invoke-AddInitialADCConfig -M "Feature `"$Feature`" already enabled."
                } else {
                    Write-ToLogFile -D -C Invoke-AddInitialADCConfig -M "Feature `"$Feature`" disabled, must be enabled."
                    $FeaturesToBeEnabled += $Feature
                }
            }
            if ($FeaturesToBeEnabled.Count -gt 0) {
                $payload = @{"feature" = $FeaturesToBeEnabled }
                try {
                    $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type nsfeature -Payload $payload -Action enable
                    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                } catch {
                    Write-Host -ForeGroundColor Red " Error"
                }
            }
            try {
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Features enabled, verifying Content Switch."
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type csvserver -Resource $($Parameters.settings.CsVipName)
            } catch {
                $ExceptMessage = $_.Exception.Message
                Write-Host -ForeGroundColor Red " Error"
                Write-ToLogFile -E -C Invoke-AddInitialADCConfig -M "Could not find/read out the content switch `"$($Parameters.settings.CsVipName)`" not available? Exception Message: $ExceptMessage"
                Write-Error "Could not find/read out the content switch `"$($Parameters.settings.CsVipName)`" not available?"
                TerminateScript 1 "Could not find/read out the content switch `"$($Parameters.settings.CsVipName)`" not available?"
                if ($ExceptMessage -like "*(404) Not Found*") {
                    Write-Host -ForeGroundColor Red "The Content Switch `"$($Parameters.settings.CsVipName)`" does NOT exist!"
                    Write-ToLogFile -E -C Invoke-AddInitialADCConfig -M "The Content Switch `"$($Parameters.settings.CsVipName)`" does NOT exist!"
                    TerminateScript 1 "The Content Switch `"$($Parameters.settings.CsVipName)`" does NOT exist!"
                } elseif ($ExceptMessage -like "*The remote server returned an error*") {
                    Write-Host -ForeGroundColor Red "Unknown error found while checking the Content Switch: `"$($Parameters.settings.CsVipName)`"."
                    Write-Host -ForeGroundColor Red "Error message: `"$ExceptMessage`""
                    Write-ToLogFile -E -C Invoke-AddInitialADCConfig -M "Unknown error found while checking the Content Switch: `"$($Parameters.settings.CsVipName)`". Exception Message: $ExceptMessage"
                    TerminateScript 1 "Unknown error found while checking the Content Switch: `"$($Parameters.settings.CsVipName)`". Exception Message: $ExceptMessage"
                } elseif (-Not [String]::IsNullOrEmpty($ExceptMessage)) {
                    Write-Host -ForeGroundColor Red "Unknown Error, `"$ExceptMessage`""
                    Write-ToLogFile -E -C Invoke-AddInitialADCConfig -M "Caught an unknown error. Exception Message: $ExceptMessage"
                    TerminateScript 1 "Caught an unknown error. Exception Message: $ExceptMessage"
                }
            } 
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            try {
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Content Switch is OK, check if Load Balancer Service exists."
                $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type service -Resource $($Parameters.settings.SvcName)
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Load Balancer Service exists, continuing."
            } catch {
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Load Balancer Service does not exist, create Load Balance Service `"$($Parameters.settings.SvcName)`"."
                $payload = @{"name" = "$($Parameters.settings.SvcName)"; "ip" = "$($Parameters.settings.SvcDestination)"; "servicetype" = "HTTP"; "port" = "80"; "healthmonitor" = "NO"; }
                $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type service -Payload $payload -Action add
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Load Balance Service created."
            }
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            try {
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Check if Load Balance VIP exists."
                $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type lbvserver -Resource $($Parameters.settings.LbName)
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Load Balance VIP exists, continuing"
            } catch {
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Load Balance VIP does not exist, create Load Balance VIP `"$($Parameters.settings.LbName)`"."
                $payload = @{"name" = "$($Parameters.settings.LbName)"; "servicetype" = "HTTP"; "ipv46" = "0.0.0.0"; "Port" = "0"; }
                $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type lbvserver -Payload $payload -Action add
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Load Balance VIP Created."
            } finally {
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Checking if LB Service `"$($Parameters.settings.SvcName)`" is bound to Load Balance VIP `"$($Parameters.settings.LbName)`"."
                $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type lbvserver_service_binding -Resource $($Parameters.settings.LbName)
    
                if ($response.lbvserver_service_binding.servicename -eq $($Parameters.settings.SvcName)) {
                    Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "LB Service binding is OK"
                } else {
                    Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "LB Service binding must be configured"
                    $payload = @{"name" = "$($Parameters.settings.LbName)"; "servicename" = "$($Parameters.settings.SvcName)"; }
                    $response = Invoke-ADCRestApi -Session $ADCSession -Method PUT -Type lbvserver_service_binding -Payload $payload
                    Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "LB Service binding is OK"
                }
            }
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            try {
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Checking if Responder Policies exists starting with `"$($Parameters.settings.RspName)`""
                $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type responderpolicy -Filter @{name = "/$($Parameters.settings.RspName)/" }
            } catch {
                Write-ToLogFile -E -C Invoke-AddInitialADCConfig -M "Failed to retrieve Responder Policies. Exception Message: $($_.Exception.Message)"
            }
            if (-Not([String]::IsNullOrEmpty($($response.responderpolicy)))) {
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Responder Policies found"
                $response.responderpolicy | Select-Object name, action, rule | ForEach-Object {
                    Write-ToLogFile -D -C Invoke-AddInitialADCConfig -M "$($_ | ConvertTo-Json -Compress)"
                }
                ForEach ($ResponderPolicy in $response.responderpolicy) {
                    try {
                        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                        Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Checking if policy `"$($ResponderPolicy.name)`" is bound to Load Balance VIP."
                        $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type responderpolicy_binding -Resource "$($ResponderPolicy.name)"
                        ForEach ($ResponderBinding in $response.responderpolicy_binding) {
                            try {
                                if ($null -eq $ResponderBinding.responderpolicy_lbvserver_binding.priority) {
                                    Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Responder Policy not bound."
                                } else {
                                    Write-ToLogFile -D -C Invoke-AddInitialADCConfig -M "ResponderBinding: $($ResponderBinding | ConvertTo-Json -Compress)"
                                    $args = @{"bindpoint" = "REQUEST" ; "policyname" = "$($ResponderBinding.responderpolicy_lbvserver_binding.name)"; "priority" = "$($ResponderBinding.responderpolicy_lbvserver_binding.priority)"; }
                                    Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Trying to unbind with the following arguments: $($args | ConvertTo-Json -Compress)"
                                    $response = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type lbvserver_responderpolicy_binding -Arguments $args -Resource $($Parameters.settings.LbName)
                                    Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Responder Policy unbound successfully."
                                }
                            } catch {
                                Write-ToLogFile -E -C Invoke-AddInitialADCConfig -M "Failed to unbind Responder. Exception Message: $($_.Exception.Message)"
                            }
                        }
                    } catch {
                        Write-ToLogFile -E -C Invoke-AddInitialADCConfig -M "Something went wrong while Retrieving data. Exception Message: $($_.Exception.Message)"
                    }
                    try {
                        Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Trying to remove the Responder Policy `"$($ResponderPolicy.name)`"."
                        $response = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type responderpolicy -Resource "$($ResponderPolicy.name)"
                        Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Responder Policy removed successfully."
                    } catch {
                        Write-ToLogFile -E -C Invoke-AddInitialADCConfig -M "Failed to remove the Responder Policy. Exception Message: $($_.Exception.Message)"
                    }
                }
        
            } else {
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "No Responder Policies found."
            }
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Checking if Responder Actions exists starting with `"$($Parameters.settings.RsaName)`"."
            try {
                $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type responderaction -Filter @{name = "/$($Parameters.settings.RsaName)/" }
            } catch {
                Write-ToLogFile -E -C Invoke-AddInitialADCConfig -M "Failed to retrieve Responder Actions. Exception Message: $($_.Exception.Message)"
            }
            if (-Not([String]::IsNullOrEmpty($($response.responderaction)))) {
                Write-ToLogFile -D -C Invoke-AddInitialADCConfig -M "Responder Actions found:"
                $response.responderaction | Select-Object name, target | ForEach-Object {
                    Write-ToLogFile -D -C Invoke-AddInitialADCConfig -M "$($_ | ConvertTo-Json -Compress)"
                }
                ForEach ($ResponderAction in $response.responderaction) {
                    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                    try {
                        Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Trying to remove the Responder Action `"$($ResponderAction.name)`""
                        $response = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type responderaction -Resource "$($ResponderAction.name)"
                        Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Responder Action removed successfully."
                    } catch {
                        Write-ToLogFile -E -C Invoke-AddInitialADCConfig -M "Failed to remove the Responder Action. Exception Message: $($_.Exception.Message)"
                    }
                }
            } else {
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "No Responder Actions found."
            }
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            Write-ToLogFile -D -C Invoke-AddInitialADCConfig -M "Creating a test Responder Action."
            $payload = @{"name" = "$($($Parameters.settings.RsaName))_test"; "type" = "respondwith"; "target" = '"HTTP/1.0 200 OK" +"\r\n\r\n" + "XXXX"'; }
            $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type responderaction -Payload $payload -Action add
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            Write-ToLogFile -D -C Invoke-AddInitialADCConfig -M "Responder Action created, creating a test Responder Policy."
            $payload = @{"name" = "$($($Parameters.settings.RspName))_test"; "action" = "$($($Parameters.settings.RsaName))_test"; "rule" = 'HTTP.REQ.URL.CONTAINS(".well-known/acme-challenge/XXXX")'; }
            $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type responderpolicy -Payload $payload -Action add
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            Write-ToLogFile -D -C Invoke-AddInitialADCConfig -M "Responder Policy created, binding Responder Policy `"$($($Parameters.settings.RspName))_test`" to Load Balance VIP: `"$($Parameters.settings.LbName)`"."
            $payload = @{"name" = "$($Parameters.settings.LbName)"; "policyname" = "$($($Parameters.settings.RspName))_test"; "priority" = 5; }
            $response = Invoke-ADCRestApi -Session $ADCSession -Method PUT -Type lbvserver_responderpolicy_binding -Payload $payload -Resource $($Parameters.settings.LbName)
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            try {
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Responder Policy bound successfully, check if Content Switch Policy exists."
                $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type cspolicy -Resource $($Parameters.settings.CspName)
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Content Switch Policy exists, continuing."
                if (-not($response.cspolicy.rule -eq "HTTP.REQ.URL.CONTAINS(`"well-known/acme-challenge/`")")) {
                    $payload = @{"policyname" = "$($Parameters.settings.CspName)"; "rule" = "HTTP.REQ.URL.CONTAINS(`"well-known/acme-challenge/`")"; }
                    $response = Invoke-ADCRestApi -Session $ADCSession -Method PUT -Type cspolicy -Payload $payload
                    Write-ToLogFile -D -C Invoke-AddInitialADCConfig -M "Response: $($response | ConvertTo-Json -Compress)"
                }
            } catch {
                Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Create Content Switch Policy."
                $payload = @{"policyname" = "$($Parameters.settings.CspName)"; "rule" = 'HTTP.REQ.URL.CONTAINS("well-known/acme-challenge/")'; }
                $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type cspolicy -Payload $payload -Action add
            }
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Content Switch Policy created successfully, bind Load Balancer `"$($Parameters.settings.LbName)`" to Content Switch `"$($Parameters.settings.CsVipName)`" with prio: $($Parameters.settings.CsVipBinding)"
            $payload = @{"name" = "$($Parameters.settings.CsVipName)"; "policyname" = "$($Parameters.settings.CspName)"; "priority" = "$($Parameters.settings.CsVipBinding)"; "targetlbvserver" = "$($Parameters.settings.LbName)"; "gotopriorityexpression" = "END"; }
            $response = Invoke-ADCRestApi -Session $ADCSession -Method PUT -Type csvserver_cspolicy_binding -Payload $payload
            Write-ToLogFile -I -C Invoke-AddInitialADCConfig -M "Binding created successfully! Finished configuring the ADC"
        } catch {
            Write-Host -ForeGroundColor Red " Error"
            Write-ToLogFile -E -C Invoke-AddInitialADCConfig -M "Could not configure the ADC. Exception Message: $($_.Exception.Message)"
            Write-Error "Could not configure the ADC!"
            TerminateScript 1 "Could not configure the ADC!"
        }
        Start-Sleep -Seconds 2
        Write-Host -ForeGroundColor Green " Ready"        
    }
    
}

function Invoke-CheckDNS {
    [CmdletBinding()]
    param (
        
    )
    process {
        Write-Host -ForeGroundColor Yellow "`r`nNOTE: Executing some tests, can take a couple of seconds/minutes..."
        Write-Host -ForeGroundColor Yellow "Should a DNS test fail, the script will try to continue!"
        Write-Host -ForeGroundColor White "`r`nDNS Validation & Verifying ADC config"
        Write-ToLogFile -I -C Invoke-CheckDNS -M "DNS Validation & Verifying ADC config."
        ForEach ($DNSObject in $DNSObjects ) {
            Write-Host -ForeGroundColor White -NoNewLine " -DNS Hostname..........: "
            Write-Host -ForeGroundColor Cyan "$($DNSObject.DNSName) [$($DNSObject.IPAddress)]"
            $TestURL = "http://$($DNSObject.DNSName)/.well-known/acme-challenge/XXXX"
            Write-ToLogFile -I -C Invoke-CheckDNS -M "Testing if the Citrix ADC (Content Switch) is configured successfully by accessing URL: `"$TestURL`" (via internal DNS)."
            try {
                Write-ToLogFile -D -C Invoke-CheckDNS -M "Retrieving data"
                $result = Invoke-WebRequest -URI $TestURL -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                Write-ToLogFile -I -C Invoke-CheckDNS -M "Retrieved successfully."
                Write-ToLogFile -D -C Invoke-CheckDNS -M "output: $($result | Select-Object StatusCode,StatusDescription,RawContent | ConvertTo-Json -Compress)"
            } catch {
                $result = $null
                Write-ToLogFile -E -C Invoke-CheckDNS -M "Internal check failed. Exception Message: $($_.Exception.Message)"
            }
            if ($result.RawContent -eq "HTTP/1.0 200 OK`r`n`r`nXXXX") {
                Write-Host -ForeGroundColor White -NoNewLine " -Test (Int. DNS).......: "
                Write-Host -ForeGroundColor Green "OK"
                Write-ToLogFile -I -C Invoke-CheckDNS -M "Test (Int. DNS): OK"
            } else {
                Write-Host -ForeGroundColor White -NoNewLine " -Test (Int. DNS).......: "
                Write-Host -ForeGroundColor Yellow "Not successful, maybe not resolvable internally?"
                Write-ToLogFile -W -C Invoke-CheckDNS -M "Test (Int. DNS): Not successful, maybe not resolvable externally?"
                Write-ToLogFile -D -C Invoke-CheckDNS -M "Output: $($result | Select-Object StatusCode,StatusDescription,RawContent | ConvertTo-Json -Compress)"
            }
    
            try {
                Write-ToLogFile -I -C Invoke-CheckDNS -M "Checking if Public IP is available for external DNS testing."
                [ref]$ValidIP = [IPAddress]::None
                if (([IPAddress]::TryParse("$($DNSObject.IPAddress)", $ValidIP)) -and (-not ($($Parameters.settings.DisableIPCheck)))) {
                    Write-ToLogFile -I -C Invoke-CheckDNS -M "Testing if the Citrix ADC (Content Switch) is configured successfully by accessing URL: `"$TestURL`" (via external DNS)."
                    $TestURL = "http://$($DNSObject.IPAddress)/.well-known/acme-challenge/XXXX"
                    $Headers = @{"Host" = "$($DNSObject.DNSName)" }
                    Write-ToLogFile -D -C Invoke-CheckDNS -M "Retrieving data with the following headers: $($Headers | ConvertTo-Json -Compress)"
                    $result = Invoke-WebRequest -URI $TestURL -Headers $Headers -TimeoutSec 10 -UseBasicParsing
                    Write-ToLogFile -I -C Invoke-CheckDNS -M "Success"
                    Write-ToLogFile -D -C Invoke-CheckDNS -M "Output: $($result | Select-Object StatusCode,StatusDescription,RawContent | ConvertTo-Json -Compress)"
                } else {
                    Write-ToLogFile -I -C Invoke-CheckDNS -M "Public IP is not available for external DNS testing"
                }
            } catch {
                $result = $null
                Write-ToLogFile -E -C Invoke-CheckDNS -M "External check failed. Exception Message: $($_.Exception.Message)"
            }
            [ref]$ValidIP = [IPAddress]::None
            if (([IPAddress]::TryParse("$($DNSObject.IPAddress)", $ValidIP)) -and (-not ($($Parameters.settings.DisableIPCheck)))) {
                if ($result.RawContent -eq "HTTP/1.0 200 OK`r`n`r`nXXXX") {
                    Write-Host -ForeGroundColor White -NoNewLine " -Test (Ext. DNS).......: "
                    Write-Host -ForeGroundColor Green "OK"
                    Write-ToLogFile -I -C Invoke-CheckDNS -M "Test (Ext. DNS): OK"
                } else {
                    Write-Host -ForeGroundColor White -NoNewLine " -Test (Ext. DNS).......: "
                    Write-Host -ForeGroundColor Yellow "Not successful, maybe not resolvable externally?"
                    Write-ToLogFile -W -C Invoke-CheckDNS -M "Test (Ext. DNS): Not successful, maybe not resolvable externally?"
                    Write-ToLogFile -D -C Invoke-CheckDNS -M "Output: $($result | Select-Object StatusCode,StatusDescription,RawContent | ConvertTo-Json -Compress)"
                }
            }
        }
        Write-Host -ForeGroundColor White "`r`nFinished the tests, script will continue"
        Write-ToLogFile -I -C Invoke-CheckDNS -M "Finished the tests, script will continue."        
    }
    
}

function ConvertTo-EncryptedPassword {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [Object]$Object
    )
    process {
        try {
            $IsEncrypted = $false
            if ([String]::IsNullOrEmpty($Object) -Or ($Object.Length -eq 0)) {
                $encrypted = "<null>"
                $IsEncrypted = $true
            } elseif ($Object -is [SecureString]) {
                $encrypted = ConvertFrom-SecureString -k (0..15) $Object
                $IsEncrypted = $true
            } elseif ($Object -is [String]) {
                $encrypted = ConvertFrom-SecureString -k (0..15) (ConvertTo-SecureString $Object -AsPlainText -Force)
                $IsEncrypted = $true
            } elseif ($Object -is [System.Management.Automation.PSCredential]) {
                if (([String]::IsNullOrEmpty($($Object.GetNetworkCredential().Password))) -or ($Object.Password.Length -eq 0)) {
                    $encrypted = "<null>"
                    $IsEncrypted = $true
                } else {
                    $encrypted = ConvertFrom-SecureString -k (0..15) $Object.Password
                    $IsEncrypted = $true
                }
            } else {
                Throw "The object type is unknown, must be String, SecureString or a PSCredential type."
            }
        } catch {
            $encrypted = "<null>"
            Throw "Could not convert the passed Object"
        }
        $return = [PSCustomObject]@{
            Password    = $encrypted
            IsEncrypted = $IsEncrypted
        }
        return $return
    }
}
function ConvertFrom-EncryptedPassword {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [PSCustomObject]$Object,

        [Switch]$AsClearText
    )
    process {
        try {    
            if (($Object.Password -eq "<null>") -Or ([String]::IsNullOrEmpty($Object.Password))) {
                if ($AsClearText) {
                    [String]$decodedString = ""
                } else {
                    [SecureString]$decodedString = [SecureString]::new()
                }                       
            } else {
                if ($Object.IsEncrypted) {
                    if ($AsClearText) {
                        [String]$decodedString = ""
                        [String]$decodedString = (New-Object System.Management.Automation.PSCredential(" ", (ConvertTo-SecureString -k (0..15) $Object.Password))).GetNetworkCredential().Password
                    } else {
                        [SecureString]$decodedString = [SecureString]::new()
                        [SecureString]$decodedString = (New-Object System.Management.Automation.PSCredential(" ", (ConvertTo-SecureString -k (0..15) $Object.Password))).Password
                    }
                } else {
                    if ($AsClearText) {
                        [String]$decodedString = $Object.Password
                    } else {
                        [SecureString]$decodedString = ConvertTo-SecureString $Object.Password -AsPlainText -Force
                    }
                }
            }
        } catch {
            if ($AsClearText) {
                [String]$decodedString = ""
            } else {
                [SecureString]$decodedString = [SecureString]::new()
            }
        }
        return $decodedString
    } 
}

function Invoke-AddUpdateParameter {
    [CmdletBinding()]
    param (
        [PSCustomObject]$Object,

        [String]$Name,

        [Object]$Value
    )
    process {
        if ($Value -is [SecureString]) {
            [String]$Value = ConvertTo-EncryptedPassword -Object $Value
        }
        if ([String]::IsNullOrEmpty($($Object | Get-Member -Name $Name -ErrorAction SilentlyContinue))) {
            $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
        } else {
            $Object."$Name" = $Value
        }
    }
}

#endregion Functions

#region ScriptBasics

$CertificateActions = $true
if ($CleanADC -or $RemoveTestCertificates -or $CreateApiUser -or $CreateUserPermissions) {
    $CertificateActions = $false
} 

if ($IPv6 -and $CertificateActions) {
    Write-Host -ForegroundColor White "`r`nIPv6"
    Write-Host -NoNewline -ForegroundColor White " -IPv6 checks...........: "
    Write-Warning "IPv6 Checks are experimental"
    $PublicDnsServerv6 = "2606:4700:4700::1111"
}

$PublicDnsServer = "1.1.1.1"

$ScriptFatalError = [PSCustomObject]@{
    Error    = $false
    ExitCode = 0
    Message  = $Null
}

if (-Not [String]::IsNullOrEmpty($SAN)) {
    if ($SAN -is [Array]) {
        [String]$SAN = $SAN -Join ","
    } else {
        [String]$SAN = $($SAN.Split(",").Split(" ") -Join ",")
    }
}

$ScriptRoot = $(if ($psISE) { Split-Path -Path $psISE.CurrentFile.FullPath } else { $(if ($global:PSScriptRoot.Length -gt 0) { $global:PSScriptRoot } else { $global:pwd.Path }) })

try {
    if (-Not $AutoRun) {
        if (($Password -is [String]) -and ($Password.Length -gt 0)) {
            [SecureString]$Password = ConvertTo-SecureString -String $Password -AsPlainText -Force
        }
        if ((($Password.Length -gt 0) -and ($Username.Length -gt 0))) {
            [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)
        }
        if (([PSCredential]::Empty -eq $Credential) -Or ([String]::IsNullOrEmpty($Credential))) {
            $Credential = Get-Credential -Username nsroot -Message "Citrix ADC Credentials"
        }
        if (([PSCredential]::Empty -eq $Credential) -Or ([String]::IsNullOrEmpty($Credential))) {
            throw "No valid credential found, -Username & -Password or -Credential not specified!"
        } else {
            $ADCCredentialUsername = $Credential.Username
            $ADCCredentialPassword = $Credential.Password
        }

    }
    if ($CertificateActions) {
        Add-Type -AssemblyName System.Web | Out-Null
        $length = 20
        [SecureString]$GeneratedPassword = ConvertTo-SecureString -String $([System.Web.Security.Membership]::GeneratePassword($length, 2)) -AsPlainText -Force
        if ([String]::IsNullOrEmpty($PfxPassword)) {
            try {
                if ((-Not [String]::IsNullOrEmpty($($Parameters.settings.PfxPassword))) -And $AutoRun) {
                    $PfxPasswordGenerated = $false
                } else {
                    $PfxPassword = $GeneratedPassword
                    $PfxPasswordGenerated = $true
                }
            } catch {
                $PfxPassword = $GeneratedPassword
                $PfxPasswordGenerated = $true
            }
        } elseif ($PfxPassword -is [String]) {
            [SecureString]$PfxPassword = ConvertTo-SecureString -String $PfxPassword -AsPlainText -Force
            $PfxPasswordGenerated = $false
        } else {
            $PfxPasswordGenerated = $false
        }
        $SMTPCredentialUsername = $SMTPCredential.Username
        $SMTPCredentialPassword = $SMTPCredential.Password
    }
} catch {
    throw "Could not convert to Secure Values! Exception Message: $($_.Exception.Message)"
}


try {
    Write-Host -ForeGroundColor White "`r`nScript"
    if (($AutoRun) -and (-Not (Test-Path -Path $ConfigFile -ErrorAction SilentlyContinue))) {
        Throw "Config File NOT found! This is required when specifying the AutoRun parameter!"
    }
    
    $Parameters = [PSCustomObject]@{
        settings     = [PSCustomObject]@{ }
        certrequests = @()
    }
    $SaveConfig = $false
    if (-Not [String]::IsNullOrEmpty($ConfigFile)) {
        $ConfigPath = try { Split-Path -Path $ConfigFile -Parent -ErrorAction SilentlyContinue } catch { $null }
        if ([String]::IsNullOrEmpty($ConfigPath) -Or $ConfigPath -eq ".") {
            $ConfigFile = Join-Path -Path $ScriptRoot -ChildPath $(Split-Path -Path $ConfigFile -Leaf -ErrorAction SilentlyContinue ) -ErrorAction SilentlyContinue
        }
        Write-Host -ForeGroundColor White -NoNewLine " -Config File...........: "
        Write-Host -ForeGroundColor Cyan "$ConfigFile"
        if (Test-Path -Path $ConfigFile) {
            Write-Host -ForeGroundColor Green "Found"
            try {
                if ($AutoRun) {
                    Write-Host -ForeGroundColor White -NoNewLine " -Reading Config File...: "
                    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                    $Parameters = Get-Content -Path $ConfigFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
                    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                } else {
                    Write-Host -ForeGroundColor White -NoNewLine " -Creating Config.......: "
                    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                }
                try { if (-Not $Parameters.GetType().Name -eq "PSCustomObject") { $Parameters = New-Object -TypeName PSCustomObject } } catch { $Parameters = New-Object -TypeName PSCustomObject }
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                if ([String]::IsNullOrEmpty($($Parameters | Get-Member -Name "settings" -ErrorAction SilentlyContinue))) { $Parameters | Add-Member -MemberType NoteProperty -Name "settings" -Value $(New-Object -TypeName PSCustomObject) }
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                if ([String]::IsNullOrEmpty($($Parameters | Get-Member -Name "certrequests" -ErrorAction SilentlyContinue))) { $Parameters | Add-Member -MemberType NoteProperty -Name "certrequests" -Value @() }
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                try { if (-Not ($Parameters.settings.GetType().Name -eq "PSCustomObject")) { $Parameters.settings = $(New-Object -TypeName PSCustomObject) } } Catch { $Parameters.settings = $(New-Object -TypeName PSCustomObject) }
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                if (-Not ($Parameters.certrequests -is [Array])) { $Parameters.certrequests = @() }
            } catch {
                Write-Host -ForeGroundColor Red "Error, Maybe the JSON file is invalid"
            }
            Write-Host -ForeGroundColor Green " Done"
        } else {
            Write-Host -ForeGroundColor White -NoNewLine " -Status................: "
            Write-Host -ForeGroundColor Cyan "Not Found, creating new ConfigFile"
            if ($AutoRun) {
                Write-Host -ForeGroundColor Red "No valid certificate requests found! This is required when specifying the AutoRun parameter!"
                Throw "No valid certificate requests found! This is required when specifying the AutoRun parameter!"
            }
        }
        if ($Parameters.certrequests.Count -le 0) {
            $Parameters.certrequests += New-Object -TypeName PSCustomobject
            if ($AutoRun) {
                Write-Host -ForeGroundColor Red "No valid certificate requests found! This is required when specifying the AutoRun parameter!"
                Throw "No valid certificate requests found! This is required when specifying the AutoRun parameter!"
            }
        }
    } elseif ($AutoRun) {
        Write-Host -ForeGroundColor Red "Not Found! This is required when specifying the AutoRun parameter!"
        Throw "Config File NOT found! This is required when specifying the AutoRun parameter!`r`n$($_.Exception.Message)"
    } elseif ($CertificateActions) {
        if ($Parameters.certrequests.Count -le 0) {
            $Parameters.certrequests += New-Object -TypeName PSCustomobject
        }
    }
} catch {
    Write-Host -ForeGroundColor Yellow "Could not load the Config File`r`n$($_.Exception.Message)"
    if ($AutoRun) {
        Throw "Could not load the Config File!`r`n$($_.Exception.Message)"
    }
}

Write-Host -ForeGroundColor White -NoNewLine " -Defining parameters...: "
Write-Host -ForeGroundColor Yellow -NoNewLine "*"
if ($AutoRun) {
    try {
        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
        $ADCCredentialUsername = $Parameters.settings.ADCCredentialUsername
        $ADCCredentialPassword = ConvertFrom-EncryptedPassword -Object $($Parameters.settings.ADCCredentialPassword)
        $Credential = New-Object -TypeName PSCredential -ArgumentList $ADCCredentialUsername, $ADCCredentialPassword
    } catch {
        Throw "Could not read ADC credentials"
    }
    try {
        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
        $PfxPassword = ConvertFrom-EncryptedPassword -Object $($Parameters.settings.PfxPassword)
        $PfxPasswordGenerated = $false
    } catch {
        Write-Warning "Could not read PfxPassword from ConfigFile. A new Password will be generated."
        $PfxPassword = $GeneratedPassword
        $PfxPasswordGenerated = $true
    }
    try {
        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
        $SMTPCredentialUsername = $Parameters.settings.SMTPCredentialUsername
        $SMTPCredentialPassword = ConvertFrom-EncryptedPassword -Object $($Parameters.settings.SMTPCredentialPassword)
        $SMTPCredential = New-Object -TypeName PSCredential -ArgumentList $SMTPCredentialUsername, $SMTPCredentialPassword
    } catch {
        $SMTPCredential = [PSCredential]::Empty
    }
    $Global:LogLevel = $Parameters.settings.LogLevel
    Write-Host -ForeGroundColor Green " Done"
} else {
    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name ManagementURL -Value $ManagementURL
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name ADCCredentialUsername -Value $ADCCredentialUsername
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name ADCCredentialPassword -Value $(ConvertTo-EncryptedPassword -Object $ADCCredentialPassword)
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name DisableLogging -Value $([bool]::Parse($DisableLogging))
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name LogFile -Value $LogFile
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name LogLevel -Value $LogLevel
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name SaveADCConfig -Value $([bool]::Parse($SaveADCConfig))
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name SendMail -Value $([bool]::Parse($SendMail))
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name SMTPTo -Value $SMTPTo
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name SMTPFrom -Value $SMTPFrom
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name SMTPCredentialUsername -Value $SMTPCredentialUsername
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name SMTPCredentialPassword -Value $(ConvertTo-EncryptedPassword -Object $SMTPCredentialPassword)
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name SMTPServer -Value $SMTPServer
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name DisableIPCheck -Value $([bool]::Parse($DisableIPCheck))
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name SvcName -Value $SvcName
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name SvcDestination -Value $SvcDestination
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name LbName -Value $LbName
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name CsVipName -Value $CsVipName
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name RspName -Value $RspName
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name RsaName -Value $RsaName
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name CspName -Value $CspName
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name CsVipBinding -Value $CsVipBinding
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name ScriptVersion -Value $ScriptVersion
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name PfxPassword -Value $(ConvertTo-EncryptedPassword -Object $PfxPassword)
    if (($Parameters.certrequests.Count -eq 1) -and (-Not $AutoRun )) {
        Invoke-AddUpdateParameter -Object $Parameters.certrequests[0] -Name CN -Value $CN
        Invoke-AddUpdateParameter -Object $Parameters.certrequests[0] -Name SANs -Value $SAN
        Invoke-AddUpdateParameter -Object $Parameters.certrequests[0] -Name FriendlyName -Value $FriendlyName
        Invoke-AddUpdateParameter -Object $Parameters.certrequests[0] -Name CertKeyNameToUpdate -Value $CertKeyNameToUpdate
        Invoke-AddUpdateParameter -Object $Parameters.certrequests[0] -Name RemovePrevious -Value $([bool]::Parse($RemovePrevious))
        Invoke-AddUpdateParameter -Object $Parameters.certrequests[0] -Name CertDir -Value $CertDir
        Invoke-AddUpdateParameter -Object $Parameters.certrequests[0] -Name EmailAddress -Value $EmailAddress
        Invoke-AddUpdateParameter -Object $Parameters.certrequests[0] -Name KeyLength -Value $KeyLength
        Invoke-AddUpdateParameter -Object $Parameters.certrequests[0] -Name ValidationMethod -Value $null
    }
    $SaveConfig = $true
    Write-Host -ForeGroundColor Green " Done"
}

if ($Parameters.settings.DisableLogging) {
    $Global:LogLevel = "None"
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name LogLevel -Value $Global:LogLevel
} else {
    if ($Parameters.settings.LogFile -like "*<DEFAULT>*") {
        $Parameters.settings.LogFile = Join-Path -Path $ScriptRoot -ChildPath $($MyInvocation.MyCommand -Replace '.ps1','.txt' )
    }
    Write-Verbose "Log $($Parameters.settings.LogFile)"
    if (((Split-Path -Path $Parameters.settings.LogFile -Parent -ErrorAction SilentlyContinue) -eq ".") -or ([String]::IsNullOrEmpty($(Split-Path -Path $Parameters.settings.LogFile -Parent -ErrorAction SilentlyContinue)))) {
        $Parameters.settings.LogFile = Join-Path -Path $ScriptRoot -ChildPath $(Split-Path -Path $Parameters.settings.LogFile -Leaf )
        Write-Verbose "Log $($Parameters.settings.LogFile)"
    }
    $Global:LogLevel = $Parameters.settings.LogLevel
    $Script:LogLevel = $Parameters.settings.LogLevel
    $Global:LogFile = $Parameters.settings.LogFile
    $Script:LogFile = $Parameters.settings.LogFile
    Invoke-AddUpdateParameter -Object $Parameters.settings -Name LogFile -Value $LogFile

    $ExtraHeaderInfo = @"
ScriptBase: $ScriptRoot
Script Version: $ScriptVersion
PoSH ACME Version: $PoshACMEVersion
PSBoundParameters:
$($PSBoundParameters | Out-String)
"@
    Write-ToLogFile -I -C ScriptBasics -M "Starting a new log" -NewLog -ExtraHeaderInfo $ExtraHeaderInfo
    Write-Host -ForeGroundColor White -NoNewLine " -Log File..............: "
    Write-Host -ForeGroundColor Cyan "$($Parameters.settings.LogFile)"
    Write-Host -ForeGroundColor White -NoNewLine " -Log Level.............: "
    if ($Parameters.settings.LogLevel -eq "Debug") {
        Write-Host -ForeGroundColor Yellow "$($Parameters.settings.LogLevel) - WARNING: Passwords may be visible in the log!"
    } else {
        Write-Host -ForeGroundColor Cyan "$($Parameters.settings.LogLevel)"
    }
}

if ($CertificateActions){
if ($PfxPasswordGenerated) {
    Write-ToLogFile -I -C ScriptVariables -M "No PfxPassword was specified therefore a new one was generated."
} else {
    Write-ToLogFile -I -C ScriptVariables -M "PfxPassword was specified via parameter."
}
}
#endregion Logging

#region Help

if ($Help -Or ($PSBoundParameters.Count -eq 0)) {
    Get-Help $MyInvocation.ScriptName -Detailed
    $Parameters.settings.SendMail = $false
    TerminateScript 0 "Displaying the Detailed help info for: `"$($MyInvocation.ScriptName)`""
}
#endregion Help

#region CleanPoshACMEStorage

$ACMEStorage = Join-Path -Path $($env:LOCALAPPDATA) -ChildPath "Posh-ACME"
if ($CleanPoshACMEStorage) {
    Write-ToLogFile -I -C CleanPoshACMEStorage -M "Parameter CleanPoshACMEStorage was specified, removing `"$ACMEStorage`"."
    Remove-Item -Path $ACMEStorage -Recurse -Force -ErrorAction SilentlyContinue
}

#endregion CleanPoshACMEStorage

#region LoadModule

if ($CertificateActions) {
    Write-ToLogFile -I -C DOTNETCheck -M "Checking if .NET Framework 4.7.1 or higher is installed."
    $NetRelease = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release).Release
    if ($NetRelease -lt 461308) {
        Write-ToLogFile -W -C DOTNETCheck -M ".NET Framework 4.7.1 or higher is NOT installed."
        Write-Host -NoNewLine -ForeGroundColor RED "`n`nWARNING: "
        Write-Host ".NET Framework 4.7.1 or higher is not installed, please install before continuing!"
        Start-Process https://www.microsoft.com/net/download/dotnet-framework-runtime
        TerminateScript 1 ".NET Framework 4.7.1 or higher is not installed, please install before continuing!"
    } else {
        Write-ToLogFile -I -C DOTNETCheck -M ".NET Framework 4.7.1 or higher is installed."
    }
    $ADCSession = Connect-ADC -ManagementURL $Parameters.settings.ManagementURL -Credential $Credential -PassThru
    Write-Host -ForeGroundColor White -NoNewLine " -Loading Modules ......: "
    Write-ToLogFile -I -C LoadModule -M "Try loading the Posh-ACME v$PoshACMEVersion Modules."
    $modules = Get-Module -ListAvailable -Verbose:$false | Where-Object { ($_.Name -like "*Posh-ACME*") -and ($_.Version -ge [System.Version]$PoshACMEVersion) }
    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
    if ([String]::IsNullOrEmpty($modules)) {
        Write-ToLogFile -D -C LoadModule -M "Checking for PackageManagement."
        if ([String]::IsNullOrWhiteSpace($(Get-Module -ListAvailable -Verbose:$false | Where-Object { $_.Name -eq "PackageManagement" }))) {
            Write-Host -ForegroundColor Red " Failed"
            Write-Warning "PackageManagement is not available please install this first or manually install Posh-ACME"
            Write-Warning "Visit `"https://docs.microsoft.com/en-us/powershell/gallery/psget/get_psget_module`" to download Package Management"
            Write-Warning "Posh-ACME: https://www.powershellgallery.com/packages/Posh-ACME/$PoshACMEVersion"
            Write-ToLogFile -W -C LoadModule -M "PackageManagement is not available please install this first or manually install Posh-ACME."
            Write-ToLogFile -W -C LoadModule -M "Visit `"https://docs.microsoft.com/en-us/powershell/gallery/psget/get_psget_module`" to download Package Management."
            Write-ToLogFile -W -C LoadModule -M "Posh-ACME: https://www.powershellgallery.com/packages/Posh-ACME/$PoshACMEVersion"
            Start-Process "https://www.powershellgallery.com/packages/Posh-ACME/$PoshACMEVersion"
            TerminateScript 1 "PackageManagement is not available please install this first or manually install Posh-ACME"
        } else {
            try {
                if (-not ((Get-PackageProvider | Where-Object { $_.Name -like "*nuget*" }).Version -ge [System.Version]"2.8.5.208")) {
                    Write-ToLogFile -I -C LoadModule -M "Installing Nuget."
                    Get-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue | Out-Null
                    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                }
                $installationPolicy = (Get-PSRepository -Name PSGallery).InstallationPolicy
                if (-not ($installationPolicy.ToLower() -eq "trusted")) {
                    Write-ToLogFile -D -C LoadModule -M "Defining PSGallery PSRepository as trusted."
                    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
                    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                }
                Write-ToLogFile -I -C LoadModule -M "Installing Posh-ACME v$PoshACMEVersion"
                try {
                    Install-Module -Name Posh-ACME -Scope AllUsers -RequiredVersion $PoshACMEVersion -Force -AllowClobber
                    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                } catch {
                    Write-ToLogFile -D -C LoadModule -M "Installing Posh-ACME again but without the -AllowClobber option."
                    Install-Module -Name Posh-ACME -Scope AllUsers -RequiredVersion $PoshACMEVersion -Force
                    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                }
                if (-not ((Get-PSRepository -Name PSGallery).InstallationPolicy -eq $installationPolicy)) {
                    Write-ToLogFile -D -C LoadModule -M "Returning the PSGallery PSRepository InstallationPolicy to previous value."
                    Set-PSRepository -Name "PSGallery" -InstallationPolicy $installationPolicy | Out-Null
                    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                }
                Write-ToLogFile -D -C LoadModule -M "Try loading module Posh-ACME."
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                Import-Module Posh-ACME -ErrorAction Stop
                Write-Host -ForeGroundColor Green -NoNewLine " OK"
            } catch {
                Write-Host -ForeGroundColor Red " Failed"
                Write-ToLogFile -E -C LoadModule -M "Error while loading and/or installing module. Exception Message: $($_.Exception.Message)"
                Write-Error "Error while loading and/or installing module"
                Write-Warning "PackageManagement is not available please install this first or manually install Posh-ACME"
                Write-Warning "Visit `"https://docs.microsoft.com/en-us/powershell/gallery/psget/get_psget_module`" to download Package Management"
                Write-Warning "Posh-ACME: https://www.powershellgallery.com/packages/Posh-ACME/$PoshACMEVersion"
                Start-Process "https://www.powershellgallery.com/packages/Posh-ACME/$PoshACMEVersion"
                Write-ToLogFile -W -C LoadModule -M "PackageManagement is not available please install this first or manually install Posh-ACME."
                Write-ToLogFile -W -C LoadModule -M "Visit `"https://docs.microsoft.com/en-us/powershell/gallery/psget/get_psget_module`" to download Package Management."
                Write-ToLogFile -W -C LoadModule -M "Posh-ACME: https://www.powershellgallery.com/packages/Posh-ACME/$PoshACMEVersion"
                TerminateScript 1 "PackageManagement is not available please install this first or manually install Posh-ACME."
            } finally {
                Write-Host -ForeGroundColor White -NoNewLine " -Posh-ACME Version.....: "
                Write-Host -ForeGroundColor Cyan "v$PoshACMEVersion"
            }
        }
    } else {
        Write-ToLogFile -I -C LoadModule -M "v$PoshACMEVersion of Posh-ACME is installed, loading module."
        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
        try {
            Import-Module Posh-ACME -ErrorAction Stop
            Write-Host -ForeGroundColor Green " OK"
        } catch {
            Write-Host -ForeGroundColor Red " Failed"
            Write-ToLogFile -E -C LoadModule -M "Importing module Posh-ACME failed."
            Write-Error "Importing module Posh-ACME failed"
            TerminateScript 1 "Importing module Posh-ACME failed"
        }
    }
    Write-ToLogFile -I -C LoadModule -M "Posh-ACME loaded successfully."
}

#endregion LoadModule

#region VersionInfo

Write-Host -ForeGroundColor White -NoNewLine " -Script Version........: "
Write-Host -ForeGroundColor Cyan "v$ScriptVersion"
Write-ToLogFile -I -C VersionInfo -M "Current script version: v$ScriptVersion, checking if a new version is available."
try {
    $AvailableVersions = Invoke-CheckScriptVersions -URI $VersionURI
    if ([version]$AvailableVersions.master -gt [version]$ScriptVersion) {
        Write-Host -ForeGroundColor White -NoNewLine " -New Production Note...: "
        Write-Host -ForeGroundColor Cyan "$($AvailableVersions.masternote)"
        Write-ToLogFile -I -C VersionInfo -M "Note: $($AvailableVersions.masternote)"
        Write-Host -ForeGroundColor White -NoNewLine " -New Production Version: "
        Write-Host -ForeGroundColor Cyan "v$($AvailableVersions.master)"
        Write-ToLogFile -I -C VersionInfo -M "Version: v$($AvailableVersions.master)"
        Write-Host -ForeGroundColor White -NoNewLine " -New Production URL....: "
        Write-Host -ForeGroundColor Cyan "$($AvailableVersions.masterurl)"
        Write-ToLogFile -I -C VersionInfo -M "URL: $($AvailableVersions.masterurl)"
        if (-Not [String]::IsNullOrEmpty($($AvailableVersions.masterimportant))) {
            ""
            Write-Host -ForeGroundColor White -NoNewLine " -IMPORTANT Note........: "
            Write-Host -ForeGroundColor Yellow "$($AvailableVersions.masterimportant)"
            Write-ToLogFile -I -C VersionInfo -M "IMPORTANT Note: $($AvailableVersions.masterimportant)"
        }
        $MailData += "$($AvailableVersions.masternote)`r`nVersion: v$($AvailableVersions.master)`r`nURL:$($AvailableVersions.masterurl)"
    } else {
        Write-ToLogFile -I -C VersionInfo -M "No new Master version available"
    }
    if ([version]$AvailableVersions.dev -gt [version]$ScriptVersion) {
        Write-Host -ForeGroundColor White -NoNewLine " -New Develop Note......: "
        Write-Host -ForeGroundColor Cyan "$($AvailableVersions.devnote)"
        Write-ToLogFile -I -C VersionInfo -M "Note: $($AvailableVersions.devnote)"
        Write-Host -ForeGroundColor White -NoNewLine " -New Develop Version...: "
        Write-Host -ForeGroundColor Cyan "v$($AvailableVersions.dev)"
        Write-ToLogFile -I -C VersionInfo -M "Version: v$($AvailableVersions.dev)"
        Write-Host -ForeGroundColor White -NoNewLine " -New Develop URL.......: "
        Write-Host -ForeGroundColor Cyan "$($AvailableVersions.devurl)"
        Write-ToLogFile -I -C VersionInfo -M "URL: $($AvailableVersions.devurl)"
        if (-Not [String]::IsNullOrEmpty($($AvailableVersions.devimportant))) {
            ""
            Write-Host -ForeGroundColor White -NoNewLine " -IMPORTANT Note........: "
            Write-Host -ForeGroundColor Yellow "$($AvailableVersions.devimportant)"
            Write-ToLogFile -I -C VersionInfo -M "IMPORTANT Note: $($AvailableVersions.devimportant)"
        }
    } else {
        Write-ToLogFile -I -C VersionInfo -M "No new Development version available"
    }
} catch {
    Write-ToLogFile -E -C VersionInfo -M "Caught an error while retrieving version info. Exception Message: $($_.Exception.Message)"
}
Write-ToLogFile -I -C VersionInfo -M "Version check finished."
#endregion VersionInfo

#region ADC-Check

Write-ToLogFile -I -C ADC-Check -M "Trying to login into the Citrix ADC."
Write-Host -ForeGroundColor White "`r`nCitrix ADC Connection"
$ADCSession = Connect-ADC -ManagementURL $Parameters.settings.ManagementURL -Credential $Credential -PassThru
Write-Host -ForeGroundColor White -NoNewLine " -URL...................: "
Write-Host -ForeGroundColor Cyan "$($Parameters.settings.ManagementURL)"
Write-Host -ForeGroundColor White -NoNewLine " -Username..............: "
Write-Host -ForeGroundColor Cyan "$($ADCSession.Username)"
Write-Host -ForeGroundColor White -NoNewLine " -Password..............: "
Write-Host -ForeGroundColor Cyan "**ENCRYPTED**"
Write-Host -ForeGroundColor White -NoNewLine " -Version...............: "
Write-Host -ForeGroundColor Cyan "$($ADCSession.Version)"
try {
    $ADCVersion = [double]$($ADCSession.version.split(" ")[1].Replace("NS", "").Replace(":", ""))
    if ($ADCVersion -lt 11) {
        Write-Host -ForeGroundColor RED -NoNewLine "ERROR: "
        Write-Host -ForeGroundColor White "Only ADC version 11 and up is supported, please use an older version (v1-api) of this script!"
        Write-ToLogFile -E -C ADC-Check -M "Only ADC version 11 and up is supported, please use an older version (v1-api) of this script!"
        Start-Process "https://github.com/j81blog/GenLeCertForNS/tree/master-v1-api"
        TerminateScript 1 "Only ADC version 11 and up is supported, please use an older version (v1-api) of this script!"
    }
} catch {
    Write-ToLogFile -E -C ADC-Check -M "Caught an error while retrieving the version! Exception Message: $($_.Exception.Message)"
}

if ($CreateUserPermissions -and [String]::IsNullOrEmpty($($Parameters.settings.CsVipName))) {
    Write-Host -ForeGroundColor White -NoNewLine " -Content Switch........: "
    Write-Host -ForeGroundColor Red "NOT Found! This is required for Command Policy creation!"
    TerminateScript 1 "No Content Switch VIP name defined, this is required for Command Policy creation!"
}

if ($AutoRun -Or -Not [String]::IsNullOrEmpty($($Parameters.settings.ManagementURL))) {
    if (-Not [String]::IsNullOrEmpty($($Parameters.settings.CsVipName))) {
        try {
            Write-ToLogFile -I -C ADC-CS-Validation -M "Verifying Content Switch."
            $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type csvserver -Resource $($Parameters.settings.CsVipName)
        } catch {
            $ExceptMessage = $_.Exception.Message
            Write-ToLogFile -E -C ADC-CS-Validation -M "Error Verifying Content Switch. Details: $ExceptMessage"
        } finally {
            if (($response.errorcode -eq "0") -and `
                ($response.csvserver.type -eq "CONTENT") -and `
                ($response.csvserver.curstate -eq "UP") -and `
                ($response.csvserver.servicetype -eq "HTTP") -and `
                ($response.csvserver.port -eq "80") ) {
                Write-Host -ForeGroundColor White -NoNewLine " -Content Switch........: "
                Write-Host -ForeGroundColor Cyan -NoNewLine "$($Parameters.settings.CsVipName)"
                Write-Host -ForeGroundColor Green " (found)"
                Write-Host -ForeGroundColor White -NoNewLine " -Connection............: "
                Write-Host -ForeGroundColor Green "OK"
                Write-ToLogFile -I -C ADC-CS-Validation -M "Content Switch OK"
            } elseif ($ExceptMessage -like "*(404) Not Found*") {
                Write-Host -ForeGroundColor White -NoNewLine " -Content Switch........: "
                Write-Host -ForeGroundColor Red "ERROR: The Content Switch `"$($Parameters.settings.CsVipName)`" does NOT exist!"
                Write-Host -ForeGroundColor White -NoNewLine "  -Error message........: "
                Write-Host -ForeGroundColor Red "`"$ExceptMessage`"`r`n"
                Write-Host -ForeGroundColor Yellow "  IMPORTANT: Please make sure a HTTP Content Switch is available`r`n"
                Write-Host -ForeGroundColor White -NoNewLine " -Connection............: "
                Write-Host -ForeGroundColor Red "FAILED! Exiting now`r`n"
                Write-ToLogFile -E -C ADC-CS-Validation -M "The Content Switch `"$($Parameters.settings.CsVipName)`" does NOT exist! Please make sure a HTTP Content Switch is available."
                TerminateScript 1 "The Content Switch `"$($Parameters.settings.CsVipName)`" does NOT exist! Please make sure a HTTP Content Switch is available."
            } elseif ($ExceptMessage -like "*The remote server returned an error*") {
                Write-Host -ForeGroundColor White -NoNewLine " -Content Switch........: "
                Write-Host -ForeGroundColor Red "ERROR: Unknown error found while checking the Content Switch"
                Write-Host -ForeGroundColor White -NoNewLine "  -Error message........: "
                Write-Host -ForeGroundColor Red "`"$ExceptMessage`"`r`n"
                Write-Host -ForeGroundColor White -NoNewLine " -Connection............: "
                Write-Host -ForeGroundColor Red "FAILED! Exiting now`r`n"
                Write-ToLogFile -E -C ADC-CS-Validation -M "Unknown error found while checking the Content Switch"
                TerminateScript 1 "Unknown error found while checking the Content Switch"
            } elseif (($response.errorcode -eq "0") -and (-not ($response.csvserver.servicetype -eq "HTTP"))) {
                Write-Host -ForeGroundColor White -NoNewLine " -Content Switch........: "
                Write-Host -ForeGroundColor Red "ERROR: Content Switch `"$($Parameters.settings.CsVipName)`" is $($response.csvserver.servicetype) and NOT HTTP"
                if (-not ([String]::IsNullOrWhiteSpace($ExceptMessage))) {
                    Write-Host -ForeGroundColor White -NoNewLine "  -Error message........: "
                    Write-Host -ForeGroundColor Red "`"$ExceptMessage`""
                }
                Write-Host -ForeGroundColor Yellow "`r`n  IMPORTANT: Please use a HTTP (Port 80) Content Switch!`r`n  This is required for the validation.`r`n"
                Write-Host -ForeGroundColor White -NoNewLine " -Connection............: "
                Write-Host -ForeGroundColor Red "FAILED! Exiting now`r`n"
                Write-ToLogFile -E -C ADC-CS-Validation -M "Content Switch `"$($Parameters.settings.CsVipName)`" is $($response.csvserver.servicetype) and NOT HTTP. Please use a HTTP (Port 80) Content Switch! This is required for the validation."
                TerminateScript 1 "Content Switch `"$($Parameters.settings.CsVipName)`" is $($response.csvserver.servicetype) and NOT HTTP. Please use a HTTP (Port 80) Content Switch! This is required for the validation."
            } else {
                Write-Host -ForeGroundColor White -NoNewLine " -Content Switch........: "
                Write-Host -ForeGroundColor Green "Found"
                Write-ToLogFile -I -C ADC-CS-Validation -M "Content Switch Found"
                Write-Host -ForeGroundColor White -NoNewLine "  -State................: "
                if ($response.csvserver.curstate -eq "UP") {
                    Write-Host -ForeGroundColor Green "UP"
                    Write-ToLogFile -I -C ADC-CS-Validation -M "Content Switch is UP"
                } else {
                    Write-Host -ForeGroundColor RED "$($response.csvserver.curstate)"
                    Write-ToLogFile -I -C ADC-CS-Validation -M "Content Switch Not OK, Current Status: $($response.csvserver.curstate)."
                }
                Write-Host -ForeGroundColor White -NoNewLine "  -Type.................: "
                if ($response.csvserver.type -eq "CONTENT") {
                    Write-Host -ForeGroundColor Green "CONTENT"
                    Write-ToLogFile -I -C ADC-CS-Validation -M "Content Switch type OK, Type: $($response.csvserver.type)"
                } else {
                    Write-Host -ForeGroundColor RED "$($response.csvserver.type)"
                    Write-ToLogFile -I -C ADC-CS-Validation -M "Content Switch type Not OK, Type: $($response.csvserver.type)"
                }
                if (-not ([String]::IsNullOrWhiteSpace($ExceptMessage))) {
                    Write-Host -ForeGroundColor White -NoNewLine "  -Error message........: "
                    Write-Host -ForeGroundColor Red "`"$ExceptMessage`""
                }
                Write-Host -ForeGroundColor White -NoNewLine " -Data..................: "
                Write-Host -ForeGroundColor Yellow $($response.csvserver | Format-List -Property * | Out-String)
                Write-Host -ForeGroundColor White -NoNewLine " -Connection............: "
                Write-Host -ForeGroundColor Red "FAILED! Exiting now`r`n"
                Write-ToLogFile -E -C ADC-CS-Validation -M "Content Switch verification failed."
                TerminateScript 1 "Content Switch verification failed."
            }
        }
    } else {
        Write-Host -ForeGroundColor White -NoNewLine " -Connection............: "
        if (-Not [String]::IsNullOrEmpty($($ADCSession.Version))) {
            Write-Host -ForeGroundColor Green "OK"
            Write-ToLogFile -I -C ADC-CS-Validation -M "Connection OK."
        } else {
            Write-Warning "Could not verify the Citrix ADC Connection!"
            Write-Warning "Script will continue but uploading of certificates will probably Fail"
            Write-ToLogFile -W -C ADC-CS-Validation -M "Could not verify the Citrix ADC Connection! Script will continue but uploading of certificates will probably Fail."
        }
    }
}

#endregion ADC-Check

#region ApiUserPermissions

if ($CreateUserPermissions -Or $CreateApiUser) {
    ""
    Write-Warning "When you want to use own names instead of the default values for VIPs, Policies, Actions, etc."
    Write-Warning "Please run the script with the optional parameters. These names will be defined in the Command Policy."
    Write-Warning "Only those configured are allowed to be used by the members of the Command Policy `"$NSCPName`"!"
    Write-Warning "You can rerun this script with the changed parameters at any time to update an existing Command Policy"
    Write-ToLogFile -I -C ApiUserPermissions -M "CreateUserPermissions parameter specified, create or update Command Policy `"$($NSCPName)`""
    Write-Host -ForeGroundColor White "`r`nApi User Permissions Group (Command Policy)"
    Write-Host -ForeGroundColor White -NoNewLine " -Command Policy Name...: "
    Write-Host -ForeGroundColor Cyan "$NSCPName "
    Write-Host -ForeGroundColor White -NoNewLine " -CS VIP Name...........: "
    Write-Host -ForeGroundColor Cyan $($Parameters.settings.CsVipName)
    Write-Host -ForeGroundColor White -NoNewLine " -LB VIP Name...........: "
    Write-Host -ForeGroundColor Cyan $($Parameters.settings.LbName)
    Write-Host -ForeGroundColor White -NoNewLine " -Service Name..........: "
    Write-Host -ForeGroundColor Cyan $($Parameters.settings.SvcName)
    Write-Host -ForeGroundColor White -NoNewLine " -Responder Action Name.: "
    Write-Host -ForeGroundColor Cyan $($Parameters.settings.RsaName)
    Write-Host -ForeGroundColor White -NoNewLine " -Responder Policy Name.: "
    Write-Host -ForeGroundColor Cyan $($Parameters.settings.RspName)
    Write-Host -ForeGroundColor White -NoNewLine " -CS Policy Name........: "
    Write-Host -ForeGroundColor Cyan $($Parameters.settings.CspName)
    Write-Host -ForeGroundColor White -NoNewLine " -Action................: "

    $CmdSpec = "(^convert\s+ssl\s+pkcs12)|(^show\s+ns\s+feature)|(^show\s+ns\s+feature\s+.*)|(^show\s+responder\s+action)|(^show\s+responder\s+policy)|(^(add|rm)\s+system\s+file.*-fileLocation.*nsconfig.*ssl.*)|(^show\s+ssl\s+certKey)|(^(add|link|unlink|update)\s+ssl\s+certKey\s+.*)|(^save\s+ns\s+config)|(^save\s+ns\s+config\s+.*)|(^show\s+ns\s+version)|(^(set|show|bind|unbind)\s+cs\s+vserver\s+$($Parameters.settings.CsVipName).*)|(^\S+\s+Service\s+$($Parameters.settings.SvcName).*)|(^\S+\s+lb\s+vserver\s+$($Parameters.settings.LbName).*)|(^\S+\s+responder\s+action\s+$($Parameters.settings.RsaName).*)|(^\S+\s+responder\s+policy\s+$($Parameters.settings.RspName).*)|(^\S+\s+cs\s+policy\s+$($Parameters.settings.CspName).*)"
    try {
        $Filters = @{ policyname = "$NSCPName" }
        $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type systemcmdpolicy -Filters $Filters
        if ($response.systemcmdpolicy.count -eq 1) {
            Write-ToLogFile -I -C ApiUserPermissions -M "Existing found, updating Command Policy"
            Write-Host -NoNewLine -ForeGroundColor Yellow "Existing found, "
            $payload = @{ policyname = $NSCPName; action = "Allow"; cmdspec = $CmdSpec }
            Write-ToLogFile -D -C ApiUserPermissions -M "Putting: $($payload | ConvertTo-Json -Compress)"
            $response = Invoke-ADCRestApi -Session $ADCSession -Method PUT -Type systemcmdpolicy -Payload $payload
            Write-Host -ForeGroundColor Green "Changed"
            
        } elseif ($response.systemcmdpolicy.count -gt 1) {
            Write-Host -ForeGroundColor Red "ERROR: Multiple Command Policies found!"
            Write-ToLogFile -I -C ApiUserPermissions -M "Multiple Command Policies found."
            $response.systemcmdpolicy | ForEach-Object {
                Write-ToLogFile -D -C ApiUserPermissions -M "$($_ | ConvertTo-Json -Compress)"
            }
        } else {
            Write-ToLogFile -I -C ApiUserPermissions -M "None found, creating new Command Policy"
            $payload = @{ policyname = $NSCPName; action = "Allow"; cmdspec = $CmdSpec }
            Write-ToLogFile -D -C ApiUserPermissions -M "Posting: $($payload | ConvertTo-Json -Compress)"
            $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type systemcmdpolicy -Payload $payload
            Write-Host -ForeGroundColor Green "Created"
        }
    } catch {
        Write-Host -ForeGroundColor Red "Error"
        Write-ToLogFile -E -C ApiUserPermissions -M "Caught an error! Exception Message: $($_.Exception.Message)"
    }
}

#endregion ApiUserPermissions

#region ApiUser

if ($CreateApiUser) {
    $CertificateActions = $false
    Write-ToLogFile -I -C ApiUser -M "CreateApiUser parameter specified, create or update user `"$ApiUsername`""
    Write-Host -ForeGroundColor White "`r`nApi (System) User"
    Write-Host -ForeGroundColor White -NoNewLine " -Api User Name.........: "
    Write-Host -ForeGroundColor Cyan "$ApiUsername "
    Write-Host -ForeGroundColor White -NoNewLine " -Action................: "
    if (($ApiPassword -is [String]) -and ($ApiPassword.Length -gt 0)) {
        [SecureString]$ApiPassword = ConvertTo-SecureString -String $ApiPassword -AsPlainText -Force
        Write-ToLogFile -D -C ApiUser -M "Secure password created"
    }
    if ((($ApiPassword.Length -gt 0) -and ($ApiUsername.Length -gt 0))) {
        $ApiCredential = New-Object System.Management.Automation.PSCredential -ArgumentList $ApiUsername, $ApiPassword
        Write-ToLogFile -D -C ApiUser -M "Credential created"
    }
    if (([PSCredential]::Empty -eq $ApiCredential) -Or ($null -eq $ApiCredential)) {
        Write-Host -ForeGroundColor Red "No valid credentials found!"
        Write-ToLogFile -E -C ApiUser -M "No valid Api Credential found, -ApiUsername or -ApiPassword not specified!"
        TerminateScript 1 "No valid Api Credential found, -ApiUsername or -ApiPassword not specified!"
    }
    Write-ToLogFile -D -C ApiUser -M "Basics ready, continuing"
    try {
        $Filters = @{ username = "$ApiUsername" }
        $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type systemuser -Filters $Filters
        if ($response.systemuser.count -eq 1) {
            Write-ToLogFile -I -C ApiUser -M "Existing found, updating User"
            Write-Host -NoNewLine -ForeGroundColor Cyan "Updating Existing "
            try {
                Write-ToLogFile -D -C ApiUser -M "Trying the preferred (API) method"
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                $payload = @{ username = $ApiUsername; password = $($ApiCredential.GetNetworkCredential().password); externalauth = "Disabled"; allowedmanagementinterface = @("API") }
                Write-ToLogFile -D -C ApiUser -M "Putting: $($payload | ConvertTo-Json -Compress)"
                $response = Invoke-ADCRestApi -Session $ADCSession -Method PUT -Type systemuser -Payload $payload
                Write-ToLogFile -D -C ApiUser -M "Succeeded"
            } catch {
                Write-ToLogFile -D -C ApiUser -M "Failed, trying the method without API"
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                $payload = @{ username = $ApiUsername; password = $($ApiCredential.GetNetworkCredential().password); externalauth = "Disabled" }
                Write-ToLogFile -D -C ApiUser -M "Putting: $($payload | ConvertTo-Json -Compress)"
                $response = Invoke-ADCRestApi -Session $ADCSession -Method PUT -Type systemuser -Payload $payload
                Write-ToLogFile -D -C ApiUser -M "Succeeded"
            }
            Write-Host -ForeGroundColor Green " Changed"
        } elseif ($response.systemuser.count -gt 1) {
            Write-Host -ForeGroundColor Red "ERROR: Multiple users found!"
            Write-ToLogFile -I -C ApiUser -M "Multiple Command Policies found."
            $response.systemuser | ForEach-Object {
                Write-ToLogFile -D -C ApiUser -M "$($_ | ConvertTo-Json -Compress)"
            }
        } else {
            Write-ToLogFile -I -C ApiUser -M "None found, creating new Users"
            try {
                Write-ToLogFile -D -C ApiUser -M "Trying to create the user"
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                $payload = @{ username = $ApiUsername; password = $($ApiCredential.GetNetworkCredential().password); externalauth = "Disabled" }
                Write-ToLogFile -D -C ApiUser -M "Posting: $($payload | ConvertTo-Json -Compress)"
                $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type systemuser -Payload $payload
                try {
                Write-ToLogFile -D -C ApiUser -M "Trying to set the preferred (API) method"
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                $payload = @{ username = $ApiUsername; externalauth = "Disabled"; allowedmanagementinterface = @("API") }
                Write-ToLogFile -D -C ApiUser -M "Posting: $($payload | ConvertTo-Json -Compress)"
                $response = Invoke-ADCRestApi -Session $ADCSession -Method PUT -Type systemuser -Payload $payload
                } catch {
                    Write-ToLogFile -D -C ApiUser -M "Could not set API Command Line Interface only (Feature not supported on this version), $($_.Exception.Message)"
                    Write-Host -ForeGroundColor Yellow -NoNewLine " API Interface setting not possible."
                }

            Write-ToLogFile -I -C ApiUser -M "API User created successfully."
            Write-Host -ForeGroundColor Green " Created"
        } catch {
            Write-Host -ForeGroundColor Red " Error"
            Write-ToLogFile -E -C ApiUser -M "Caught an error while creating user. $($_Exception.Message)"
        }

        }
        Write-ToLogFile -I -C ApiUser -M "Bind Command Policy"
        Write-Host -ForeGroundColor White -NoNewLine " -User Policy Binding...: "
        Write-Host -ForeGroundColor Cyan "$NSCPName "
        $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type systemuser_systemcmdpolicy_binding -Resource $ApiUsername
        if ($response.systemuser_systemcmdpolicy_binding.policyname.Count -gt 1) {
            Write-ToLogFile -I -C ApiUser -M "Multiple found ($($response.systemuser_systemcmdpolicy_binding.policyname -join ", "))"
            Write-Host -ForeGroundColor Yellow "Multiple found ($($response.systemuser_systemcmdpolicy_binding.policyname -join ", "))"
            $BindingsToRemove = $response.systemuser_systemcmdpolicy_binding.policyname | Where-Object { $_ -ne $NSCPName }
            foreach ($Binding in $BindingsToRemove) {
                Write-ToLogFile -D -C ApiUser -M "Removing `"$Binding`""
                Write-Host -ForeGroundColor White -NoNewLine " -Binding...............: "
                Write-Host -ForeGroundColor Cyan -NoNewLine "[$Binding] "
                try {
                    $Arguments = @{ policyname = $Binding }
                    Write-ToLogFile -D -C ApiUser -M "Deleting: $($Arguments | ConvertTo-Json -Compress)"
                    $response = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type systemuser_systemcmdpolicy_binding -Resource $ApiUsername -Arguments $Arguments -ErrorAction Stop
                    Write-Host -ForeGroundColor Green "Removed"
                } catch {
                    Write-Host -ForeGroundColor Red "Error"
                    Write-ToLogFile -D -C ApiUser -M "Error $($_.Exception.Message)"
                }
            }
            $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type systemuser_systemcmdpolicy_binding -Resource $ApiUsername
        }
        Write-Host -ForeGroundColor White -NoNewLine " -User Policy Binding...: "
        if ($response.systemuser_systemcmdpolicy_binding.policyname | Where-Object { $_ -eq $NSCPName }) {
            Write-Host -ForeGroundColor Cyan "Present"
            Write-ToLogFile -I -C ApiUser -M "A binding is already present"
        } else {
            Write-ToLogFile -I -C ApiUser -M "Creating a new binding"
            $payload = @{ username = $ApiUsername; policyname = $NSCPName; priority = 10 }
            Write-ToLogFile -D -C ApiUser -M "Putting: $($payload | ConvertTo-Json -Compress)"
            $response = Invoke-ADCRestApi -Session $ADCSession -Method PUT -Type systemuser_systemcmdpolicy_binding -Payload $payload
            Write-Host -ForeGroundColor Green "Bound"
        }
    } catch {
        Write-Host -ForeGroundColor Red "Error"
        Write-ToLogFile -E -C ApiUser -M "Caught an error! Exception Message: $($_.Exception.Message)"
    }
}


if (($CreateUserPermissions) -Or ($CreateApiUser)) {
    Save-ADCConfig -SaveADCConfig:$($Parameters.settings.SaveADCConfig)
    TerminateScript 0
}

#endregion ApiUser

#region EmailSetup

$MailData = @()
if ($Parameters.settings.SendMail) {
    $SMTPError = @()
    Write-Host -ForeGroundColor White "`r`nEmail Details"
    Write-Host -ForeGroundColor White -NoNewLine " -Email To Address......: "
    if ([String]::IsNullOrEmpty($($Parameters.settings.SMTPTo))) {
        Write-Host -ForeGroundColor Red "None"
        Write-ToLogFile -E -C EmailSettings -M "No To Address specified (-SMTPTo)"
        $SMTPError += "No To Address specified (-SMTPTo)"
    } else {
        Write-Host -ForeGroundColor Cyan "$($Parameters.settings.SMTPTo)"
        Write-ToLogFile -I -C EmailSettings -M "Email To Address: $($Parameters.settings.SMTPTo))"
    }
    Write-Host -ForeGroundColor White -NoNewLine " -Email From Address....: "
    if ([String]::IsNullOrEmpty($($Parameters.settings.SMTPFrom))) {
        Write-Host -ForeGroundColor Red "None"
        Write-ToLogFile -E -C EmailSettings -M "No From Address specified (-SMTPFrom)"
        $SMTPError += "No From Address specified (-SMTPFrom)"
    } else {
        Write-Host -ForeGroundColor Cyan "$($Parameters.settings.SMTPFrom)"
        Write-ToLogFile -I -C EmailSettings -M "Email From Address: $($Parameters.settings.SMTPFrom)"
    }
    Write-Host -ForeGroundColor White -NoNewLine " -Email Server..........: "
    if ([String]::IsNullOrEmpty($($Parameters.settings.SMTPServer))) {
        Write-Host -ForeGroundColor Red "None"
        Write-ToLogFile -E -C EmailSettings -M "No Email (SMTP) Server specified (-SMTPServer)"
        $SMTPError += "No Email (SMTP) Server specified (-SMTPServer)"
    } else {
        Write-Host -ForeGroundColor Cyan "$($Parameters.settings.SMTPServer)"
        Write-ToLogFile -I -C EmailSettings -M "Email Server: $($Parameters.settings.SMTPServer)"
    }
    Write-Host -ForeGroundColor White -NoNewLine " -Email Credentials.....: "
    if ($SMTPCredential -eq [PSCredential]::Empty) {
        Write-Host -ForeGroundColor Cyan "(Optional) None"
        Write-ToLogFile -I -C EmailSettings -M "No Email Credential specified, this is optional"
    } else {
        Write-Host -ForeGroundColor Cyan "$($Parameters.settings.SMTPCredential.UserName) (Credential)"
        Write-ToLogFile -I -C EmailSettings -M "Email Credential: $($Parameters.settings.SMTPCredential.UserName)"
    }
    if (-Not [String]::IsNullOrEmpty($SMTPError)) {
        $Parameters.settings.SendMail = $false
        TerminateScript 1 "Incorrect values, check mail settings.`r`n$($SMTPError | Out-String)"
    }
}

#endregion MailSetup

#endregion ScriptBasics

if ($CertificateActions) {
    #region Services
    if ($Production) {
        $BaseService = "LE_PROD"
        $LEText = "Production Certificates"
    } else {
        $BaseService = "LE_STAGE"
        $LEText = "Test Certificates (Staging)"
        $MailData += "IMPORTANT: This is a test certificate!"
    }
    Posh-ACME\Set-PAServer $BaseService 6>$null
    $PAServer = Posh-ACME\Get-PAServer -Refresh
    Write-Host -ForeGroundColor White "`r`nLet's Encrypt Preparation"
    Write-Host -ForeGroundColor White -NoNewLine " -Note..................: "
    Write-Host -ForeGroundColor Yellow "IMPORTANT, By running this script you agree with the terms specified by Let's Encrypt."
    Write-ToLogFile -I -C Services -M "By running this script you agree with the terms specified by Let's Encrypt."
    Write-Host -ForeGroundColor White -NoNewLine " -Terms Of Service......: "
    Write-Host -ForeGroundColor Yellow "$($PAServer.meta.termsOfService)"
    Write-ToLogFile -I -C Services -M "Terms Of Service: $($PAServer.meta.termsOfService)"
    Write-Host -ForeGroundColor White -NoNewLine " -Website...............: "
    Write-Host -ForeGroundColor Yellow "$($PAServer.meta.website)"
    Write-ToLogFile -I -C Services -M "Website: $($PAServer.meta.website)"
    Write-Host -ForeGroundColor White -NoNewLine " -LE Certificate Usage..: "
    Write-Host -ForeGroundColor Cyan $LEText
    Write-ToLogFile -I -C Services -M "LE Certificate Usage: $LEText"
    Write-Host -ForeGroundColor White -NoNewLine " -LE Account Storage....: "
    Write-Host -ForeGroundColor Cyan $ACMEStorage
    Write-ToLogFile -I -C Services -M "LE Account Storage: $ACMEStorage"

    #endregion Services

    if ($Parameters.certrequests.Count -gt 1) {
        Write-Host -ForeGroundColor White "`r`n"
        Write-Host -ForeGroundColor White -NoNewline " -Nr Cert. Requests.....: "
        Write-Host -ForeGroundColor Cyan "$($Parameters.certrequests.Count)"
    }
    
    $Round = 0
    ForEach ($CertRequest in $Parameters.certrequests) {
        $Round++
        Write-ToLogFile -I -C "CertRequest-$($Round.ToString('00'))" -M "**************************************** $($Round.ToString('00')) ****************************************"
        Write-ToLogFile -I -C DNSPreCheck -M "Round: $Round / $($Parameters.certrequests.Count)"
        if ((-Not [String]::IsNullOrEmpty($($CertRequest.CN))) -and (-Not ($CertRequest.ValidationMethod -eq "dns"))) {
            $CertRequest.ValidationMethod = "http"
        }
    
        Write-ToLogFile -D -C ScriptVariables -M "Setting session DATE/TIME variable."
        [DateTime]$ScriptDateTime = Get-Date
        [String]$SessionDateTime = $ScriptDateTime.ToString("yyyyMMdd-HHmmss")
        Write-ToLogFile -D -C ScriptVariables -M "Session DATE/TIME variable value: `"$SessionDateTime`"."
  
        ##TODO per cert PfxPassword maybe
        
        #region DNSPreCheck
        [regex]$fqdnExpression = "^(?=^.{1,254}$)(^(?:(?!\d+\.|-)[a-zA-Z0-9_\-]{1,63}(?<!-)\.?)+(?:[a-zA-Z]{2,})$)+$"
        if (($($CertRequest.CN) -match "\*") -Or ($CertRequest.SANs -match "\*")) {
            $SaveConfig = $false
            Write-Host -ForeGroundColor Yellow "`r`nNOTE: -CN or -SAN contains a wildcard entry, continuing with the `"dns`" validation method!"
            Write-ToLogFile -I -C DNSPreCheck -M "-CN or -SAN contains a wildcard entry, continuing with the `"dns`" validation method!"
            Write-Host -ForeGroundColor White -NoNewline " -CN....................: "
            Write-Host -ForeGroundColor Yellow "$($CertRequest.CN)"
            Write-ToLogFile -I -C DNSPreCheck -M "CN: $($CertRequest.CN)"
            Write-Host -ForeGroundColor White -NoNewline " -SAN(s)................: "
            Write-Host -ForeGroundColor Yellow "$($CertRequest.SANs)"
            Write-ToLogFile -I -C DNSPreCheck -M "SAN(s): $($CertRequest.SANs | ConvertTo-Json -Compress)"
            $CertRequest.ValidationMethod = "dns"
            $Parameters.settings.DisableIPCheck = $true
            Write-ToLogFile -I -C DNSPreCheck -M "Continuing with the `"$($CertRequest.ValidationMethod)`" validation method!"
        } else {
            $CertRequest.ValidationMethod = $CertRequest.ValidationMethod.ToLower()
            if (([String]::IsNullOrWhiteSpace($($Parameters.settings.CsVipName))) -and ($CertRequest.ValidationMethod -eq "http")) {
                Write-Host -ForeGroundColor Red "`r`nERROR: The `"-CsVipName`" cannot be empty!`r`n"
                Write-ToLogFile -E -C DNSPreCheck -M "The `"-CsVipName`" cannot be empty!"
                TerminateScript 1 "The `"-CsVipName`" cannot be empty!"
            }
            Write-Host -ForeGroundColor White "`r`nCertificate Request [$($Round.ToString('00'))] "
            Write-Host -ForeGroundColor White -NoNewline " -CN....................: "
            Write-Host -ForeGroundColor Yellow -NoNewline "$($CertRequest.CN)"
            if ($CertRequest.CN -match $fqdnExpression) {
                Write-Host -ForeGroundColor Green " $([Char]8730)"
                Write-ToLogFile -I -C DNSPreCheck -M "CN: $($CertRequest.CN) is a valid record"
            } else {
                Write-Host -ForeGroundColor Red " NOT a valid fqdn!"
                TerminateScript 1 "`"$($CertRequest.CN)`" is NOT a valid fqdn!"
            }
            Write-Host -ForeGroundColor White -NoNewline " -SAN(s)................: "
            $CheckedSANs = @()
            ForEach ($record in $CertRequest.SANs.Split(",")) {
                Write-Host -ForeGroundColor Yellow -NoNewline "$record"
                if ($record -match $fqdnExpression) {
                    Write-Host -ForeGroundColor Green -NoNewline " $([Char]8730), "
                    Write-ToLogFile -I -C DNSPreCheck -M "SAN Entry: $record is a valid record"
                    $CheckedSANs += $record
                } else {
                    Write-Host -ForeGroundColor Red -NoNewline " NOT a valid fqdn!"
                    Write-Host -ForeGroundColor Yellow -NoNewline " SKIPPED, "
                }
            }
            ""
            $CertRequest.SANs = $CheckedSANs -Join ","
        }

        Write-ToLogFile -D -C DNSPreCheck -M "ValidationMethod is set to: `"$($CertRequest.ValidationMethod)`"."
    
        if ($CertRequest.ValidationMethod -eq "dns" -and ($AutoRun)) {
            Write-ToLogFile -E -C DNSPreCheck -M "You cannot use the dns validation method with the -AutoRun parameter!"
            Write-Host -ForeGroundColor White -NoNewline " -Wildcard..............: "
            Write-Host -ForeGroundColor RED "A wildcard was found while also using the -AutoRun parameter. Only HTTP validation (no Wildcard) is allowed!"
            Break
        }
        if ($CertRequest.ValidationMethod -in "http", "dns") {
            $DNSObjects = @()
            $ResponderPrio = 10
            $DNSObjects += [PSCustomObject]@{
                DNSName       = [String]$($CertRequest.CN)
                IPAddress     = $null
                Status        = $null
                Match         = $null
                SAN           = $false
                Challenge     = $null
                ResponderPrio = $ResponderPrio
                Done          = $false
            }
            if (-not ([String]::IsNullOrEmpty($($CertRequest.SANs)))) {
                Write-ToLogFile -I -C DNSPreCheck -M "Checking for double SAN values."
                $SANRecords = $CertRequest.SANs.Split(",").Split(" ")
                $SANCount = $SANRecords.Count
                $SANRecords = $SANRecords | Select-Object -Unique
                $CertRequest.SANs = $SANRecords -Join ","

                if (-Not ($SANCount -eq $SANRecords.Count)) {
                    Write-Host -ForeGroundColor White -NoNewline " -Double Records........: "
                    Write-Host -ForeGroundColor Yellow "WARNING: There were $($SANCount - $SANRecords.Count) double SAN values, only continuing with unique ones."
                    Write-ToLogFile -W -C DNSPreCheck -M "There were $($SANCount - $SANRecords.Count) double SAN values, only continuing with unique ones."
                } else {
                    Write-ToLogFile -I -C DNSPreCheck -M "No double SAN values found."
                }
                Foreach ($SANEntry in $SANRecords) {
                    $ResponderPrio += 10
                    if (-Not ($SANEntry -eq $($CertRequest.CN))) {
                        $DNSObjects += [PSCustomObject]@{
                            DNSName       = [String]$SANEntry
                            IPAddress     = $null
                            Status        = $null
                            Match         = $null
                            SAN           = $true
                            Challenge     = $null
                            ResponderPrio = [int]$ResponderPrio
                            Done          = $false
                        }
                    } else {
                        Write-Warning "Double record found, SAN value `"$SANEntry`" is the same as CN value `"$($CertRequest.CN)`". Removed double SAN entry."
                        Write-ToLogFile -W -C DNSPreCheck -M "Double record found, SAN value `"$SANEntry`" is the same as CN value `"$($CertRequest.CN)`". Removed double SAN entry."
                    }
                }
            }
            Write-ToLogFile -D -C DNSPreCheck -M "DNS Data:"
            $DNSObjects | Select-Object DNSName, SAN | ForEach-Object {
                Write-ToLogFile -D -C DNSPreCheck -M "$($_ | ConvertTo-Json -Compress)"
            }
        }
    
        #endregion DNSPreCheck
    
        #region Registration
    
        if ($CertRequest.ValidationMethod -in "http", "dns") {
            Write-Host -ForeGroundColor White "`r`nLet's Encrypt Account & Registration"
            Write-Host -ForeGroundColor White -NoNewLine " -Registration..........: "
            try {
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                Write-ToLogFile -I -C Registration -M "Try to retrieve the existing Registration."
                $PARegistration = Posh-ACME\Get-PAAccount -List -Contact $CertRequest.EmailAddress -Refresh | Where-Object { ($_.status -eq "valid") -and ($_.KeyLength -eq $CertRequest.KeyLength) }
                if ($PARegistration -is [system.array]) {
                    $PARegistration = $PARegistration | Sort-Object id | Select-Object -Last 1
                }
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                if ($PARegistration.Contact -contains "mailto:$($CertRequest.EmailAddress)") {
                    Write-ToLogFile -I -C Registration -M "Existing registration found, no changes necessary."
                } else {
                    if ([String]::IsNullOrEmpty($($PARegistration.Contact))) {
                        $CurrentAddress = "<empty>"
                    } else {
                        $CurrentAddress = $PARegistration.Contact
                    }
                    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                    Write-ToLogFile -I -C Registration -M "Current registration `"$CurrentAddress`" is not equal to `"$($CertRequest.EmailAddress)`", setting new registration."
                    $PARegistration = Posh-ACME\New-PAAccount -Contact $($CertRequest.EmailAddress) -KeyLength $CertRequest.KeyLength -AcceptTOS
                }
            } catch {
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                Write-ToLogFile -I -C Registration -M "Setting new registration to `"$($CertRequest.EmailAddress)`"."
                try {
                    $PARegistration = Posh-ACME\New-PAAccount -Contact $($CertRequest.EmailAddress) -KeyLength $CertRequest.KeyLength -AcceptTOS
                    Write-ToLogFile -I -C Registration -M "New registration successful."
                } catch {
                    Write-ToLogFile -E -C Registration -M "Error New registration failed! Exception Message: $($_.Exception.Message)"
                    Write-Host -ForeGroundColor Red "`nError New registration failed!"
                }
            }
            try {
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                Set-PAAccount -ID $PARegistration.id | out-null
                Write-ToLogFile -I -C Registration -M "Account $($PARegistration.id) set as default."
            } catch {
                Write-ToLogFile -E -C Registration -M "Could not set default account. Exception Message: $($_.Exception.Message)."
            }
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            $PARegistration = Posh-ACME\Get-PAAccount -List -Contact $($CertRequest.EmailAddress) -Refresh | Where-Object { ($_.status -eq "valid") -and ($_.KeyLength -eq $CertRequest.KeyLength) }
            Write-ToLogFile -D -C Registration -M "Registration: $($PARegistration | ConvertTo-Json -Compress)."
            if (-not ($PARegistration.Contact -contains "mailto:$($CertRequest.EmailAddress)")) {
                Write-Host -ForeGroundColor Red " Error"
                Write-ToLogFile -E -C Registration -M "User registration failed."
                Write-Error "User registration failed"
                TerminateScript 1 "User registration failed"
            }
            if ($PARegistration.status -ne "valid") {
                Write-Host -ForeGroundColor Red " Error"
                Write-ToLogFile -E -C Registration -M "Account status is $($Account.status)."
                Write-Error  "Account status is $($Account.status)"
                TerminateScript 1 "Account status is $($Account.status)"
            } else {
                Write-ToLogFile -I -C Registration -M "Registration ID: $($PARegistration.id), Status: $($PARegistration.status)."
                Write-ToLogFile -I -C Registration -M "Setting Account as default for new order."
                Posh-ACME\Set-PAAccount -ID $PARegistration.id -Force
            }
            Write-Host -ForeGroundColor Green " Ready [$($PARegistration.Contact)]"
        }
    
        #endregion Registration
    
        #region Order
    
        if (($CertRequest.ValidationMethod -in "http", "dns")) {
            if ([String]::IsNullOrEmpty($($CertRequest.FriendlyName))) {
                $CertRequest.FriendlyName = $CertRequest.CN
            }
        
            Write-Host -ForeGroundColor White -NoNewLine " -Order.................: "
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            try {
                Write-ToLogFile -I -C Order -M "Trying to create a new order."
                $domains = $DNSObjects | Select-Object DNSName -ExpandProperty DNSName
                $PAOrder = Posh-ACME\New-PAOrder -Domain $domains -KeyLength $CertRequest.KeyLength -Force -FriendlyName $CertRequest.FriendlyName -PfxPass $(ConvertTo-PlainText -SecureString $PfxPassword)
                Start-Sleep -Seconds 1
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                Write-ToLogFile -D -C Order -M "Order data:"
                $PAOrder | Select-Object MainDomain, FriendlyName, SANs, status, expires, KeyLength | ForEach-Object {
                    Write-ToLogFile -D -C Order -M "$($_ | ConvertTo-Json -Compress)"
                }
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                $PAChallenges = $PAOrder | Posh-ACME\Get-PAOrder -Refresh | Posh-ACME\Get-PAAuthorizations
                Write-ToLogFile -D -C Order -M "Challenge status: "
                $PAChallenges | Select-Object DNSId, status, HTTP01Status, DNS01Status | ForEach-Object {
                    Write-ToLogFile -D -C Order -M "$($_ | ConvertTo-Json -Compress)"
                }
                Write-ToLogFile -I -C Order -M "Order created successfully."
            } catch {
                Write-Host -ForeGroundColor Red " Error"
                Write-ToLogFile -E -C Order -M "Could not create the order. You can retry with specifying the `"-CleanPoshACMEStorage`" parameter. "
                Write-ToLogFile -E -C Order -M "Exception Message: $($_.Exception.Message)"
                Write-Host -ForeGroundColor Red "ERROR: Could not create the order. You can retry with specifying the `"-CleanPoshACMEStorage`" parameter."
                TerminateScript 1 "Could not create the order. You can retry with specifying the `"-CleanPoshACMEStorage`" parameter."
            }
            Write-Host -ForeGroundColor Green " Ready"
        }
    
        #endregion Order
    
        #region DNS-Validation
    
        if (($CertRequest.ValidationMethod -in "http", "dns")) {
            Write-Host -ForeGroundColor White "`r`nDNS - Validate Records"
            Write-Host -ForeGroundColor White -NoNewLine " -Checking records......: "
            Write-ToLogFile -I -C DNS-Validation -M "Validate DNS record(s)."
            Foreach ($DNSObject in $DNSObjects) {
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                if ($IPv6) {
                    $DNSObject.IPAddress = "::"
                } else {
                    $DNSObject.IPAddress = "0.0.0.0"
                }
                $DNSObject.Status = $false
                $DNSObject.Match = $false
                try {
                    $PAChallenge = $PAChallenges | Where-Object { $_.fqdn -eq $DNSObject.DNSName }
                    if ([String]::IsNullOrWhiteSpace($PAChallenge)) {
                        Write-Host -ForeGroundColor Red " Error [$($DNSObject.DNSName)]"
                        Write-ToLogFile -E -C DNS-Validation -M "No valid Challenge found."
                        Write-Error "No valid Challenge found"
                        TerminateScript 1 "No valid Challenge found"
                    } else {
                        $DNSObject.Challenge = $PAChallenge
                    }
                    if ($($Parameters.settings.DisableIPCheck)) {
                        $DNSObject.IPAddress = "NoIPCheck"
                        $DNSObject.Match = $true
                        $DNSObject.Status = $true
                    } else {
                        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                        Write-ToLogFile -I -C DNS-Validation -M "Using public DNS server ($PublicDnsServer) to verify dns records."
                        Write-ToLogFile -D -C DNS-Validation -M "Trying to get IP Address."
                        if ($IPv6) {
                            try {
                                $PublicIP = (Resolve-DnsName -Server $PublicDnsServer -Name $DNSObject.DNSName -DnsOnly -Type AAAA -ErrorAction Stop).IPAddress
                            } catch {
                                $PublicIP = (Resolve-DnsName -Server $PublicDnsServerv6 -Name $DNSObject.DNSName -DnsOnly -Type AAAA -ErrorAction SilentlyContinue).IPAddress
                            }
                        } else {
                            $PublicIP = (Resolve-DnsName -Server $PublicDnsServer -Name $DNSObject.DNSName -DnsOnly -Type A -ErrorAction SilentlyContinue).IPAddress
                        }
                        if ([String]::IsNullOrWhiteSpace($PublicIP)) {
                            Write-Host -ForeGroundColor Red " Error [$($DNSObject.DNSName)]"
                            Write-ToLogFile -E -C DNS-Validation -M "No valid (public) IP Address found for DNSName:`"$($DNSObject.DNSName)`"."
                            Write-Error "No valid (public) IP Address found for DNSName:`"$($DNSObject.DNSName)`""
                            TerminateScript 1 "No valid (public) IP Address found for DNSName:`"$($DNSObject.DNSName)`""
                        } elseif ($PublicIP -is [system.array]) {
                            Write-ToLogFile -W -C DNS-Validation -M "More than one ip address found:"
                            $PublicIP | ForEach-Object {
                                Write-ToLogFile -D -C DNS-Validation -M "$($_ | ConvertTo-Json -Compress)"
                            }
                        
                            Write-Warning "More than one ip address found`n$($PublicIP | Format-List | Out-String)"
                            $DNSObject.IPAddress = $PublicIP | Select-Object -First 1
                            Write-ToLogFile -W -C DNS-Validation -M "using the first one`"$($DNSObject.IPAddress)`"."
                            Write-Warning "using the first one`"$($DNSObject.IPAddress)`""
                        } else {
                            Write-ToLogFile -D -C DNS-Validation -M "Saving Public IP Address `"$PublicIP`"."
                            $DNSObject.IPAddress = $PublicIP
                        }
                    }
                } catch {
                    Write-ToLogFile -E -C DNS-Validation -M "Error while retrieving IP Address. Exception Message: $($_.Exception.Message)"
                    Write-Host -ForeGroundColor Red "Error while retrieving IP Address,"
                    if ($DNSObject.SAN) {
                        Write-Host -ForeGroundColor Red "you can try to re-run the script with the -DisableIPCheck parameter."
                        Write-Host -ForeGroundColor Red "The script will continue but `"$DNSRecord`" will be skipped"
                        Write-ToLogFile -E -C DNS-Validation -M "You can try to re-run the script with the -DisableIPCheck parameter. The script will continue but `"$DNSRecord`" will be skipped."
                        $DNSObject.IPAddress = "Skipped"
                        $DNSObject.Match = $true
                    } else {
                        Write-Host -ForeGroundColor Red " Error [$($DNSObject.DNSName)]"
                        Write-Host -ForeGroundColor Red "you can try to re-run the script with the -DisableIPCheck parameter."
                        Write-ToLogFile -E -C DNS-Validation -M "You can try to re-run the script with the -DisableIPCheck parameter."
                        TerminateScript 1 "You can try to re-run the script with the -DisableIPCheck parameter."
                    }
                }
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                if ($DNSObject.SAN) {
                    $CNObject = $DNSObjects | Where-Object { $_.SAN -eq $false }
                    Write-ToLogFile -I -C DNS-Validation -M "All IP Addresses must match, checking..."
                    if ($DNSObject.IPAddress -match $CNObject.IPAddress) {
                        Write-ToLogFile -I -C DNS-Validation -M "`"$($DNSObject.IPAddress)/($($DNSObject.DNSName))`" matches to `"$($CNObject.IPAddress)/($($CNObject.DNSName))`"."
                        $DNSObject.Match = $true
                        $DNSObject.Status = $true
                    } else {
                        Write-ToLogFile -W -C DNS-Validation -M "`"$($DNSObject.IPAddress)/($($DNSObject.DNSName))`" Doesn't match to `"$($CNObject.IPAddress)/($($CNObject.DNSName))`"."
                        $DNSObject.Match = $false
                    }
                } else {
                    Write-ToLogFile -I -C DNS-Validation -M "`"$($DNSObject.IPAddress)/($($DNSObject.DNSName))`" is the first entry, continuing."
                    $DNSObject.Status = $true
                    $DNSObject.Match = $true
                }
            }
            Write-ToLogFile -D -C DNS-Validation -M "SAN Objects:"
            $DNSObjects | Select-Object DNSName, IPAddress, Status, Match | ForEach-Object {
                Write-ToLogFile -D -C DNS-Validation -M "$($_ | ConvertTo-Json -Compress)"
            }
            Write-Host -ForeGroundColor Green " Ready"
        }
        if ($CertRequest.ValidationMethod -eq "http") {
            Write-Host -ForeGroundColor White -NoNewLine " -Checking for errors...: "
            Write-ToLogFile -I -C DNS-Validation -M "Checking for invalid DNS Records."
            $InvalidDNS = $DNSObjects | Where-Object { $_.Status -eq $false }
            $SkippedDNS = $DNSObjects | Where-Object { $_.IPAddress -eq "Skipped" }
            if ($InvalidDNS) {
                Write-Host -ForeGroundColor Red " Error"
                Write-ToLogFile -E -C DNS-Validation -M "Invalid DNS object(s):"
                $InvalidDNS | Select-Object DNSName, Status | ForEach-Object {
                    Write-ToLogFile -D -C DNS-Validation -M "$($_ | ConvertTo-Json -Compress)"
                }
                $DNSObjects | Select-Object DNSName, IPAddress -First 1 | Format-List | Out-String | ForEach-Object { Write-Host -ForeGroundColor Green "$_" }
                $InvalidDNS | Select-Object DNSName, IPAddress | Format-List | Out-String | ForEach-Object { Write-Host -ForeGroundColor Red "$_" }
                Write-Error -Message "Invalid (not registered?) DNS Record(s) found!"
                TerminateScript 1 "Invalid (not registered?) DNS Record(s) found!"
            } else {
                Write-ToLogFile -I -C DNS-Validation -M "None found, continuing"
            }
            if ($SkippedDNS) {
                Write-Warning "The following DNS object(s) will be skipped:`n$($SkippedDNS | Select-Object DNSName | Format-List | Out-String)"
                Write-ToLogFile -W -C DNS-Validation -M "The following DNS object(s) will be skipped:"
                $SkippedDNS | Select-Object DNSName | ForEach-Object {
                    Write-ToLogFile -D -C DNS-Validation -M "Skipped: $($_ | ConvertTo-Json -Compress)"
                }
            }
            Write-ToLogFile -I -C DNS-Validation -M "Checking non-matching DNS Records"
            $DNSNoMatch = $DNSObjects | Where-Object { $_.Match -eq $false }
            if ($DNSNoMatch -and (-not $($Parameters.settings.DisableIPCheck))) {
                Write-Host -ForeGroundColor Red " Error"
                Write-ToLogFile -E -C DNS-Validation -M "Non-matching records found, must match to `"$($DNSObjects[0].DNSName)`" ($($DNSObjects[0].IPAddress))"
                $DNSNoMatch | Select-Object DNSName, Match | ForEach-Object {
                    Write-ToLogFile -D -C DNS-Validation -M "$($_ | ConvertTo-Json -Compress)"
                }
                $DNSObjects[0] | Select-Object DNSName, IPAddress | Format-List | Out-String | ForEach-Object { Write-Host -ForeGroundColor Green "$_" }
                $DNSNoMatch | Select-Object DNSName, IPAddress | Format-List | Out-String | ForEach-Object { Write-Host -ForeGroundColor Red "$_" }
                Write-Error "Non-matching records found, must match to `"$($DNSObjects[0].DNSName)`" ($($DNSObjects[0].IPAddress))."
                TerminateScript 1 "Non-matching records found, must match to `"$($DNSObjects[0].DNSName)`" ($($DNSObjects[0].IPAddress))."
            } elseif ($($Parameters.settings.DisableIPCheck)) {
                Write-ToLogFile -I -C DNS-Validation -M "IP Addresses checking was skipped."
            } else {
                Write-ToLogFile -I -C DNS-Validation -M "All IP Addresses match."
            }
            Write-Host -ForeGroundColor Green "Done"
        }
    
        #endregion DNS-Validation
    
        #region CheckOrderValidation
    
        if ($CertRequest.ValidationMethod -eq "http") {
            Write-ToLogFile -I -C CheckOrderValidation -M "Checking if validation is required."
            $PAOrderItems = Posh-ACME\Get-PAOrder -Refresh -MainDomain $($CertRequest.CN) | Posh-ACME\Get-PAAuthorizations
            $ValidationRequired = $PAOrderItems | Where-Object { $_.status -ne "valid" }
            Write-ToLogFile -D -C CheckOrderValidation -M "$($ValidationRequired.Count) validations required:"
            $ValidationRequired | Select-Object fqdn, status, HTTP01Status, Expires | ForEach-Object {
                Write-ToLogFile -D -C CheckOrderValidation -M "$($_ | ConvertTo-Json -Compress)"
            }
        
            if ($ValidationRequired.Count -eq 0) {
                Write-ToLogFile -I -C CheckOrderValidation -M "Validation NOT required."
                $ADCActionsRequired = $false
            } else {
                Write-ToLogFile -I -C CheckOrderValidation -M "Validation IS required."
                $ADCActionsRequired = $true
    
            }
            Write-ToLogFile -D -C CheckOrderValidation -M "ADC actions required: $($ADCActionsRequired)."
        }
    
        #endregion CheckOrderValidation
    
        #region ConfigureADC
    
        if ($ADCActionsRequired -and ($CertRequest.ValidationMethod -eq "http")) {
            Invoke-AddInitialADCConfig
        }
        #endregion ConfigureADC
    
        #region CheckDNS
    
        if (($ADCActionsRequired) -and ($CertRequest.ValidationMethod -eq "http")) {
            Invoke-CheckDNS
        }
        #endregion CheckDNS
    
        #region OrderValidation
    
        if ($CertRequest.ValidationMethod -eq "http") {
            Write-ToLogFile -I -C OrderValidation -M "Configuring the ADC Responder Policies/Actions required for the validation."
            Write-ToLogFile -D -C OrderValidation -M "PAOrderItems:"
            $PAOrderItems | Select-Object fqdn, status, Expires, HTTP01Status, DNS01Status | ForEach-Object {
                Write-ToLogFile -D -C OrderValidation -M "$($_ | ConvertTo-Json -Compress)"
            }
            Write-Host -ForeGroundColor White "`r`nADC - Order Validation"
            foreach ($DNSObject in $DNSObjects) {
                $ADCKeyAuthorization = $null
                $PAOrderItem = $PAOrderItems | Where-Object { $_.fqdn -eq $DNSObject.DNSName }
                Write-Host -ForeGroundColor White -NoNewLine " -DNS Hostname..........: "
                Write-Host -ForeGroundColor Cyan "$($DNSObject.DNSName)"
                Write-Host -ForeGroundColor White -NoNewLine " -Ready for Validation..: "
                if ($PAOrderItem.status -eq "valid") {
                    Write-Host -ForeGroundColor Green "=> N/A, Still valid"
                    Write-ToLogFile -I -C OrderValidation -M "`"$($DNSObject.DNSName)`" is valid, nothing to configure."
                } else {
                    Write-ToLogFile -I -C OrderValidation -M "New validation required for `"$($DNSObject.DNSName)`", Start configuring the ADC."
                    $PAToken = ".well-known/acme-challenge/$($PAOrderItem.HTTP01Token)"
                    $KeyAuth = Posh-ACME\Get-KeyAuthorization -Token $($PAOrderItem.HTTP01Token) -Account $PAAccount
                    $ADCKeyAuthorization = "HTTP/1.0 200 OK\r\n\r\n$($KeyAuth)"
                    $RspName = "{0}_{1}" -f $($Parameters.settings.RspName), $DNSObject.ResponderPrio
                    $RsaName = "{0}_{1}" -f $($Parameters.settings.RsaName), $DNSObject.ResponderPrio
                    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                    try {
                        Write-ToLogFile -I -C OrderValidation -M "Add Responder Action `"$RsaName`" to return `"$ADCKeyAuthorization`"."
                        $payload = @{"name" = "$RsaName"; "type" = "respondwith"; "target" = "`"$ADCKeyAuthorization`""; }
                        $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type responderaction -Payload $payload -Action add
                        Write-ToLogFile -I -C OrderValidation -M "Responder Action added successfully."
                        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                        try {
                            Write-ToLogFile -I -C OrderValidation -M "Add Responder Policy `"$RspName`" to: `"HTTP.REQ.URL.CONTAINS(`"$PAToken`")`""
                            $payload = @{"name" = "$RspName"; "action" = "$RsaName"; "rule" = "HTTP.REQ.URL.CONTAINS(`"$PAToken`")"; }
                            $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type responderpolicy -Payload $payload -Action add
                            Write-ToLogFile -I -C OrderValidation -M "Responder Policy added successfully."
                            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                            try {
                                Write-ToLogFile -I -C OrderValidation -M "Trying to bind the Responder Policy `"$RspName`" to LoadBalance VIP: `"$($Parameters.settings.LbName)`""
                                $payload = @{"name" = "$($Parameters.settings.LbName)"; "policyname" = "$RspName"; "priority" = "$($DNSObject.ResponderPrio)"; }
                                $response = Invoke-ADCRestApi -Session $ADCSession -Method PUT -Type lbvserver_responderpolicy_binding -Payload $payload -Resource $($Parameters.settings.LbName)
                                Write-ToLogFile -I -C OrderValidation -M "Responder Policy successfully bound to Load Balance VIP."
                                try {
                                    Write-ToLogFile -I -C OrderValidation -M "Sending acknowledgment to Let's Encrypt."
                                    Send-ChallengeAck -ChallengeUrl $($PAOrderItem.HTTP01Url) -Account $PAAccount
                                    Write-ToLogFile -I -C OrderValidation -M "Successfully send."
                                } catch {
                                    Write-ToLogFile -E -C OrderValidation -M "Error while submitting the Challenge. Exception Message: $($_.Exception.Message)"
                                    Write-Host -ForegroundColor Red "`r`nERROR: Error while submitting the Challenge."
                                    Register-FatalError 1 "Error while submitting the Challenge."
                                    Break
                                }
                                Write-Host -ForeGroundColor Green " Ready"
                            } catch {
                                Write-ToLogFile -E -C OrderValidation -M "Failed to bind Responder Policy to Load Balance VIP. Exception Message: $($_.Exception.Message)"
                                Write-Host -ForeGroundColor Red " ERROR  [Responder Policy Binding - $RspName]"
                                ##TODO Find out why this object is made null here
                                #$ValidationMethod = $null
                                Write-Host -ForegroundColor Red "`r`nERROR: $($_.Exception.Message)"
                                Register-FatalError 1 "Failed to bind Responder Policy to Load Balance VIP"
                                Break
                            }
                        } catch {
                            Write-ToLogFile -E -C OrderValidation -M "Failed to add Responder Policy. Exception Message: $($_.Exception.Message)"
                            Write-Host -ForeGroundColor Red " ERROR  [Responder Policy - $RspName]"
                            Write-Host -ForegroundColor Red "`r`nERROR: $($_.Exception.Message)"
                            Register-FatalError 1 "Failed to add Responder Policy"
                            Break
                        }
                    } catch {
                        Write-ToLogFile -E -C OrderValidation -M "Failed to add Responder Action. Error Details: $($_.Exception.Message)"
                        Write-Host -ForeGroundColor Red " ERROR  [Responder Action - $RsaName]"
                        Write-Host -ForegroundColor Red "`r`nERROR: $($_.Exception.Message)"
                        Register-FatalError 1 "Failed to add Responder Action"
                        Break
                    }
                }
            }
    
            if (-Not $ScriptFatalError.Error) {
                Write-Host -ForeGroundColor White "`r`nWaiting for Order completion"
                Write-Host -ForeGroundColor White -NoNewLine " -Completion............: "
                Write-ToLogFile -I -C OrderValidation -M "Retrieving validation status."
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                $PAOrderItems = Posh-ACME\Get-PAOrder -Refresh -MainDomain $($CertRequest.CN) | Posh-ACME\Get-PAAuthorizations
                Write-ToLogFile -D -C OrderValidation -M "Listing PAOrderItems"
                $PAOrderItems | Select-Object fqdn, status, Expires, HTTP01Status, DNS01Status | ForEach-Object {
                    Write-ToLogFile -D -C OrderValidation -M "$($_ | ConvertTo-Json -Compress)"
                }
                $WaitLoop = 10
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                Write-ToLogFile -D -C OrderValidation -M "Items still pending: $(($PAOrderItems | Where-Object { $_.status -eq "pending" }).Count -gt 0)"
                while ($true) {
                    Start-Sleep -Seconds 5
                    $PAOrderItems = Posh-ACME\Get-PAOrder -Refresh -MainDomain $($CertRequest.CN) | Posh-ACME\Get-PAAuthorizations
                    Write-ToLogFile -I -C OrderValidation -M "Still $((($PAOrderItems | Where-Object {$_.status -eq "pending"})| Measure-Object).Count) `"pending`" items left. Waiting an extra 5 seconds."
                    if ($WaitLoop -eq 0) {
                        Write-ToLogFile -D -C OrderValidation -M "Loop ended, max reties reached!"
                        break
                    } elseif ($((($PAOrderItems | Where-Object { $_.status -eq "pending" }) | Measure-Object).Count) -eq 0) {
                        Write-ToLogFile -D -C OrderValidation -M "Loop ended no pending items left."
                        break
                    }
                    $WaitLoop--
                    Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                }
                $PAOrderItems = Posh-ACME\Get-PAOrder -Refresh -MainDomain $($CertRequest.CN) | Posh-ACME\Get-PAAuthorizations
                if ($PAOrderItems | Where-Object { $_.status -ne "valid" }) {
                    Write-Host -ForeGroundColor Red "Failed"
                    Write-ToLogFile -E -C OrderValidation -M "Unfortunately there are invalid items. Failed Records:"
                    $PAOrderItems | Where-Object { $_.status -ne "valid" } | Select-Object fqdn, status, Expires, HTTP01Status, DNS01Status | ForEach-Object {
                        Write-ToLogFile -D -C OrderValidation -M "$($_ | ConvertTo-Json -Compress)"
                    }
                    Write-Host -ForeGroundColor White "`r`nInvalid items:"
                    ForEach ($Item in $($PAOrderItems | Where-Object { $_.status -ne "valid" })) {
                        Write-Host -ForeGroundColor White -NoNewLine " -DNS Hostname..........: "
                        Write-Host -ForeGroundColor Cyan "$($Item.fqdn)"
                        Write-Host -ForeGroundColor White -NoNewLine " -Status................: "
                        Write-Host -ForeGroundColor Red " ERROR [$($Item.status)]"
                    }
                    Write-Host -ForegroundColor Red "`r`nERROR: There are some invalid items"
                    Register-FatalError 1 "There are some invalid items"
                } else {
                    Write-Host -ForeGroundColor Green " Completed"
                    Write-ToLogFile -I -C OrderValidation -M "Validation status finished."
                }
            }
            #endregion OrderValidation

            #region CleanupADC

            if ($CertRequest.ValidationMethod -in "http", "dns") {
                Invoke-ADCCleanup -Full
            }

            #endregion CleanupADC

            #region ExitIfErrors
    
            if ($ScriptFatalError.Error) {
                Register-FatalError -ExitNow
            }
    
            #endregion ExitIfErrors
        }
    
        #region DNSChallenge
    
        if ($CertRequest.ValidationMethod -eq "dns") {
            $PAOrderItems = Posh-ACME\Get-PAOrder -Refresh -MainDomain $($CertRequest.CN) | Posh-ACME\Get-PAAuthorizations
            $TXTRecords = $PAOrderItems | Select-Object fqdn, `
            @{L = 'TXTName'; E = { "_acme-challenge.$($_.fqdn.Replace('*.',''))" } }, `
            @{L = 'TXTValue'; E = { ConvertTo-TxtValue (Get-KeyAuthorization $_.DNS01Token) } }
            Write-Host -ForeGroundColor Magenta "`r`n********************************************************************"
            Write-Host -ForeGroundColor Magenta "* Make sure the following TXT records are configured at your DNS   *"
            Write-Host -ForeGroundColor Magenta "* provider before continuing! If not, DNS validation will fail!    *"
            Write-Host -ForeGroundColor Magenta "********************************************************************"
            Write-ToLogFile -I -C DNSChallenge -M "Make sure the following TXT records are configured at your DNS provider before continuing! If not, DNS validation will fail!"
            foreach ($Record in $TXTRecords) {
                ""
                Write-Host -ForeGroundColor White -NoNewLine " -DNS Hostname..........: "
                Write-Host -ForeGroundColor Cyan "$($Record.fqdn)"
                Write-Host -ForeGroundColor White -NoNewLine " -TXT Record Name.......: "
                Write-Host -ForeGroundColor Yellow "$($Record.TXTName)"
                Write-Host -ForeGroundColor White -NoNewLine " -TXT Record Value......: "
                Write-Host -ForeGroundColor Yellow "$($Record.TXTValue)"
                Write-ToLogFile -I -C DNSChallenge -M "DNS Hostname: `"$($Record.fqdn)`" => TXT Record Name: `"$($Record.TXTName)`", Value: `"$($Record.TXTValue)`"."
            }
            ""
            Write-Host -ForeGroundColor Magenta "********************************************************************"
            $($TXTRecords | Format-List | Out-String).Trim() | clip.exe
            Write-Host -ForegroundColor Yellow "`r`nINFO: Data is copied tot the clipboard"
            $answer = Read-Host -Prompt "Enter `"yes`" when ready to continue"
            if (-not ($answer.ToLower() -eq "yes")) {
                Write-Host -ForegroundColor Yellow "You've entered `"$answer`", last chance to continue"
                $answer = Read-Host -Prompt "Enter `"yes`" when ready to continue, or something else to stop and exit"
                if (-not ($answer.ToLower() -eq "yes")) {
                    Write-Host -ForegroundColor Yellow "You've entered `"$answer`", ending now!"
                    Exit (0)
                }
            }
            Write-Host "Continuing, Waiting 30 seconds for the records to settle"
            Start-Sleep -Seconds 30
            Write-ToLogFile -I -C DNSChallenge -M "Start verifying the TXT records."
            $issues = $false
            try {
                Write-Host -ForeGroundColor White "`r`nPre-Checking the TXT records"
                Foreach ($Record in $TXTRecords) {
                    Write-Host -ForeGroundColor White -NoNewLine " -DNS Hostname..........: "
                    Write-Host -ForeGroundColor Cyan "$($Record.fqdn)"
                    Write-Host -ForeGroundColor White -NoNewLine " -TXT Record check......: "
                    Write-ToLogFile -I -C DNSChallenge -M "Trying to retrieve the TXT record for `"$($Record.fqdn)`"."
                    $result = $null
                    $dnsserver = Resolve-DnsName -Name $Record.TXTName -Server $PublicDnsServer -DnsOnly
                    if ([String]::IsNullOrWhiteSpace($dnsserver.PrimaryServer)) {
                        Write-ToLogFile -D -C DNSChallenge -M "Using DNS Server `"$PublicDnsServer`" for resolving the TXT records."
                        $result = Resolve-DnsName -Name $Record.TXTName -Type TXT -Server $PublicDnsServer -DnsOnly
                    } else {
                        Write-ToLogFile -D -C DNSChallenge -M "Using DNS Server `"$($dnsserver.PrimaryServer)`" for resolving the TXT records."
                        $result = Resolve-DnsName -Name $Record.TXTName -Type TXT -Server $dnsserver.PrimaryServer -DnsOnly
                    }
                    Write-ToLogFile -D -C DNSChallenge -M "Output: $($result | ConvertTo-Json -Compress)"
                    if ([String]::IsNullOrWhiteSpace($result.Strings -like "*$($Record.TXTValue)*")) {
                        Write-Host -ForegroundColor Yellow "Could not determine"
                        $issues = $true
                        Write-ToLogFile -W -C DNSChallenge -M "Could not determine."
                    } else {
                        Write-Host -ForegroundColor Green "OK"
                        Write-ToLogFile -I -C DNSChallenge -M "Check OK."
                    }
                }
            } catch {
                Write-ToLogFile -E -C DNSChallenge -M "Caught an error. Exception Message: $($_.Exception.Message)"
                $issues = $true
            }
            if ($issues) {
                ""
                Write-Warning "Found issues during the initial test. TXT validation might fail. Waiting an additional 30 seconds before continuing..."
                Write-ToLogFile -W -C DNSChallenge -M "Found issues during the initial test. TXT validation might fail."
                Start-Sleep -Seconds 20
            }
        }
    
        #endregion DNSChallenge
    
        #region FinalizingOrder
    
        if ($CertRequest.ValidationMethod -in "dns") {
            Write-ToLogFile -I -C FinalizingOrder -M "Check if DNS Records need to be validated."
            Write-Host -ForeGroundColor White "`r`nSending Acknowledgment"
            Foreach ($DNSObject in $DNSObjects) {
                Write-Host -ForeGroundColor White -NoNewLine " -DNS Hostname..........: "
                Write-Host -ForeGroundColor Cyan "$($DNSObject.DNSName)"
                Write-ToLogFile -I -C FinalizingOrder -M "Validating item: `"$($DNSObject.DNSName)`"."
                Write-Host -ForeGroundColor White -NoNewLine " -Send Ack..............: "
                $PAOrderItem = Posh-ACME\Get-PAOrder -MainDomain $($CertRequest.CN) | Posh-ACME\Get-PAAuthorizations | Where-Object { $_.fqdn -eq $DNSObject.DNSName }
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                Write-ToLogFile -D -C FinalizingOrder -M "OrderItem:"
                $PAOrderItem | Select-Object fqdn, status, DNS01Status, expires | ForEach-Object {
                    Write-ToLogFile -D -C FinalizingOrder -M "$($_ | ConvertTo-Json -Compress)"
                }
                if (($PAOrderItem.DNS01Status -notlike "valid") -and ($PAOrderItem.DNS01Status -notlike "invalid")) {
                    try {
                        Write-ToLogFile -I -C FinalizingOrder -M "Validation required, start submitting Challenge."
                        Posh-ACME\Send-ChallengeAck -ChallengeUrl $($PAOrderItem.DNS01Url) -Account $PAAccount
                        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                        Write-ToLogFile -I -C FinalizingOrder -M "Submitted the Challenge successfully."
                    } catch {
                        Write-Host -ForeGroundColor Red " ERROR"
                        Write-ToLogFile -E -C FinalizingOrder -M "Caught an error. Exception Message: $($_.Exception.Message)"
                        Write-Error "Error while submitting the Challenge"
                        TerminateScript 1 "Error while submitting the Challenge"
                    }
                    Write-Host -ForeGroundColor Green " Sent Successfully"
                } elseif ($PAOrderItem.DNS01Status -like "valid") {
                    Write-ToLogFile -I -C FinalizingOrder -M "The item is valid."
                    $DNSObject.Done = $true
                    Write-Host -ForeGroundColor Green " Still valid"
                } else {
                    Write-ToLogFile -W -C FinalizingOrder -M "Unexpected status: $($PAOrderItem.DNS01Status)"
                }
                $PAOrderItem = $null
            }
            $i = 1
            Write-Host -ForeGroundColor White "`r`nValidation"
            Write-ToLogFile -I -C FinalizingOrder -M "Start validation."
            while ($i -le 20) {
                Write-Host -ForeGroundColor White " -Attempt...............: $i"
                Write-ToLogFile -I -C FinalizingOrder -M "Validation attempt: $i"
                $PAOrderItems = Posh-ACME\Get-PAOrder -MainDomain $($CertRequest.CN) | Posh-ACME\Get-PAAuthorizations
                Foreach ($DNSObject in $DNSObjects) {
                    if ($DNSObject.Done -eq $false) {
                        Write-Host -ForeGroundColor White -NoNewLine " -DNS Hostname..........: "
                        Write-Host -ForeGroundColor Cyan "$($DNSObject.DNSName)"
                        try {
                            $PAOrderItem = $PAOrderItems | Where-Object { $_.fqdn -eq $DNSObject.DNSName }
                            Write-ToLogFile -D -C FinalizingOrder -M "OrderItem:"
                            $PAOrderItem | Select-Object fqdn, status, DNS01Status, expires | ForEach-Object {
                                Write-ToLogFile -D -C FinalizingOrder -M "$($_ | ConvertTo-Json -Compress)"
                            }
                            Write-Host -ForeGroundColor White -NoNewLine " -Status................: "
                            switch ($PAOrderItem.DNS01Status.ToLower()) {
                                "pending" {
                                    Write-Host -ForeGroundColor Yellow "$($PAOrderItem.DNS01Status)"
                                }
                                "invalid" {
                                    $DNSObject.Done = $true
                                    Write-Host -ForeGroundColor Red "$($PAOrderItem.DNS01Status)"
                                }
                                "valid" {
                                    $DNSObject.Done = $true
                                    Write-Host -ForeGroundColor Green "$($PAOrderItem.DNS01Status)"
                                }
                                default {
                                    Write-Host -ForeGroundColor Red "UNKNOWN [$($PAOrderItem.DNS01Status)]"
                                }
                            }
                            Write-ToLogFile -I -C FinalizingOrder -M "$($DNSObject.DNSName): $($PAOrderItem.DNS01Status)"
                        } catch {
                            Write-ToLogFile -E -C FinalizingOrder -M "Error while Retrieving validation status. Exception Message: $($_.Exception.Message)"
                            Write-Error "Error while Retrieving validation status"
                            TerminateScript 1 "Error while Retrieving validation status"
                        }
                        $PAOrderItem = $null
                    }
                }
                if (-NOT ($DNSObjects | Where-Object { $_.Done -eq $false })) {
                    Write-ToLogFile -I -C FinalizingOrder -M "All items validated."
                    if ($PAOrderItems | Where-Object { $_.DNS01Status -eq "invalid" }) {
                        Write-Host -ForegroundColor Red "`r`nERROR: Validation Failed, invalid items found! Exiting now!"
                        Write-ToLogFile -E -C FinalizingOrder -M "Validation Failed, invalid items found!"
                        TerminateScript 1 "Validation Failed, invalid items found!"
                    }
                    if ($PAOrderItems | Where-Object { $_.DNS01Status -eq "pending" }) {
                        Write-Host -ForegroundColor Red "`r`nERROR: Validation Failed, still pending items left! Exiting now!"
                        Write-ToLogFile -E -C FinalizingOrder -M "Validation Failed, still pending items left!"
                        TerminateScript 1 "Validation Failed, still pending items left!"
                    }
                    break
                }
                Write-ToLogFile -I -C FinalizingOrder -M "Waiting, round: $i"
                Start-Sleep -Seconds 1
                $i++
                ""
            }
        }
    
        if ($CertRequest.ValidationMethod -in "http", "dns") {
            Write-Host -ForeGroundColor White "`r`nCertificates"
            Write-Host -ForeGroundColor White -NoNewLine " -Status................: "
            Write-ToLogFile -I -C FinalizingOrder -M "Checking if order is ready."
            $Order = $PAOrder | Posh-ACME\Get-PAOrder -Refresh
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            Write-ToLogFile -D -C FinalizingOrder -M "Order state: $($Order.status)"
            if ($Order.status -eq "ready") {
                Write-ToLogFile -I -C FinalizingOrder -M "Order is ready."
            } else {
                Write-ToLogFile -I -C FinalizingOrder -M "Order is still not ready, validation failed?" -Verbose
            }
            Write-ToLogFile -I -C FinalizingOrder -M "Requesting certificate."
            try {
                $NewCertificates = New-PACertificate -Domain $($DNSObjects.DNSName) -DirectoryUrl $BaseService -PfxPass $(ConvertTo-PlainText -SecureString $PfxPassword) -CertKeyLength $CertRequest.KeyLength -FriendlyName $CertRequest.FriendlyName -ErrorAction Stop
                Write-ToLogFile -D -C FinalizingOrder -M "$($NewCertificates | Select-Object Subject,NotBefore,NotAfter,KeyLength | ConvertTo-Json -Compress)"
                Write-ToLogFile -I -C FinalizingOrder -M "Certificate requested successfully."
            } catch {
                Write-ToLogFile -I -C FinalizingOrder -M "Failed to request certificate."
            }
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            Start-Sleep -Seconds 1
        }
    
        #endregion FinalizingOrder
    
        #region CertFinalization
    
        if ($CertRequest.ValidationMethod -in "http", "dns") {
            Write-Host -ForeGroundColor Yellow -NoNewLine "*"
            $CertificateAlias = "CRT-SAN-$SessionDateTime-$($CertRequest.CN.Replace('*.',''))"
            $CertificateDirectory = Join-Path -Path $($CertRequest.CertDir) -ChildPath "$CertificateAlias"
            Write-ToLogFile -I -C CertFinalization -M "Create directory `"$CertificateDirectory`" for storing the new certificates."
            New-Item $CertificateDirectory -ItemType directory -force | Out-Null
            $CertificateName = "$($ScriptDateTime.ToString("yyyyMMddHHmm"))-$($CertRequest.CN.Replace('*.',''))"
            if (Test-Path $CertificateDirectory) {
                Write-ToLogFile -I -C CertFinalization -M "Retrieving certificate info."
                $PACertificate = Posh-ACME\Get-PACertificate -MainDomain $($CertRequest.CN)
                Write-ToLogFile -I -C CertFinalization -M "Retrieved successfully."
                $ChainFile = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 "$($PACertificate.ChainFile)"
                $CAName = $ChainFile.DnsNameList.Unicode.Replace("'", "")
                $IntermediateCACertKeyName = "$($CAName)-int"
                $IntermediateCAFileName = "$($IntermediateCACertKeyName).crt"
                $IntermediateCAFullPath = Join-Path -Path $CertificateDirectory -ChildPath $IntermediateCAFileName
    
                Write-ToLogFile -D -C CertFinalization -M "Intermediate: `"$IntermediateCAFileName`"."
                Copy-Item $PACertificate.ChainFile -Destination $IntermediateCAFullPath -Force
                if ($Production) {
                    if ($CertificateName.length -ge 31) {
                        $CertificateName = "$($CertificateName.subString(0,31))"
                        Write-ToLogFile -D -C CertFinalization -M "CertificateName (new name): `"$CertificateName`" ($($CertificateName.length) max 31)"
                    } else {
                        $CertificateName = "$CertificateName"
                        Write-ToLogFile -D -C CertFinalization -M "CertificateName: `"$CertificateName`" ($($CertificateName.length) max 31)"
                    }
                    if ($CertificateAlias.length -ge 59) {
                        $CertificateFileName = "$($CertificateAlias.subString(0,59)).crt"
                        Write-ToLogFile -D -C CertFinalization -M "Certificate (new name): `"$CertificateFileName`"($($CertificateFileName.length) max 63)"
                        $CertificateKeyFileName = "$($CertificateAlias.subString(0,59)).key"
                        Write-ToLogFile -D -C CertFinalization -M "Key (new name): `"$CertificateKeyFileName`"($($CertificateFileName.length) max 63)"
                    } else {
                        $CertificateFileName = "$($CertificateAlias).crt"
                        Write-ToLogFile -D -C CertFinalization -M "Certificate: `"$CertificateFileName`" ($($CertificateFileName.length) max 63)"
                        $CertificateKeyFileName = "$($CertificateAlias).key"
                        Write-ToLogFile -D -C CertFinalization -M "Key: `"$CertificateKeyFileName`"($($CertificateFileName.length) max 63)"
                    }
                    $CertificatePfxFileName = "$CertificateAlias.pfx"
                    $CertificatePemFileName = "$CertificateAlias.pem"
                    $CertificatePfxWithChainFileName = "$($CertificateAlias)-WithChain.pfx"
                } else {
                    if ($CertificateName.length -ge 27) {
                        $CertificateName = "TST-$($CertificateName.subString(0,27))"
                        Write-ToLogFile -D -C CertFinalization -M "CertificateName (new name): `"$CertificateName`" ($($CertificateName.length) max 31)"
                    } else {
                        $CertificateName = "TST-$($CertificateName)"
                        Write-ToLogFile -D -C CertFinalization -M "CertificateName: `"$CertificateName`" ($($CertificateName.length) max 31)"
                    }
                    if ($CertificateAlias.length -ge 55) {
                        $CertificateFileName = "TST-$($CertificateAlias.subString(0,55)).crt"
                        Write-ToLogFile -D -C CertFinalization -M "Certificate (new name): `"$CertificateFileName`"($($CertificateFileName.length) max 63)"
                        $CertificateKeyFileName = "TST-$($CertificateAlias.subString(0,55)).key"
                        Write-ToLogFile -D -C CertFinalization -M "Key (new name): `"$CertificateKeyFileName`"($($CertificateFileName.length) max 63)"
                    } else {
                        $CertificateFileName = "TST-$($CertificateAlias).crt"
                        Write-ToLogFile -D -C CertFinalization -M "Certificate: `"$CertificateFileName`"($($CertificateFileName.length) max 63)"
                        $CertificateKeyFileName = "TST-$($CertificateAlias).key"
                        Write-ToLogFile -D -C CertFinalization -M "Key: `"$CertificateKeyFileName`"($($CertificateFileName.length) max 63)"
                    }
                    $CertificatePfxFileName = "TST-$CertificateAlias.pfx"
                    $CertificatePemFileName = "TST-$CertificateAlias.pem"
                    $CertificatePfxWithChainFileName = "TST-$($CertificateAlias)-WithChain.pfx"
                }
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                $CertificateFullPath = Join-Path -Path $CertificateDirectory -ChildPath $CertificateFileName
                $CertificateKeyFullPath = Join-Path -Path $CertificateDirectory -ChildPath $CertificateKeyFileName
                $CertificatePfxFullPath = Join-Path -Path $CertificateDirectory -ChildPath $CertificatePfxFileName
                $CertificatePfxWithChainFullPath = Join-Path -Path $CertificateDirectory -ChildPath $CertificatePfxWithChainFileName
                Write-ToLogFile -D -C CertFinalization -M "PFX: `"$CertificatePfxFileName`" ($($CertificatePfxFileName.length))"
                Copy-Item $PACertificate.CertFile -Destination $CertificateFullPath -Force
                Copy-Item $PACertificate.KeyFile -Destination $CertificateKeyFullPath -Force
                Copy-Item $PACertificate.PfxFullChain -Destination $CertificatePfxWithChainFullPath -Force
                $certificate = Get-PfxData -FilePath $CertificatePfxWithChainFullPath -Password $PfxPassword
                $NewCertificates = Export-PfxCertificate -PfxData $certificate -FilePath $CertificatePfxFullPath -Password $PfxPassword -ChainOption EndEntityCertOnly -Force
                Write-ToLogFile -I -C CertFinalization -M "Certificates Finished."
            } else {
                Write-ToLogFile -E -C CertFinalization -M "Could not test Certificate directory."
            }
        }
    
        #endregion CertFinalization
    
        #region ADC-CertUpload
    
        if ($CertRequest.ValidationMethod -in "http", "dns") {
            try {
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                Write-ToLogFile -I -C ADC-CertUpload -M "Uploading the certificate to the Citrix ADC."
                Write-ToLogFile -D -C ADC-CertUpload -M "Retrieving existing CA Intermediate Certificate."
                $Filters = @{"serial" = "$($ChainFile.SerialNumber)" }
                $ADCIntermediateCA = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type sslcertkey -Filters $Filters -ErrorAction SilentlyContinue
                if ([String]::IsNullOrEmpty($($ADCIntermediateCA.sslcertkey.certkey))) {
                    Write-ToLogFile -D -C ADC-CertUpload -M "Second attempt, trying without leading zero's."
                    $Filters = @{"serial" = "$($ChainFile.SerialNumber.TrimStart("00"))" }
                    $ADCIntermediateCA = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type sslcertkey -Filters $Filters -ErrorAction SilentlyContinue
                }
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                Write-ToLogFile -D -C ADC-CertUpload -M "Details:"
                $ADCIntermediateCA.sslcertkey | Select-Object certkey, issuer, subject, serial, clientcertnotbefore, clientcertnotafter | ForEach-Object {
                    Write-ToLogFile -D -C ADC-CertUpload -M "$($_ | ConvertTo-Json -Compress)"
                }
                Write-ToLogFile -D -C ADC-CertUpload -M "Checking if IntermediateCA `"$IntermediateCACertKeyName`" already exists."
                if ([String]::IsNullOrEmpty($($ADCIntermediateCA.sslcertkey.certkey))) {
                    try {
                        Write-ToLogFile -I -C ADC-CertUpload -M "Uploading `"$IntermediateCAFileName`" to the ADC."
                        $IntermediateCABase64 = [System.Convert]::ToBase64String($(Get-Content $IntermediateCAFullPath -Encoding "Byte"))
                        $payload = @{"filename" = "$IntermediateCAFileName"; "filecontent" = "$IntermediateCABase64"; "filelocation" = "/nsconfig/ssl/"; "fileencoding" = "BASE64"; }
                        $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type systemfile -Payload $payload
                        Write-ToLogFile -I -C ADC-CertUpload -M "Succeeded, Add the certificate to the ADC config."
                        $payload = @{"certkey" = "$IntermediateCACertKeyName"; "cert" = "/nsconfig/ssl/$($IntermediateCAFileName)"; }
                        $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type sslcertkey -Payload $payload
                        Write-ToLogFile -I -C ADC-CertUpload -M "Certificate added."
                    } catch {
                        Write-Warning "Could not upload or get the Intermediate CA ($($ChainFile.DnsNameList.Unicode)), manual action may be required"
                        Write-ToLogFile -W -C ADC-CertUpload -M "Could not upload or get the Intermediate CA ($($ChainFile.DnsNameList.Unicode)), manual action may be required."
                    }
                } else {
                    $IntermediateCACertKeyName = $ADCIntermediateCA.sslcertkey.certkey
                    Write-ToLogFile -D -C ADC-CertUpload -M "IntermediateCA exists, saving existing name `"$IntermediateCACertKeyName`" for later use."
                }
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                if ([String]::IsNullOrEmpty($($CertRequest.CertKeyNameToUpdate))) {
                    Write-ToLogFile -I -C ADC-CertUpload -M "CertKeyNameToUpdate variable was not configured."
                    $ExistingCertificateDetails = $Null
                } else {
                    Write-ToLogFile -D -C ADC-CertUpload -M "CertKeyNameToUpdate: `"$($CertRequest.CertKeyNameToUpdate)`""

                    Write-ToLogFile -I -C ADC-CertUpload -M "CertKeyNameToUpdate variable was configured, trying to retrieve data."
                    $Filters = @{"certkey" = "$($CertRequest.CertKeyNameToUpdate)" }
                    $ExistingCertificateDetails = try { Invoke-ADCRestApi -Session $ADCSession -Method GET -Type sslcertkey -Resource $($CertRequest.CertKeyNameToUpdate) -Filters $Filters -ErrorAction SilentlyContinue } catch { $null }
                }
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                if (-Not [String]::IsNullOrEmpty($($ExistingCertificateDetails.sslcertkey.certkey))) {
                    $CertificateCertKeyName = $($ExistingCertificateDetails.sslcertkey.certkey)
                    Write-ToLogFile -I -C ADC-CertUpload -M "Existing certificate `"$CertificateCertKeyName`" found on the ADC, start updating."
                    try {
                        Write-ToLogFile -D -C ADC-CertUpload -M "Unlinking certificate."
                        $payload = @{"certkey" = "$CertificateCertKeyName"; }
                        $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type sslcertkey -Payload $payload -Action unlink
    
                    } catch {
                        Write-ToLogFile -D -C ADC-CertUpload -M "Certificate was not linked."
                    }
                    $ADCCertKeyUpdating = $true
                } else {
                    Write-ToLogFile -I -C ADC-CertUpload -M "No existing certificate found on the ADC that needs to be updated."
                    $RemovePrevious = $false
                    if (-Not [String]::IsNullOrEmpty($($CertRequest.CertKeyNameToUpdate))) {
                        $CertificateCertKeyName = $($CertRequest.CertKeyNameToUpdate)
                        Write-ToLogFile -I -C ADC-CertUpload -M "Adding new certificate as `"$($CertRequest.CertKeyNameToUpdate)`""
                    } else {
                        $CertificateCertKeyName = $CertificateName
                        $ExistingCertificateDetails = try { Invoke-ADCRestApi -Session $ADCSession -Method GET -Type sslcertkey -Resource $CertificateName -ErrorAction SilentlyContinue } catch { $null }
                        if (-Not [String]::IsNullOrEmpty($($ExistingCertificateDetails.sslcertkey.certkey))) {
                            Write-Warning "Certificate `"$CertificateCertKeyName`" already exists, please update manually! Or if you need to update an existing Certificate, specify the `"-CertKeyNameToUpdate`" Parameter."
                            Write-ToLogFile -W -C ADC-CertUpload -M "Certificate `"$CertificateCertKeyName`" already exists, please update manually! Or if you need to update an existing Certificate, specify the `"-CertKeyNameToUpdate`" Parameter."
                            TerminateScript 1 "Certificate `"$CertificateCertKeyName`" already exists, please update manually! Or if you need to update an existing Certificate, specify the `"-CertKeyNameToUpdate`" Parameter."
                        }
                    }
                    $ADCCertKeyUpdating = $false
                }
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                Write-ToLogFile -D -C ADC-CertUpload -M "CertificateName: $CertificateName"
                Write-ToLogFile -D -C ADC-CertUpload -M "CertificateCertKeyName: $CertificateCertKeyName"
                $CertificatePfxBase64 = [System.Convert]::ToBase64String($(Get-Content $CertificatePfxFullPath -Encoding "Byte"))
                Write-ToLogFile -I -C ADC-CertUpload -M "Uploading the Pfx certificate."
                $payload = @{"filename" = "$CertificatePfxFileName"; "filecontent" = "$CertificatePfxBase64"; filelocation = "/nsconfig/ssl/"; fileencoding = "BASE64"; }
                $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type systemfile -Payload $payload
    
                if ($ADCVersion -lt 12) {
                    Write-ToLogFile -D -C ADC-CertUpload -M "ADC verion is lower than 12, converting the Pfx certificate to a pem file ($CertificatePemFileName)"
                    $payload = @{"outfile" = "$CertificatePemFileName"; "Import" = "true"; "pkcs12file" = "$CertificatePfxFileName"; "des3" = "true"; "password" = "$(ConvertTo-PlainText -SecureString $PfxPassword)"; "pempassphrase" = "$(ConvertTo-PlainText -SecureString $PfxPassword)" }
                    $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type sslpkcs12 -Payload $payload -Action convert
                    $payload = @{certkey = "$CertificateCertKeyName"; cert = "$($CertificatePemFileName)"; key = $CertificatePemFileName; password = true; inform = PEM; passplain = "$(ConvertTo-PlainText -SecureString $PfxPassword)" }
                } else {
                    $payload = @{certkey = $CertificateCertKeyName; cert = $CertificatePfxFileName; key = $CertificatePemFileName; password = "true"; inform = "PFX"; passplain = "$(ConvertTo-PlainText -SecureString $PfxPassword)" }
                }
                try {
                    if ($ADCCertKeyUpdating -And $RemovePrevious) {
                        Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                        Write-ToLogFile -I -C ADC-CertUpload -M "Update the certificate and key to the ADC config."
                        $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type sslcertkey -Payload $payload -Action update
                        Write-ToLogFile -I -C ADC-CertUpload -M "Updated successfully."
                        if ($RemovePrevious) {
                            try {
                                Write-ToLogFile -I -C ADC-RemovePrevious -M "-RemovePrevious parameter was specified, retrieving files."
                                $Arguments = @{ filename = "$($ExistingCertificateDetails.sslcertkey.cert)"; filelocation = "/nsconfig/ssl/" }
                                $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type systemfile -Arguments $Arguments
                                $PreviousCertFileName = $response.systemfile.filename
                                Write-ToLogFile -D -C ADC-RemovePrevious -M "PreviousCertFileName: `"$PreviousCertFileName`""
                                $Arguments = @{ filename = "$($ExistingCertificateDetails.sslcertkey.key)"; filelocation = "/nsconfig/ssl/" }
                                $response = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type systemfile -Arguments $Arguments
                                $PreviousKeyFileName = $response.systemfile.filename
                                Write-ToLogFile -D -C ADC-RemovePrevious -M "PreviousKeyFileName: `"$PreviousKeyFileName`""
                                $Arguments = @{ filelocation = "/nsconfig/ssl/" }
                                if (-Not [String]::IsNullOrEmpty($PreviousCertFileName)) {
                                    Write-ToLogFile -I -C ADC-RemovePrevious -M "Removing file: `"/nsconfig/ssl/$PreviousCertFileName`""
                                    $null = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type systemfile -Resource $PreviousCertFileName -Arguments $Arguments
                                    Write-ToLogFile -I -C ADC-RemovePrevious -M "Success"
                                }
                                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                                if ((-Not [String]::IsNullOrEmpty($PreviousKeyFileName)) -And ($PreviousCertFileName -ne $PreviousKeyFileName)) {
                                    Write-ToLogFile -I -C ADC-RemovePrevious -M "Removing file: `"/nsconfig/ssl/$PreviousKeyFileName`""
                                    $null = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type systemfile -Resource $PreviousKeyFileName -Arguments $Arguments
                                    Write-ToLogFile -I -C ADC-RemovePrevious -M "Success"
                                } else {
                                    Write-ToLogFile -I -C ADC-RemovePrevious -M "Same file, `"/nsconfig/ssl/$PreviousKeyFileName`" was already removed."
                                }
                            } catch {
                                Write-ToLogFile -E -C ADC-RemovePrevious -M "Could not remove previous files, $($_.Exception.Message)"
                            }
                        }
                    } else {
                        Write-ToLogFile -I -C ADC-CertUpload -M "Add the certificate and key to the ADC config."
                        $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type sslcertkey -Payload $payload
                        Write-ToLogFile -I -C ADC-CertUpload -M "Added successfully."
                    }
                } catch {
                    Write-Warning "Caught an error, certificate not added to the ADC Config"
                    Write-Warning "Details: $($_.Exception.Message | Out-String)"
                    Write-ToLogFile -E -C ADC-CertUpload -M "Caught an error, certificate not added to the ADC Config. Exception Message: $($_.Exception.Message)"
                }
                Write-Host -ForeGroundColor Yellow -NoNewLine "*"
                Write-ToLogFile -I -C ADC-CertUpload -M "Link `"$CertificateCertKeyName`" to `"$IntermediateCACertKeyName`""
                try {
                    $payload = @{"certkey" = "$CertificateCertKeyName"; "linkcertkeyname" = "$IntermediateCACertKeyName"; }
                    $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type sslcertkey -Payload $payload -Action link
                    Write-ToLogFile -I -C ADC-CertUpload -M "Link successfully."
                } catch {
                    Write-Warning -Message "Could not link the certificate `"$CertificateCertKeyName`" to Intermediate `"$IntermediateCACertKeyName`""
                    Write-ToLogFile -E -C ADC-CertUpload -M "Could not link the certificate `"$CertificateCertKeyName`" to Intermediate `"$IntermediateCACertKeyName`"."
                    Write-ToLogFile -E -C ADC-CertUpload -M "Exception Message: $($_.Exception.Message)"
                }
                Write-Host -ForeGroundColor Green " Ready"

                if ($PfxPasswordGenerated) {
                    ""
                    Write-Warning "No Password was specified, so a random password was generated!"
                    Write-ToLogFile -W -C ADC-CertUpload -M "No Password was specified, so a random password was generated! (Password not saved in Log)"
                    Write-Host -ForeGroundColor Magenta "`r`n********************************************************************"
                    Write-Host -ForeGroundColor White -NoNewline "`r`n -PFX Password..........: "
                    Write-Host -ForeGroundColor Yellow $(ConvertTo-PlainText -SecureString $PfxPassword)
                    Write-Host -ForeGroundColor Magenta "`r`n********************************************************************"
                }
                Write-Host -ForeGroundColor White -NoNewline " -Certificate Usage.....: " 
                if ($Production) {
                    Write-Host -ForeGroundColor Cyan "Production"
                } else {
                    Write-Host -ForeGroundColor Yellow "!! Test !!"
                }
                Write-Host -ForeGroundColor White -NoNewline " -Keysize...............: "
                Write-Host -ForeGroundColor Cyan "$($CertRequest.KeyLength)"
                Write-Host -ForeGroundColor White -NoNewline " -Certkey Name..........: " 
                Write-Host -ForeGroundColor Cyan $CertificateCertKeyName
                Write-Host -ForeGroundColor White -NoNewline " -Cert Dir..............: " 
                Write-Host -ForeGroundColor Cyan $CertificateDirectory
                Write-Host -ForeGroundColor White -NoNewline " -CRT Filename..........: "
                Write-Host -ForeGroundColor Cyan $CertificateFileName
                Write-Host -ForeGroundColor White -NoNewline " -KEY Filename..........: "
                Write-Host -ForeGroundColor Cyan $CertificateKeyFileName
                Write-Host -ForeGroundColor White -NoNewline " -PFX Filename..........: "
                Write-Host -ForeGroundColor Cyan $CertificatePfxFileName
                Write-Host -ForeGroundColor White -NoNewline " -PFX (with Chain)......: "
                Write-Host -ForeGroundColor Cyan $CertificatePfxWithChainFileName
                ""
                Write-Host -ForeGroundColor White -NoNewline " -Certificate State.....: "
                Write-Host -ForeGroundColor Green "Finished with the certificates!"
                Write-ToLogFile -I -C ADC-CertUpload -M "Keysize: $($CertRequest.KeyLength)"
                Write-ToLogFile -I -C ADC-CertUpload -M "Cert Dir: $CertificateDirectory"
                Write-ToLogFile -I -C ADC-CertUpload -M "CRT Filename: $CertificateFileName"
                Write-ToLogFile -I -C ADC-CertUpload -M "KEY Filename: $CertificateKeyFileName"
                Write-ToLogFile -I -C ADC-CertUpload -M "PFX Filename: $CertificatePfxFileName"
                Write-ToLogFile -I -C ADC-CertUpload -M "PFX (with Chain): $CertificatePfxWithChainFileName"
                Write-ToLogFile -I -C ADC-CertUpload -M "Finished with the certificates!"
    
                $MailData += "Certificates stored in: $CertificateDirectory"
                try {
                    $MailCertificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 "$(Join-Path -Path $CertificateDirectory -ChildPath $CertificateFileName)"
                    $MailData += "CRT Filename: $CertificateFileName"
                    $MailData += "PFX Filename: $CertificatePfxFileName"
                    $MailData += "Valid until: $($MailCertificate.NotAfter.ToUniversalTime())"
                    $MailData += "Approved by CA: $($MailCertificate.Issuer)"
                    $MailData += "CN: $($MailCertificate.Subject)"
                    $MailData += "SANs: $($MailCertificate.DnsNameList.Unicode -Join ", ")"
                    $MailData += "Public Key Size: $($MailCertificate.PublicKey.key.KeySize)"
                } catch { }

                ##Saving Config if required    
                Save-ADCConfig -SaveADCConfig:$($Parameters.settings.SaveADCConfig)

                #region IISActions
    
                if ($UpdateIIS) {
                    Write-Host -ForeGroundColor White "`r`nIIS"
                    try {
                        Import-Module WebAdministration -ErrorAction Stop
                        $WebAdministrationModule = $true
                    } catch {
                        $WebAdministrationModule = $false
                    }
                    if ($WebAdministrationModule) {
                        try {
                            Write-Host -ForeGroundColor White -NoNewline " -IIS Site..............: " 
                            Write-Host -ForeGroundColor Cyan $IISSiteToUpdate
                            $ImportedCertificate = Import-PfxCertificate -FilePath $CertificatePfxFullPath -CertStoreLocation Cert:\LocalMachine\My -Password $PfxPassword
                            Write-ToLogFile -D -C IISActions -M "ImportedCertificate $($ImportedCertificate | Select-Object Thumbprint,Subject | ConvertTo-Json -Compress)"
                            Write-Host -ForeGroundColor White -NoNewline " -Binding...............: " 
                            $CurrentWebBinding = Get-WebBinding -Name $IISSiteToUpdate -Protocol https
                            if ($CurrentWebBinding) {
                                Write-ToLogFile -I -C IISActions -M "Current binding exists."
                                Write-Host -ForeGroundColor Green "Current [$($CurrentWebBinding.bindingInformation)]"
                                $CurrentCertificateBinding = Get-Item IIS:\SslBindings\0.0.0.0!443 -ErrorAction SilentlyContinue
                                Write-ToLogFile -D -C IISActions -M "CurrentCertificateBinding $($CurrentCertificateBinding | Select-Object IPAddress,Port,Host,Store,@{ name="Sites"; expression={$_.Sites.Value} } | ConvertTo-Json -Compress)"
                                Write-Host -ForeGroundColor White -NoNewline " -Unbinding Current Cert: " 
                                Write-ToLogFile -I -C IISActions -M "Unbinding Current Certificate, $($CurrentCertificateBinding.Thumbprint)"
                                $CurrentCertificateBinding | Remove-Item -ErrorAction SilentlyContinue
                                Write-Host -ForeGroundColor Yellow "Removed [$($CurrentCertificateBinding.Thumbprint)]"
                            } else {
                                Write-ToLogFile -I -C IISActions -M "No current binding exists, trying to add one."
                                try {
                                    New-WebBinding -Name $IISSiteToUpdate -IPAddress "*" -Port 443 -Protocol https
                                    $CurrentWebBinding = Get-WebBinding -Name $IISSiteToUpdate -Protocol https
                                    Write-Host -ForeGroundColor Green "New, created [$($CurrentWebBinding.bindingInformation)]"
                                    Write-ToLogFile -D -C IISActions -M "CurrentCertificateBinding $($CurrentCertificateBinding | Select-Object IPAddress,Port,Host,Store,@{ name="Sites"; expression={$_.Sites.Value} } | ConvertTo-Json -Compress)"
                                } catch {
                                    Write-Host -ForeGroundColor Red "Failed"
                                    Write-ToLogFile -E -C IISActions -M "Failed. Exception Message: $($_.Exception.Message)"
                                }
                            }
                            try {
                                Write-ToLogFile -I -C IISActions -M "Binding new certificate, $($ImportedCertificate.Thumbprint)"
                                Write-Host -ForeGroundColor White -NoNewline " -Binding New Cert......: " 
                                New-Item -path IIS:\SSLBindings\0.0.0.0!443 -Value $ImportedCertificate -ErrorAction Stop | Out-Null
                                Write-Host -ForeGroundColor Green "Bound [$($ImportedCertificate.Thumbprint)]"
                                $MailData += "IIS Binding updated for site `"$IISSiteToUpdate`": $($ImportedCertificate.Thumbprint)"
                            } catch {
                                Write-Host -ForeGroundColor Red "Could not bind"
                                Write-ToLogFile -E -C IISActions -M "Could not bind. Exception Message: $($_.Exception.Message)"
                            }
                        } catch {
                            Write-Host -ForeGroundColor Red "Caught an error while updating"
                            Write-ToLogFile -E -C IISActions -M "Caught an error while updating. Exception Message: $($_.Exception.Message)"
                        }
                    } else {
                        Write-Host -ForeGroundColor White -NoNewline " -Module................: " 
                        Write-Host -ForeGroundColor Red "WebAdministration Module could not be found, please install feature!"
                    }
                }
    
                #endregion IISActions
    
                ""
                if ($CertRequest.ValidationMethod -eq "dns") {
                    Write-Host -ForegroundColor Magenta "`r`n********************************************************************"
                    Write-Host -ForegroundColor Magenta "* IMPORTANT: Don't forget to delete the created DNS records!!      *"
                    Write-Host -ForegroundColor Magenta "********************************************************************"
                    Write-ToLogFile -I -C ADC-CertUpload -M "Don't forget to delete the created DNS records!!"
                    foreach ($Record in $TXTRecords) {
                        ""
                        Write-Host -ForeGroundColor White -NoNewLine " -DNS Hostname..........: "
                        Write-Host -ForeGroundColor Cyan "$($Record.fqdn)"
                        Write-Host -ForeGroundColor White -NoNewLine " -TXT Record Name.......: "
                        Write-Host -ForeGroundColor Yellow "$($Record.TXTName)"
                        Write-ToLogFile -I -C ADC-CertUpload -M "TXT Record: `"$($Record.TXTName)`""
                    }
                    ""
                    Write-Host -ForegroundColor Magenta "********************************************************************"
                }
                if (-not $Production) {
                    Write-Host -ForeGroundColor Yellow "`r`nYou are now ready for the Production version!"
                    Write-Host -ForeGroundColor Yellow "Add the `"-Production`" parameter and rerun the same script.`r`n"
                    Write-ToLogFile -I -C ADC-CertUpload -M "You are now ready for the Production version! Add the `"-Production`" parameter and rerun the same script."
                }
            } catch {
                Write-ToLogFile -E -C ADC-CertUpload -M "Certificate completion failed. Exception Message: $($_.Exception.Message)"
                Write-Error "Certificate completion failed. Exception Message: $($_.Exception.Message)"
                TerminateScript 1 "Certificate completion failed. Exception Message: $($_.Exception.Message)"
            }
        }
    
        #endregion ADC-CertUpload
    } #END Loop
    
}

#region CleanupADC
    
if ($CleanADC) {
    Invoke-ADCCleanup -Full
}
    
    
#endregion CleanupADC

#region RemoveTestCerts

if ($RemoveTestCertificates) {
    Write-Host -ForeGroundColor White "`r`nADC - (Test) Certificate Cleanup"
    Write-ToLogFile -I -C RemoveTestCerts -M "Start removing the test certificates."
    Write-ToLogFile -I -C RemoveTestCerts -M "Trying to login into the Citrix ADC."
    $ADCSession = Connect-ADC -ManagementURL $Parameters.settings.ManagementURL -Credential $Credential -PassThru
    $IntermediateCACertKeyName = "Fake LE Intermediate X1"
    $IntermediateCASerial = "8be12a0e5944ed3c546431f097614fe5"
    Write-ToLogFile -I -C RemoveTestCerts -M "Retrieving existing certificates."
    $CertDetails = Invoke-ADCRestApi -Session $ADCSession -Method GET -Type sslcertkey
    Write-ToLogFile -D -C RemoveTestCerts -M "Checking if IntermediateCA `"$IntermediateCACertKeyName`" already exists."
    $IntermediateCADetails = $CertDetails.sslcertkey | Where-Object { $_.serial -eq $IntermediateCASerial }
    $LinkedCertificates = $CertDetails.sslcertkey | Where-Object { $_.linkcertkeyname -eq $IntermediateCADetails.certkey }
    Write-ToLogFile -D -C RemoveTestCerts -M "The following certificates were found:"
    $LinkedCertificates | Select-Object certkey, linkcertkeyname, serial | ForEach-Object {
        Write-ToLogFile -D -C RemoveTestCerts -M "$($_ | ConvertTo-Json -Compress)"
    }
    Write-Host -ForeGroundColor White -NoNewLine " -Linked Certkeys found.: "
    Write-Host -ForeGroundColor Cyan "$(($LinkedCertificates | Measure-Object).Count)"
    ForEach ($LinkedCertificate in $LinkedCertificates) {
        $payload = @{"certkey" = "$($LinkedCertificate.certkey)"; }
        try {
            $response = Invoke-ADCRestApi -Session $ADCSession -Method POST -Type sslcertkey -Payload $payload -Action unlink
            Write-Host -ForeGroundColor White -NoNewLine " -Unlinking Certkey.....: "
            Write-Host -ForeGroundColor Green "Done    [$($LinkedCertificate.certkey)]"
            Write-ToLogFile -I -C RemoveTestCerts -M "Unlinked: `"$($LinkedCertificate.certkey)`""
        } catch {
            Write-Host -ForeGroundColor Yellow "WARNING, Could not unlink `"$($LinkedCertificate.certkey)`""
            Write-ToLogFile -E -C RemoveTestCerts -M "Could not unlink certkey `"$($LinkedCertificate.certkey)`". Exception Message: $($_.Exception.Message)"
        }
    }
    $FakeCerts = $CertDetails.sslcertkey | Where-Object { $_.issuer -match $IntermediateCACertKeyName }
    Write-ToLogFile -D -C RemoveTestCerts -M "Test Cert data:"
    $FakeCerts | ForEach-Object {
        Write-ToLogFile -D -C RemoveTestCerts -M "$($_ | ConvertTo-Json -Compress)"
    }
    Write-Host -ForeGroundColor White -NoNewLine " -Certificates found....: "
    Write-Host -ForeGroundColor Cyan "$(($FakeCerts | Measure-Object).Count)"
    ForEach ($FakeCert in $FakeCerts) {
        try {
            Write-ToLogFile -I -C RemoveTestCerts -M "Trying to delete `"$($FakeCert.certkey)`"."
            Write-Host -ForeGroundColor White -NoNewLine " -SSL Certkey...........: "
            $response = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type sslcertkey -Resource $($FakeCert.certkey)
            Write-Host -ForeGroundColor Green "Deleted [$($FakeCert.certkey)]"
        } catch {
            Write-Host -ForeGroundColor Yellow "WARNING, could not remove certkey `"$($FakeCert.certkey)`""
            Write-ToLogFile -W -C RemoveTestCerts -M "Could not remove certkey `"$($FakeCert.certkey)`" from the ADC. Exception Message: $($_.Exception.Message)"
        }
        Write-ToLogFile -W -C RemoveTestCerts -M "Getting Certificate details"
        try {
            $CertFilePath = (split-path $($FakeCert.cert) -Parent).Replace("\", "/")
            if ([String]::IsNullOrEmpty($CertFilePath)) {
                $CertFilePath = "/nsconfig/ssl/"
            }
        } catch {
            $CertFilePath = "/nsconfig/ssl/"
        }
        try {
            $CertFileName = split-path $($FakeCert.cert) -Leaf
        } catch {
            $CertFileName = $null
        }
        Write-ToLogFile -W -C RemoveTestCerts -M "Certificate name: `"$($CertFileName)`" in path: `"$($CertFilePath)`""
        Write-ToLogFile -W -C RemoveTestCerts -M "Getting Certificate Key details"
        try {
            $KeyFilePath = (split-path $($FakeCert.key) -Parent).Replace("\", "/")
            if ([String]::IsNullOrEmpty($KeyFilePath)) {
                $KeyFilePath = "/nsconfig/ssl/"
            }
        } catch {
            $KeyFilePath = "/nsconfig/ssl/"
        }
        try {
            $KeyFileName = split-path $($FakeCert.key) -Leaf
        } catch {
            $KeyFileName = $null
        }
        Write-ToLogFile -W -C RemoveTestCerts -M "Certificate name: `"$($KeyFileName)`" in path: `"$($KeyFilePath)`""
        Write-Host -ForeGroundColor White -NoNewLine " -SSL Certificate File..: "
        $Arguments = @{"filelocation" = "$CertFilePath"; }
        try {
            Write-ToLogFile -I -C RemoveTestCerts -M "Trying to delete `"$(Join-Path -Path $CertFilePath -ChildPath $CertFileName)`"."
            $response = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type systemfile -Resource $CertFileName -Arguments $Arguments
            Write-Host -ForeGroundColor Green "Deleted [$(Join-Path -Path $CertFilePath -ChildPath $CertFileName)]"
            Write-ToLogFile -I -C RemoveTestCerts -M "File deleted."
        } catch {
            Write-Host -ForeGroundColor Yellow "WARNING, could not delete file `"$(Join-Path -Path $CertFilePath -ChildPath $CertFileName)`""
            Write-ToLogFile -E -C RemoveTestCerts -M "Could not delete file `"$(Join-Path -Path $CertFilePath -ChildPath $CertFileName)`". Exception Message: $($_.Exception.Message)"
        }
        if (-Not ($(Join-Path -Path $CertFilePath -ChildPath $CertFileName) -eq $(Join-Path -Path $KeyFilePath -ChildPath $KeyFileName))) {
            Write-Host -ForeGroundColor White -NoNewLine " -SSL Key File..........: "
            $Arguments = @{"filelocation" = "$KeyFilePath"; }
            try {
                Write-ToLogFile -I -C RemoveTestCerts -M "Trying to delete `"$(Join-Path -Path $KeyFilePath -ChildPath $KeyFileName)`"."
                $response = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type systemfile -Resource $KeyFileName -Arguments $Arguments
                Write-Host -ForeGroundColor Green "Deleted [$(Join-Path -Path $KeyFilePath -ChildPath $KeyFileName)]"
                Write-ToLogFile -I -C RemoveTestCerts -M "File deleted."
            } catch {
                Write-Host -ForeGroundColor Yellow "WARNING, could not delete file `"$(Join-Path -Path $KeyFilePath -ChildPath $KeyFileName)`""
                Write-ToLogFile -E -C RemoveTestCerts -M "Could not delete file `"$(Join-Path -Path $KeyFilePath -ChildPath $KeyFileName)`". Exception Message: $($_.Exception.Message)"
            }
        }
    }
    $Arguments = @{"filelocation" = "/nsconfig/ssl"; }
    $CertFiles = Invoke-ADCRestApi -Session $ADCSession -Method Get -Type systemfile -Arguments $Arguments
    $CertFilesToRemove = $CertFiles.systemfile | Where-Object { $_.filename -match "TST-" }
    Write-Host -ForeGroundColor White -NoNewLine " -Misc. Files Found.....: "
    Write-Host -ForeGroundColor Cyan "$(($CertFilesToRemove | Measure-Object).Count)"
    ForEach ($CertFileToRemove in $CertFilesToRemove) {
        Write-Host -ForeGroundColor White -NoNewLine " -File..................: "
        $Arguments = @{"filelocation" = "$($CertFileToRemove.filelocation)"; }
        try {
            Write-ToLogFile -I -C RemoveTestCerts -M "Trying to delete `"$(Join-Path -Path $CertFileToRemove.filelocation -ChildPath $CertFileToRemove.filename)`"."
            $response = Invoke-ADCRestApi -Session $ADCSession -Method DELETE -Type systemfile -Resource $($CertFileToRemove.filename) -Arguments $Arguments
            Write-Host -ForeGroundColor Green "Deleted [$(Join-Path -Path $CertFileToRemove.filelocation -ChildPath $CertFileToRemove.filename)]"
            Write-ToLogFile -I -C RemoveTestCerts -M "File deleted."
        } catch {
            Write-Host -ForeGroundColor Yellow "WARNING, could not delete file [$(Join-Path -Path $CertFileToRemove.filelocation -ChildPath $CertFileToRemove.filename)]"
            Write-ToLogFile -E -C RemoveTestCerts -M "Could not delete file: `"$(Join-Path -Path $CertFileToRemove.filelocation -ChildPath $CertFileToRemove.filename)`". Exception Message: $($_.Exception.Message)"
        }
    }
}

#endregion RemoveTestCerts

#region Final Actions

if ($SaveConfig -and (-Not [String]::IsNullOrEmpty($ConfigFile))) {
    try {
        Write-ToLogFile -I -C Final-Actions -M "Saving parameters to file `"$ConfigFile`""
        $Parameters | ConvertTo-Json | Out-File -FilePath $ConfigFile -Encoding unicode -Force -ErrorAction Stop | Out-Null
        Write-ToLogFile -I -C Final-Actions -M "Saving done"
    } catch {
        Write-ToLogFile -E -C Final-Actions -M "Saving failed! Exception Message: $($_.Exception.Message)"
        Write-Host -ForegroundColor Red "Could not write the Parameters to `"$ConfigFile`"`r`nException Message: $($_.Exception.Message)"
    }
} elseif ($SaveConfig-and ([String]::IsNullOrEmpty($ConfigFile))) {
    Write-ToLogFile -D -C Final-Actions -M "There were unsaved changes, but no ConfigFile was defined."
} else {
    Write-ToLogFile -D -C Final-Actions -M "No ConfigFile was defined, nothing will be saved."
}

TerminateScript 0

#endregion Final Actions