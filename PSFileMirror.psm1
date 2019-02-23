$Functions = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath "Source") -Recurse -File
forEach ($Function in $Functions)
{
    . $Function.FullName
}