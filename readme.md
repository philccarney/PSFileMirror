# PSFileMirror

[![Build status](https://ci.appveyor.com/api/projects/status/b269t02q767owgwc?svg=true)](https://ci.appveyor.com/project/Phil84148/psfilemirror)

A simple Powershell-only (6+) file copy/mirror solution.

## Usage

```Powershell
# Install it
Install-Module PSFileMirror

# Import it
Import-Module ".\PSFileMirror\PSFileMirror.psd1"

# Use it
Invoke-FileMirror -Path ".\Source" -Destination ".\Destination" -Log ".\Example.log"
```
