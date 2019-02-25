# PSFileMirror

A simple Powershell Core-only file/directory solution.

## Usage

```Powershell

Import-Module ".\PSFileMirror\PSFileMirror.psd1"

Invoke-FileMirror -Path ".\Source" -Destination ".\Destination" -Log ".\Example.log"
```