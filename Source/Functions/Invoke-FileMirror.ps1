function Invoke-FileMirror
{
    <#
.SYNOPSIS
    TBC - Short description
.DESCRIPTION
    TBC - Long description
.PARAMETER Source
    TBC
.PARAMETER Target
    TBC
.PARAMETER Log
    TBC
.PARAMETER Extension
    TBC
.PARAMETER Fast
    TBC
.EXAMPLE
    TBC - Example of how to use this cmdlet
.INPUTS
    Strings
.OUTPUTS
    TBC - Output from this cmdlet (if any)
.NOTES
    Version 0.1.0
#>
    [CmdletBinding(ConfirmImpact = 'Medium', SupportsShouldProcess = $True)]
    param
    (
        [Parameter(Mandatory = $True, Position = 0)]
        [string] $Source,

        [Parameter(Mandatory = $True, Position = 1)]
        [Alias("Destination")]
        [string] $Target,

        [Parameter(Mandatory = $False, Position = 2)]
        [string] $Log,

        [Parameter(Mandatory = $False, Position = 3, HelpMessage = "The extensions(s) which will be copied. The syntax for this is the same as Get-ChildItem's 'Include' parameter.")]
        [string[]] $Extension,

        [Parameter(Mandatory = $False, Position = 4)]
        [switch] $Fast
    )

    BEGIN
    {
        if ($PSBoundParameters.ContainsKey("Debug"))
        {
            $DebugPreference = "Continue"
        }
        Write-Debug -Message "BEGIN Block"

        #region Parameter-handling and Variables
        $DateFormat = "%y/%m%/%d-%H:%M:%S"
        $StartTime = Get-Date
        Add-LogEntry -Message "PSFileMirror started." -Log $Log

        Write-Verbose -Message "Setting file collection parameters."
        $DirSplat = @{
            Path    = $Source
            File    = $True
            Recurse = $True
        }

        if ($Extension)
        {
            $Files = Get-ChildItem @DirSplat -Include $Extension
        }
        else
        {
            $Files = Get-ChildItem @DirSplat
        }

        if ($Files)
        {
            Add-LogEntry "Files ($($Files.Count)) scraped from source ($Source)" -Log $Log
        }

        #endregion Parameter-handling and Variables
    }

    PROCESS
    {
        Write-Debug -Message "PROCESS Block"
        if ($Files)
        {
            [int] $FilesProcessed = 0
            [int] $FilesToTransfer = 0
            [int] $FilesTransferred = 0
            forEach ($File in $Files)
            {
                if ($PSCmdlet.ShouldProcess($File, "Processing file for transfer"))
                {
                    try
                    {
                        Write-Verbose -Message "Processing '$File'."
                        $ProposedPath = ($File.FullName).Replace($Source, $Target)
                        $ProposedParentDirectory = Split-Path -Path $ProposedPath -Parent
                        if (($Fast) -and (Test-Path -LiteralPath $ProposedPath))
                        {
                            # If Fast is specified, we don't care about checking hashes etc; only the existence of the file matters.
                            Write-Verbose "File already exists in destination. No further action required."
                        }
                        else
                        {
                            if ((-not ($Fast)) -and (Test-Path -LiteralPath $ProposedPath))
                            {
                                # If Fast isn't specified, we need to consider hashes, so we'll gather them before we do anything else.
                                # I've used SHA256 for now, but I've used MD5 previously. I need to clarify which is preferable for this.
                                $OriginalFileHash = Get-FileHash -Path $File -Algorithm "SHA256" |
                                    Select-Object -ExpandProperty "Hash"

                                $DestinationFileHash = Get-FileHash -Path $ProposedPath -Algorithm "SHA256" |
                                    Select-Object -ExpandProperty "Hash"

                                if ($DestinationFileHash -ne $OriginalFileHash)
                                {
                                    Write-Verbose -Message "Hash mismatch: $OriginalFileHash/$DestinationFileHash"
                                    $HashMismatch = $True
                                }
                            }

                            if (-not (Test-Path -LiteralPath $ProposedParentDirectory))
                            {
                                Write-Verbose -Message "Destination folder does not exist. Creating. ($ProposedParentDirectory)"
                                $ParentDirSplat = @{
                                    Path        = $ProposedParentDirectory
                                    ItemType    = "Directory"
                                    ErrorAction = "Stop"
                                }

                                New-Item @ParentDirSplat | Out-Null
                            }

                            if ((-not (Test-Path -LiteralPath $ProposedPath)) -or ($HashMismatch))
                            {
                                Write-Verbose -Message "Copying '$File' to '$ProposedPath'."
                                $CopySplat = @{
                                    LiteralPath = $File
                                    Destination = $ProposedPath
                                    Force       = $True
                                }

                                Copy-Item @CopySplat

                                if ((-not ($Fast)) -and
                                    ((Get-FileHash -Path $File -Algorithm "SHA256").Hash -eq (Get-FileHash -Path $ProposedPath -Algorithm "SHA256").Hash))
                                {
                                    Write-Verbose -Message "Copy completed successfully. Hashes match."
                                }
                                else
                                {
                                    if (-not ($Fast)) # This *should* capture conditions which are NotFast but failed the comparison - without rerunning it.
                                    {
                                        $Message = "Hash comparison failed for '$File'/'$ProposedPath'"
                                        Write-Warning -Message $Message
                                        Add-LogEntry -Message $Message -Log $Log
                                    }
                                }
                            }
                        }

                        $FilesProcessed ++
                    }
                    catch
                    {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                    finally
                    {
                        Add-LogEntry -Message "Processed: $File" -Log $Log
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