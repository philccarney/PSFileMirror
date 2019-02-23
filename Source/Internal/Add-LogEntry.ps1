function Add-LogEntry
{
<#
.SYNOPSIS
    Adds a string prefixed with a timestamp to a text/log file.
.DESCRIPTION
    Adds a string prefixed with a timestamp to a specified text/log file.
.PARAMETER Message
    The string which will be added to the text/log file.
.PARAMETER Log
    The text/log file which the specified message will be added to.
.EXAMPLE
    Add-LogEntry -Message "Log started" -Log ".\Path\To\Example.log"
.INPUTS
    String and System.IO.FileInfo
.OUTPUTS
    N/A
.NOTES
    This functionality can be replicated easily with Add-Content or Out-File, but this delivery provides for a more consistent end-result when used across a module or collection of scripts or functions.
#>
    [CmdletBinding(ConfirmImpact = "Low",  SupportsShouldProcess = $True)]
    param
    (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [string] $Message,

        [Parameter(Mandatory = $True, Position = 1)]
        [string] $Log
    )

    BEGIN
    {
        if ($PSBoundParameters.ContainsKey("Debug"))
        {
            $DebugPreference = "Continue"
        }
        Write-Debug -Message "BEGIN Block"

        #region Parameter-handling and Variables

            # Parameters
            [string] $Message = $PSBoundParameters.Message
            [string] $Log = $PSBoundParameters.Log

        #endregion Parameter-handling and Variables
    }

    PROCESS
    {
        Write-Debug -Message "PROCESS Block"
        if ($PSCmdlet.ShouldProcess("Performing the operation: 'Add-LogEntry' on target '$Log' with entry '$Message'",
                         "Perform the operation: 'Add-LogEntry' on target '$Log' with entry '$Message'?",
                         "Are you sure you want to perform this action?"))
        {
            try
            {
                $Parameters = @{
                    Value = "$(Get-Date -UFormat "%y/%m/%d %H:%I:%S") - $Message"
                    Path = $Log
                    ErrorAction = "Stop"
                }

                Add-Content @Parameters
            }
            catch
            {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
    }

    END
    {
        Write-Debug -Message "END Block"
    }
}