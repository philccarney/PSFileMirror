function Invoke-FileMirror
{
    <#
.SYNOPSIS
    TBC - Short description
.DESCRIPTION
    TBC - Long description
.PARAMETER Path
    TBC
.PARAMETER Destination
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
        [string] $Path,

        [Parameter(Mandatory = $True, Position = 1)]
        [string] $Destination,

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
        $StartTime = Get-Date
        Add-LogEntry -Message "PSFileMirror started." -Log $Log

        Write-Verbose -Message "Setting file collection parameters."
        $DirSplat = @{
            Path    = $Path
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
            Add-LogEntry "Files ($($Files.Count)) scraped from source ($Path)" -Log $Log
        }
        #endregion Parameter-handling and Variables
    }

    PROCESS
    {
        Write-Debug -Message "PROCESS Block"
        if ($Files)
        {
            # Some basic counters to help keep track of what has been done.
            [int] $FilesProcessed = 0
            [int] $FilesToTransfer = 0
            [int] $FilesTransferred = 0

            forEach ($File in $Files)
            {
                if ($PSCmdlet.ShouldProcess($File.FullName, "Processing destination path"))
                {
                    try
                    {
                        Write-Verbose -Message "Processing '$File'."
                        $ProposedPath = ($File.FullName).Replace($Path, $Target)
                        $ProposedParentDirectory = Split-Path -Path $ProposedPath -Parent
                        if (Test-Path -LiteralPath $ProposedPath)
                        {
                            $FileExistsInDestination = $True
                        }
                    }
                    catch
                    {
                        $PSCmdlet.ThrowTerminatingError($_)
                        Break
                    }
                }

                if ($PSCmdlet.ShouldProcess($File.FullName, "Validating destination folder"))
                {
                    try
                    {
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
                    }
                    catch
                    {
                        $PSCmdlet.ThrowTerminatingError($_)
                        Break
                    }
                }


                if ($Fast)
                {
                    # Logic branch for the Fast run-through
                    if ($PSCmdlet.ShouldProcess($File.FullName, "Confirm if file exists in destination"))
                    {
                        try
                        {
                            if ($Null -ne $FileExistsInDestination)
                            {
                                # If Fast is specified, we don't care about checking hashes etc; only the existence of the file matters.
                                Write-Verbose "File already exists in destination. No further action required."
                                Continue
                            }
                        }
                        catch
                        {
                            $PSCmdlet.ThrowTerminatingError($_)
                            Break
                        }
                    }
                }
                else
                {
                    if ($Null -ne $FileExistsInDestination)
                    {
                        if ($PSCmdlet.ShouldProcess($File.FullName, "Process file hashes for source and existing destination file"))
                        {
                            try
                            {
                                # If Fast isn't specified, we need to consider hashes, so we'll gather them before we do anything else.
                                $HashSplat = @{
                                    Algorithm   = "SHA256"
                                    ErrorAction = "Stop"
                                }

                                $OriginalFileHash = Get-FileHash @HashSplat -Path $File |
                                    Select-Object -ExpandProperty "Hash"

                                $DestinationFileHash = Get-FileHash @HashSplat -Path $ProposedPath |
                                    Select-Object -ExpandProperty "Hash"

                                if ($DestinationFileHash -ne $OriginalFileHash)
                                {
                                    Write-Verbose -Message "Hash mismatch: $OriginalFileHash/$DestinationFileHash"
                                    FileShouldBeCopied = $True
                                }
                                else
                                {
                                    Write-Verbose -Message "Hashes match."
                                }
                            }
                            catch
                            {
                                $PSCmdlet.ThrowTerminatingError($_)
                                Break
                            }
                        }
                    }
                }

                if ($PSCmdlet.ShouldProcess($File, "Processing file for transfer"))
                {
                    try
                    {
                        if (($Null -ne $FileExistsInDestination) -or (FileShouldBeCopied))
                        {
                            $FilesToTransfer ++
                            Write-Verbose -Message "Copying '$File' to '$ProposedPath'."
                            $CopySplat = @{
                                LiteralPath = $File
                                Destination = $ProposedPath
                                Force       = $True
                                ErrorAction = "Stop"
                            }

                            Copy-Item @CopySplat

                            if ((-not ($Fast)) -and
                                ((Get-FileHash -Path $File -Algorithm "SHA256").Hash -eq (Get-FileHash -Path $ProposedPath -Algorithm "SHA256").Hash))
                            {
                                Write-Verbose -Message "Copy completed successfully. Hashes match."
                                $FilesTransferred ++
                            }
                            else
                            {
                                if (-not ($Fast)) # This *should* capture conditions which are NotFast but failed the comparison - without rerunning it.
                                {
                                    $Message = "Hash comparison failed for '$File'/'$ProposedPath'"
                                    Write-Warning -Message $Message
                                    Add-LogEntry -Message $Message -Log $Log
                                }
                                else
                                {
                                    $FilesTransferred ++
                                }
                            }
                        }
                    }
                    catch
                    {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                    finally
                    {
                        $FilesProcessed ++
                        Add-LogEntry -Message "Processed: $File" -Log $Log
                    }
                }
            }
        }
    }

    END
    {
        Write-Debug -Message "END Block"
        $ElapsedTime = New-TimeSpan -Start $StartTime -End (Get-Date)
        Add-LogEntry -Message "Elapsed time: $ElapsedTime" -Log $Log
        Add-LogEntry -Message "Files processed: $FilesProcessed" -Log $Log
        Add-LogEntry -Message "Files to transfer: $FilesToTransfer" -Log $Log
        Add-LogEntry -Message "Files transferred successfully: $FilesTransferred" -Log $Log
    }
}