function Test-FileHashesMatch
{
    <#
.SYNOPSIS
    Retrieves SHA256 hashes for two files and provides True/False values after comparing them.
.DESCRIPTION
    Uses the Get-FileHash cmdlet to retrieve hashes for two files and provides True/False values after comparing them.
.PARAMETER ReferencePath
    The path to the first file in the comparison.
.PARAMETER DifferencePath
    The path to the second file in the comparison.
.EXAMPLE
    Test-FileHashesMatch -ReferencePath ".\File1.txt" -DifferencePath ".\File1.txt"

    Returns True as the files are identical.
.INPUTS
    Strings
.OUTPUTS
    Boolean
#>
    [CmdletBinding(ConfirmImpact = 'Medium', SupportsShouldProcess = $True)]
    param
    (
        [Parameter(Mandatory = $True, HelpMessage = "The path to the first file in the comparison")]
        [string] $ReferencePath,

        [Parameter(Mandatory = $True, HelpMessage = "The path to the second file in the comparison")]
        [string] $DifferencePath
    )

    $HashSplat = @{
        Algorithm   = "SHA256"
        ErrorAction = "Stop"
    }

    try
    {
        Write-Verbose -Message "Retrieving hash for reference file ($ReferencePath)"
        $ReferenceHash = Get-FileHash -Path $ReferencePath @HashSplat
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    try
    {
        Write-Verbose -Message "Retrieving hash for difference file ($DifferencePath)"
        $DifferenceHash = Get-FileHash -Path $DifferencePath @HashSplat
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    Write-Verbose -Message "Comparing hashes."
    if ($DifferenceHash.Hash -eq $ReferenceHash.Hash)
    {
        $True
    }
    else
    {
        $False
    }
}