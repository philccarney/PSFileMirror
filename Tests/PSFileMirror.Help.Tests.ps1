$ModuleName = $(Split-Path -Path $PSScriptRoot) -split "\\" | Select-Object -Last 1
$ModuleManifestPath = Join-Path -Path $(Split-Path -Path $PSScriptRoot) -ChildPath "$ModuleName.psd1"

if (Get-Module -Name $ModuleName)
{
    Remove-Module -Name $ModuleName
}

Import-Module -Name $ModuleManifestPath

Describe "Help tests for '$ModuleName'" -Tag "Build" {

    BeforeAll {

        $Functions = Get-Command -Module $ModuleName
        $Help = $Functions | ForEach-Object { Get-Help $_.Name -Full }
    }

    forEach ($FunctionHelp in $Help)
    {
        Context "$($FunctionHelp.Name)" {

            Context  "Help - Structure" {

                It "Has a Synopsis section." {
                    $FunctionHelp.Synopsis | Should -Not -BeNullOrEmpty
                }

                It "Has a Description section." {
                    $FunctionHelp.Description | Should -Not -BeNullOrEmpty
                }

                It "Has an Example section." {
                    $FunctionHelp.Examples | Should -Not -BeNullOrEmpty
                }

                It "Has an Inputs section section." {
                    $FunctionHelp.inputTypes | Should -Not -BeNullOrEmpty
                }

                It "Has an Outputs section section." {
                    $FunctionHelp.returnValues | Should -Not -BeNullOrEmpty
                }
            }

            Context "Help - Contents" {

                It "Has a Synopsis not starting with 'TBC'" {
                    $FunctionHelp.Synopsis | Should -Not -Match "TBC -"
                }

                It "Has a Description not starting with 'TBC'" {
                    $FunctionHelp.Description | Should -Not -Match "TBC -"
                }

                It "Has an Example not starting with 'TBC'" {
                    $FunctionHelp.Examples | Should -Not -Match "TBC -"
                }

                It "Has an Inputs section not starting with 'TBC'" {
                    $FunctionHelp.inputTypes | Should -Not -Match "TBC -"
                }

                It "Has an Outputs section not starting with 'TBC'" {
                    $FunctionHelp.returnValues | Should -Not -Match "TBC -"
                }
            }
        }
    }
}