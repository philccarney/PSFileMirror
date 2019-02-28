$ModuleName = (Split-Path -Path $PSScriptRoot) -split "\\" | Select-Object -Last 1
$ModuleManifestPath = Join-Path -Path (Split-Path -Path $PSScriptRoot) -ChildPath "$ModuleName.psd1"

Describe "Module Manifest Tests" -Tag "Build" {

    BeforeAll {

        $ModuleManifest = Test-ModuleManifest -Path $ModuleManifestPath
    }

    It "Passes 'Test-ModuleManifest'" {

        $ModuleManifest | Should -Not -BeNullOrEmpty
        $? | Should -Be $True
    }

    It "Has a module description" {

        $ModuleManifest.Description | Should -Not -BeNullOrEmpty
    }

    It "Has a valid version" {

        $ModuleManifest.Version.ToString() | Should -Not -BeNullOrEmpty
        $ModuleManifest.Version.ToString() | Should -match "\d+[.]\d+[.]\d+"
    }

    It "Has exported functions" {

        $ModuleManifest.ExportedFunctions | Should -Not -BeNullOrEmpty
    }
}
