function Format-FileExtension
{
    <#
    .SYNOPSIS
        Converts strings representing a file extension to a format recognised by Get-ChildItem's Include parameter.
    .DESCRIPTION
        Uses regular expression to parse and convert strings representing a file extension to a format recognised by Get-ChildItem's Include parameter.
    .EXAMPLE
        Format-FileExtension -InputObject "ps1"

        *.ps1
    .EXAMPLE
        Format-FileExtension -InputObject "PS1", ".exe", "*.msi"
    .INPUTS
        String
    .OUTPUTS
        String
    #>

    [CmdletBinding(ConfirmImpact = "Low", SupportsShouldProcess = $False)]
    [Alias()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True, ValueFromPipeline = $True, ParameterSetName = "DefaultParameters", HelpMessage = "What to enter for this parameter")]
        [string[]] $InputObject
    )

    BEGIN
    {
        if ($PSBoundParameters.ContainsKey("Debug"))
        {
        }
        Write-Debug -Message "BEGIN Block"
    }

    PROCESS
    {
        Write-Debug -Message "PROCESS Block"
        forEach ($Extension in $InputObject)
        {
            # All comments use PS1 as the example extension for consistency
            # but the code is written to match any acceptable (i.e. numbers and letters) extension.
            Write-Debug -Message "Process '$Extension'"
            # Start by checking for a match against the desired format: '*.ps1'
            if ($Extension -match "^(\*\.)")
            {
                $Extension.ToLower()
            }
            # If it doesn't, then move on to the variations.
            else
            {
                switch -regex ($Extension)
                {
                    # Check for a match against: 'ps1'
                    "^(\w|\d)+$"
                    {
                        "*." + $Extension.ToLower()
                    }

                    # Check for a match against: '**.ps1'
                    "^(\*)+(\.)+(\w|\d)+$"
                    {
                        "*." + (($Extension.ToLower()) -replace "(\.|\*)+")
                    }

                    # Check for a match against: '.ps1' or '..ps1'
                    "^(\.)+(\w|\d)+$"
                    {
                        "*." + (($Extension.ToLower()) -replace "(\.)+")
                    }

                    # Check for a match against: '*ps1' or '**ps1'
                    "^(\*)+(\w|\d)+$"
                    {
                        "*." + (($Extension.ToLower()) -replace "(\*)+")
                    }

                    # Check for a match against: '.*ps1' or '..**ps1'
                    "^(\.)+(\*)+(\w|\d)+$"
                    {
                        "*." + (($Extension.ToLower()) -replace "(\.|\*)+")
                    }

                    default
                    {
                        Write-Warning -Message "Unable to format '$Extension' as a file extension."
                        $Extension
                    }
                }
            }
        }
    }

    END
    {
        Write-Debug -Message "END Block"
    }
}