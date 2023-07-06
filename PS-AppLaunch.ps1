param ($PublishedAppIni)
<#
.SYNOPSIS
Starts a published application with specific parameters and options
.DESCRIPTION
A feature rich framework for launching published applications. Features include:
  - Customizable SplashScreen
  - Import a registry file at launch,
  - Wait for a configurable logonscript process to finish before launching main application
  - Run another EXE prior to launching the main application
  - Option to wait for that other EXE to finish before launching the main application
.PARAMETER PublishedAppIni
Full path to the INI file used to define all options
.INPUTS
Ini file
.OUTPUTS
None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  16/12/2021
  Purpose/Change: Published Application Framework
 .EXAMPLE
  None
#>

#Function to read config.ini
Function Get-IniContent
{
    <#
    .Synopsis
        Gets the content of an INI file
    .Description
        Gets the content of an INI file and returns it as a hashtable
    .Notes
        Author        : Oliver Lipkau <oliver@lipkau.net>
        Blog        : http://oliver.lipkau.net/blog/
        Source        : https://github.com/lipkau/PsIni
                      http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91
        Version        : 1.0 - 2010/03/12 - Initial release
                      1.1 - 2014/12/11 - Typo (Thx SLDR)
                                         Typo (Thx Dave Stiff)
        #Requires -Version 2.0
    .Inputs
        System.String
    .Outputs
        System.Collections.Hashtable
    .Parameter FilePath
        Specifies the path to the input file.
    .Example
        $FileContent = Get-IniContent "C:\myinifile.ini"
        -----------
        Description
        Saves the content of the c:\myinifile.ini in a hashtable called $FileContent
    .Example
        $inifilepath | $FileContent = Get-IniContent
        -----------
        Description
        Gets the content of the ini file passed through the pipe into a hashtable called $FileContent
    .Example
        C:\PS>$FileContent = Get-IniContent "c:\settings.ini"
        C:\PS>$FileContent["Section"]["Key"]
        -----------
        Description
        Returns the key "Key" of the section "Section" from the C:\settings.ini file
    .Link
        Out-IniFile
    #>

    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [ValidateScript({(Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini")})]
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]
        [string]$FilePath
    )

    Begin
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}

    Process
    {
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath"

        $ini = @{}
        switch -regex -file $FilePath
        {
            "^\[(.+)\]$" # Section
            {
                $section = $matches[1]
                $ini[$section] = @{}
                $CommentCount = 0
            }
            "^(;.*)$" # Comment
            {
                if (!($section))
                {
                    $section = "No-Section"
                    $ini[$section] = @{}
                }
                $value = $matches[1]
                $CommentCount = $CommentCount + 1
                $name = "Comment" + $CommentCount
                $ini[$section][$name] = $value
            }
            "(.+?)\s*=\s*(.*)" # Key
            {
                if (!($section))
                {
                    $section = "No-Section"
                    $ini[$section] = @{}
                }
                $name,$value = $matches[1..2]
                $ini[$section][$name] = $value
            }
        }
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $FilePath"
        Return $ini
    }

    End
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}
}

# Get ready for the GUI stuff
Add-Type -AssemblyName PresentationFramework

# Check if INI file was provided
if ($PublishedAppIni -eq $null)
{
  $msgBoxInput = [System.Windows.MessageBox]::Show("No INI-File specified.","Error","OK","Error")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 1
    }
  }
}

#Read inifile
$IniFileExists = Test-Path $PublishedAppIni
If ($IniFileExists -eq $true)
{
  $IniFile = Get-IniContent $PublishedAppIni

  $WaitForLogonScript = $IniFile["CONFIG"]["WaitForLogonScript"]
  if ($WaitForLogonScript -eq $null)
  {
    $WaitForLogonScript = 0
  }

  if ($WaitForLogonScript -eq 1)
  {
    $LogonProcessToCheck = $IniFile["CONFIG"]["WaitForLogonProcess"]
    if (($LogonProcessToCheck -eq $null) -or ($LogonProcessToCheck -eq ""))
    {
      # LogonProcessToCheck not found or empty in INI file -> disable WaitForLogonScript
      $WaitForLogonScript = 0
    }
  }

  $TitleLabel = $IniFile["CONFIG"]["TitleLabel"]
  if (($TitleLabel -eq $null) -or ($TitleLabel -eq ""))
  {
    $TitleLabel = "App Launcher"
  }

  $TitleForeground = $IniFile["CONFIG"]["TitleForeground"]
  if (($TitleForeground -eq $null) -or ($TitleForeground -eq ""))
  {
    $TitleForeground = "White"
  }

  $LoadingLabel = $IniFile["CONFIG"]["LoadingLabel"]
  if (($LoadingLabel -eq $null) -or ($LoadingLabel -eq ""))
  {
    $LoadingLabel = "Getting Ready"
  }

  $LoadingForeground = $IniFile["CONFIG"]["LoadingForeground"]
  if (($LoadingForeground -eq $null) -or ($LoadingForeground -eq ""))
  {
    $LoadingForeground = "White"
  }

  $BackgroundColor = $IniFile["CONFIG"]["BackgroundColor"]
  if (($BackgroundColor -eq $null) -or ($BackgroundColor -eq ""))
  {
    $BackgroundColor = "Red"
  }

  $AppEXEPath = $IniFile["LAUNCH"]["AppEXEPath"]
  if ($AppEXEPath -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Application EXE Path not found in INI-File.","Error","OK","Error")
    switch  ($msgBoxInput)
    {
      "OK"
      {
        Exit 1
      }
    }
  }
  Else
  {
    $ExeFileExists = Test-Path $AppEXEPath
    if ($ExeFileExists -eq $false)
    {
      $msgBoxInput = [System.Windows.MessageBox]::Show("Application EXE not found.","Error","OK","Error")
      switch  ($msgBoxInput)
      {
        "OK"
        {
          Exit 1
        }
      }
    }
  }

  $AppCommandLineArgs = $IniFile["LAUNCH"]["AppCommandLineArgs"]
  if (($AppCommandLineArgs -eq $null) -or ($AppCommandLineArgs -eq ""))
  {
    $AppCommandLineArgs = 0
  }

  $AppImportRegFile = $IniFile["LAUNCH"]["AppImportRegFile"]
  if (($AppImportRegFile -eq $null) -or ($AppImportRegFile -eq ""))
  {
    $AppImportRegFile = 0
  }
  Else
  {
    if ($AppImportRegFile -eq 1)
    {
      $AppRegFile = $IniFile["LAUNCH"]["AppRegFile"]
      if (($AppRegFile -eq $null) -or ($AppRegFile -eq ""))
      {
        $msgBoxInput = [System.Windows.MessageBox]::Show("Registry File to import not found in INI-File.","Error","OK","Error")
        switch  ($msgBoxInput)
        {
          "OK"
          {
            Exit 1
          }
        }
      }
      else
      {
        $AppRegFileExists = test-path $AppRegFile
        if ($AppRegFileExists -eq $false)
        {
          $msgBoxInput = [System.Windows.MessageBox]::Show("Specified registry file not found.","Error","OK","Error")
          switch  ($msgBoxInput)
          {
            "OK"
            {
              Exit 1
            }
          }
        }
      }
    }
    Else
    {
      $AppImportRegFile = 0
    }
  }

  $AppRunFirst = $IniFile["LAUNCH"]["AppRunFirst"]
  if (($AppRunFirst -eq $null) -or ($AppRunFirst -eq ""))
  {
    $AppRunFirst = 0
  }
  Else
  {
    if ($AppRunFirst -eq 1)
    {
      $AppRunFirstEXE = $IniFile["LAUNCH"]["AppRunFirstEXE"]
      if (($AppRunFirstEXE -eq $null) -or ($AppRunFirstEXE -eq ""))
      {
        $msgBoxInput = [System.Windows.MessageBox]::Show("Run First Executable not found in INI-File.","Error","OK","Error")
        switch  ($msgBoxInput)
        {
          "OK"
          {
            Exit 1
          }
        }
      }
      else
      {
        $AppRunFirstEXE_Exists = test-path $AppRunFirstEXE
        if ($AppRunFirstEXE_Exists -eq $false)
        {
          $msgBoxInput = [System.Windows.MessageBox]::Show("Specified Run First Executable not found.","Error","OK","Error")
          switch  ($msgBoxInput)
          {
            "OK"
            {
              Exit 1
            }
          }
        }
        else
        {
          $AppRunFirstCommandLineArgs = $IniFile["LAUNCH"]["AppRunFirstCommandLineArgs"]
          if (($AppRunFirstCommandLineArgs -eq $null) -or ($AppRunFirstCommandLineArgs -eq ""))
          {
            $AppRunFirstCommandLineArgs = 0
          }

          $WaitForAppRunFirstEXE = $IniFile["CONFIG"]["WaitForAppRunFirstEXE"]
          if (($WaitForAppRunFirstEXE -eq $null) -or ($WaitForAppRunFirstEXE -eq ""))
          {
            $WaitForAppRunFirstEXE = 0
          }
          if ($WaitForAppRunFirstEXE -eq 1)
          {
            # Derive the processname from AppRunFirstEXE
            $RunFirstEXESplit1 = $AppRunFirstEXE.split("\")
            $RunFirstEXESplit2 = ($RunFirstEXESplit1[-1]).split(".")
            $EXEProcessToCheck = $RunFirstEXESplit2[0]
          }
        }
      }
    }
    Else
    {
      $AppRunFirst = 0
    }
  }
}
Else
{
  $msgBoxInput = [System.Windows.MessageBox]::Show("Specified INI-File not found.","Error","OK","Error")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 1
    }
  }
}

# Currentdir is the actual running directory
$currentDir = [System.AppDomain]::CurrentDomain.BaseDirectory.TrimEnd('\')
if ($currentDir -eq $PSHOME.TrimEnd('\'))
{
  $currentDir = $PSScriptRoot
}


# Load libraries
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') | Out-Null
[System.Reflection.Assembly]::LoadFrom($currentdir + "\assembly\MahApps.Metro.dll") | Out-Null
[System.Reflection.Assembly]::LoadFrom($currentdir + '\assembly\System.Windows.Interactivity.dll') | Out-Null

#The splash-screen
$hash = [hashtable]::Synchronized(@{})
$runspace = [runspacefactory]::CreateRunspace()
$runspace.ApartmentState = "STA"
$runspace.ThreadOptions = "ReuseThread"
$runspace.Open()
$runspace.SessionStateProxy.SetVariable("hash",$hash)
$runspace.SessionStateProxy.SetVariable("TitleLabel",$TitleLabel)
$runspace.SessionStateProxy.SetVariable("TitleForeground",$TitleForeground)
$runspace.SessionStateProxy.SetVariable("LoadingLabel",$LoadingLabel)
$runspace.SessionStateProxy.SetVariable("LoadingForeground",$LoadingForeground)
$runspace.SessionStateProxy.SetVariable("BackgroundColor",$BackgroundColor)
$Pwshell = [PowerShell]::Create()

$Pwshell.AddScript({
$xml = [xml]@"
     <Window
	xmlns:Controls="clr-namespace:MahApps.Metro.Controls;assembly=MahApps.Metro"
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Name="WindowSplash" Title="SplashScreen" WindowStyle="None" WindowStartupLocation="CenterScreen"
	ShowInTaskbar ="true"
	Width="600" Height="350" ResizeMode = "NoResize" >

	<Grid>
		<Grid.RowDefinitions>
            <RowDefinition Height="70"/>
            <RowDefinition/>
        </Grid.RowDefinitions>

		<Grid Grid.Row="0" x:Name="Header" >
			<StackPanel Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Stretch" Margin="20,10,0,0">
		    <Label x:Name = "TitleLabel" Margin="0,0,0,0" Height="50"  FontSize="30"/>
			</StackPanel>
		</Grid>
        <Grid Grid.Row="1" >
		 	<StackPanel Orientation="Vertical" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="5,5,5,5">
				<Label x:Name = "LoadingLabel" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="24" Margin = "0,0,0,0"/>
				<Controls:MetroProgressBar x:Name = "ProgressBar" IsIndeterminate="True" Foreground="White" HorizontalAlignment="Center" Width="350" Height="20"/>
			</StackPanel>
        </Grid>
	</Grid>

</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xml
$hash.window = [Windows.Markup.XamlReader]::Load($reader)
$hash.TitleLabel = $hash.window.FindName("TitleLabel")
$hash.TitleLabel.Content = $TitleLabel
$hash.TitleLabel.Foreground = $TitleForeground
$hash.LoadingLabel = $hash.window.FindName("LoadingLabel")
$hash.LoadingLabel.Content = $LoadingLabel
$hash.LoadingLabel.Foreground = $LoadingForeground
$hash.WindowSplash = $hash.window.FindName("WindowSplash")
$hash.WindowSplash.Background = $BackgroundColor
$hash.ProgressBar = $hash.window.FindName("ProgressBar")
$hash.ProgressBar.Foreground = $LoadingForeground
$hash.window.ShowDialog()

}) | Out-Null

# Launching Splash-screen
$Pwshell.Runspace = $runspace
$script:handle = $Pwshell.BeginInvoke()
#Without 5 seconds of sleep, errors are thrown at closure
sleep 5

if ($AppRunFirst -eq 1)
{
  if ($AppRunFirstCommandLineArgs -eq "0")
  {
    start-process $AppRunFirstEXE
    sleep 2
  }
  else
  {
    start-process $AppRunFirstEXE $AppRunFirstCommandLineArgs
  }
}

if ($WaitForAppRunFirstEXE -eq 1)
{
  while ($true)
  {
    $EXEProcessCheck = Get-Process | Where-Object { $_.Name -eq $EXEProcessToCheck}
    if ($EXEProcessCheck -eq $null)
    {
      break
    }
  }
}

if ($WaitForLogonScript -eq 1)
{
  while ($true)
  {
    $LogonProcessCheck = Get-Process | Where-Object { $_.Name -eq $LogonProcessToCheck }
    if ($LogonProcessCheck -eq $null)
    {
      break
    }
  }
}

if ($AppImportRegFile -eq 1)
{
  Invoke-Command {reg import $NAV_RegFile *>&1 | Out-Null}
}

# Closing splash-screen
$hash.window.Dispatcher.Invoke("Normal",[action]{ $hash.window.close() })
$Pwshell.EndInvoke($handle) | Out-Null
$runspace.Close() | Out-Null

if ($AppCommandLineArgs -eq "0")
{
  start-process $AppEXEPath
}
Else
{
  start-process $AppEXEPath $AppCommandLineArgs
}
exit 0
