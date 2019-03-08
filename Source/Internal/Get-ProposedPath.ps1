function Get-ProposedPath
{
    <#
.SYNOPSIS
    Proposes a file-path based on provided factors.
.DESCRIPTION
    Proposes a file-path from a provided file-path, and two root folder-paths.
.EXAMPLE
    Get-ProposedPath -Path "TestDrive:\Source\item.txt" -Source "TestDrive:\Source" -Destination "TestDrive:\Destination"

    Should provide "TestDrive:\Destination\item.txt"
.EXAMPLE
    Get-ProposedPath -Path "\\Path\To\Source\To\File" -Source "\\Path\To\Source" -Destination "\\Path\To\Destination"

    Should provide "\\Path\To\Destination\To\File"
.INPUTS
    Strings
.OUTPUTS
    String
#>
    [CmdletBinding(ConfirmImpact = 'Low')]
    [OutputType([String])]
    param
    (
        [Parameter(Mandatory = $True, Position = 0, HelpMessage = "The file to be processed")]
        [string] $Path,

        [Parameter(Mandatory = $True, Position = 1, HelpMessage = "The folder that is being processed")]
        [string] $Source,

        [Parameter(Mandatory = $True, Position = 2, HelpMessage = "The folder it is being copied to")]
        [string] $Destination
    )

    try
    {
        Write-Verbose -Message "Getting proposed path for $Path ($Source\$Destination)"
        $Path.Replace($Source, $Destination)
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}