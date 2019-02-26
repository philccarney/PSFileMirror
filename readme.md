# PSFileMirror

A simple Powershell Core-only file/directory solution.

## Usage

```Powershell

Import-Module ".\PSFileMirror\PSFileMirror.psd1"

Invoke-FileMirror -Path ".\Source" -Destination ".\Destination" -Log ".\Example.log"
```

## Status

[![Build status](https://ci.appveyor.com/api/projects/status/b269t02q767owgwc?svg=true)](https://ci.appveyor.com/project/Phil84148/psfilemirror)