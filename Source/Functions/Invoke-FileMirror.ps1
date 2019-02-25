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
    PSCustomObject
.NOTES
    Version 0.1.0
#>
    [CmdletBinding(ConfirmImpact = 'Medium', SupportsShouldProcess = $True)]
    param
    (
        [Parameter(Mandatory = $True, Position = 0, HelpMessage = "The path to the file(s) to be copied")]
        [string] $Path,

        [Parameter(Mandatory = $True, Position = 1, HelpMessage = "The path to the root destination of the file(s)")]
        [string] $Destination,

        [Parameter(Mandatory = $False, Position = 2, HelpMessage = "The path to the file used to log the file operation(s)")]
        [string] $Log,

        <# [Parameter(Mandatory = $False, Position = 3, HelpMessage = "The extensions(s) which will be copied. The syntax for this is the same as Get-ChildItem's 'Include' parameter.")]
        [string[]] $Extension, #>

        [Parameter(Mandatory = $False, Position = 4, HelpMessage = "Indicates that hash-checking will be skipped for a 'Fast' completion")]
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

        Write-Verbose -Message "Scraping for files."
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
                        Write-Verbose -Message "Processing '$($File.FullName)'."
                        $ProposedPath = ($File.FullName).Replace($Path, $Destination)
                        Write-Verbose -Message "Proposed path: $ProposedPath"
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
                            if ($FileExistsInDestination)
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
                        finally
                        {
                            $FilesProcessed ++
                        }
                    }
                }
                else
                {
                    if ($FileExistsInDestination)
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
                                    $FileShouldBeCopied = $True
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
                        if ((-not ($FileExistsInDestination)) -or ($FileShouldBeCopied))
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
                        else
                        {
                            Write-Verbose -Message "Skipping file transfer."
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
        if ($PSCmdlet.ShouldProcess($Log, "Output object and write summary to log"))
        {
            try
            {
                Write-Verbose -Message "Calculating elapsed time."
                $ElapsedTime = New-TimeSpan -Start $StartTime -End (Get-Date)

                Write-Verbose -Message "Calculating failed transfers."
                if ($FilesToTransfer -gt 0)
                {
                    [int] $FailedTransfers = $FilesToTransfer - $FilesTransferred
                }
                else
                {
                    [int] $FailedTransfers = 0
                }

                Write-Verbose -Message "Building output object."
                [PSCustomObject]@{
                    FilesProcessed      = $FilesProcessed
                    FilesToTransfer     = $FilesToTransfer
                    SuccessfulTransfers = $FilesTransferred
                    FailedTransfers     = $FailedTransfers
                    ElapsedTime         = $ElapsedTime
                }

                Write-Verbose -Message "Writing summary to log."
                Add-LogEntry -Message "Elapsed time: $ElapsedTime" -Log $Log
                Add-LogEntry -Message "Files processed: $FilesProcessed" -Log $Log
                Add-LogEntry -Message "Files to transfer: $FilesToTransfer" -Log $Log
                Add-LogEntry -Message "Successful file transfers: $FilesTransferred" -Log $Log
                Add-LogEntry -Message "Failed file transfers: $FailedTransfers" -Log $Log
            }
            catch
            {
                $PSCmdlet.ThrowTerminatingError($_)
                Break
            }
        }
    }
}