function Invoke-FileMirror
{
    <#
    .SYNOPSIS
        Provides a simple file/directory mirroring solution in Powershell Core.
    .DESCRIPTION
        Uses Powershell Core cmdlets to provide a simple file/directory mirroring solution including SHA256 hash-checking.
    .PARAMETER Path
        The path to the file(s) or folder(s) to be copied.
    .PARAMETER Destination
        The path to the destination of the copy operation. The file structure is kept intact.
    .PARAMETER Log
        The path to the log file - this logs the file operation(s).
    .PARAMETER Extension
        Used to specify what files will be copied.
    .PARAMETER Fast
        Used to achieve a 'Fast' completion by skipping hash-checking of existing files, or after completed transfers.
    .EXAMPLE
        Invoke-FileMirror -Path ".\Source" -Destination ".\Destination" -Log ".\Example.log"

        Copies the contents of the 'Source' folder to the 'Destination' folder and logs the operation to the 'Example.log' file. This includes a hash-checking.
    .EXAMPLE
        Invoke-FileMirror -Path ".\Source" -Destination ".\FastDestination" -Log ".\FastExample.log" -Fast

        Copies the contents of the 'Source' folder to the 'FastDestination' folder and logs the operation to the 'FastExample.log' file. This does not include hash-checking.
    .INPUTS
        Strings
    .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(ConfirmImpact = 'Medium', SupportsShouldProcess = $True)]
    [Alias()]
    [OutputType([PSCustomObject])]
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
                        $ProposedPath = Get-ProposedPath -Path $File.FullName -Source $Path -Destination $Destination
                        Write-Verbose -Message "Proposed path: $ProposedPath"
                        if (Test-Path -LiteralPath $ProposedPath)
                        {
                            Write-Verbose -Message "Proposed path already exists."
                            $FileExistsInDestination = $True
                        }
                        else
                        {
                            Write-Verbose -Message "Proposed path does not exist yet."
                            $FileExistsInDestination = $False # Added otherwise it remains set after the first True instance.
                        }
                    }
                    catch
                    {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                }

                if ($PSCmdlet.ShouldProcess($File.FullName, "Ensuring destination folder"))
                {
                    $ProposedParentDirectory = Split-Path -Path $ProposedPath -Parent
                    Write-Verbose -Message "Proposed parent directory: $ProposedParentDirectory"
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

                            [void] (New-Item @ParentDirSplat)
                        }
                    }
                    catch
                    {
                        $PSCmdlet.ThrowTerminatingError($_)
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
                                if (-not (Test-FileHashesMatch -ReferencePath $File.FullName -DifferencePath $ProposedPath))
                                {
                                    Write-Verbose -Message "Hash mismatch. File should be copied."
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

                            if ((-not ($Fast)) -and (Test-FileHashesMatch -ReferencePath $File.FullName -DifferencePath $ProposedPath))
                            {
                                Write-Verbose -Message "Copy completed successfully. Hashes match."
                                $FilesTransferred ++
                            }
                            else
                            {
                                if (-not ($Fast)) # This *should* capture conditions which are NotFast but failed the comparison - without rerunning it.
                                {
                                    $Message = "Hash comparison failed for '$($File.FullName)'/'$ProposedPath'"
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
            }
        }
    }
}