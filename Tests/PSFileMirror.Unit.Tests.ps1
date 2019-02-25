$ModuleName = $(Split-Path -Path $PSScriptRoot) -split "\\" | Select-Object -Last 1
$ModuleManifestPath = Join-Path -Path $(Split-Path -Path $PSScriptRoot) -ChildPath "$ModuleName.psd1"

if (Get-Module -Name $ModuleName)
{
    Remove-Module -Name $ModuleName
}

Import-Module -Name $ModuleManifestPath

InModuleScope -ModuleName "PSFileMirror" {

    Describe "Unit tests for 'Get-ProposedPath'" -Tag "Build" {

        Context "Input" {

            It "Should not throw with named parameters" {

                { Get-ProposedPath -Path "TestDrive:\Source\item.txt" -Source "TestDrive:\Source" -Destination "TestDrive:\Destination" } | Should -Not -Throw
            }

            It "Should not throw with positional parameters" {

                { Get-ProposedPath "TestDrive:\Source\item.txt" "TestDrive:\Source" "TestDrive:\Destination" } | Should -Not -Throw
            }

            It "Should throw with incorrect parameters" {

                { Get-ProposedPath -File "TestDrive:\Source\item.txt" -Source "TestDrive:\Source" -Target "TestDrive:\Destination" } | Should -Throw
            }
        }

        Context "Execution" {

            BeforeAll {

                $Execution1 = Get-ProposedPath -Path "TestDrive:\Source\item.txt" -Source "TestDrive:\Source" -Destination "TestDrive:\Destination"
                $Execution2 = Get-ProposedPath -Path "\\Path\To\Source\To\File" -Source "\\Path\To\Source" -Destination "\\Path\To\Destination"
            }

            It "Should replace the source root with the destination root" {

                $Execution1 | Should -Be "TestDrive:\Destination\item.txt"
                $Execution2 | Should -Be "\\Path\To\Destination\To\File"
            }

        }

        Context "Output" {

            BeforeAll {

                $Output = Get-ProposedPath -Path "TestDrive:\Source\item.txt" -Source "TestDrive:\Source" -Destination "TestDrive:\Destination"
            }

            It "Should output a string" {

                $Output.GetType().Name | Should -Be "String"
            }

            It "Should output one object" {

                $Output.Count | Should -Be 1
            }
        }
    }
}