param ($PublishedAppIni)
<#
.SYNOPSIS
  Starts Navision with a specific set of parameters
.DESCRIPTION
  Starts Navision based on parameters in a defined INI-file
.PARAMETER PublishedAppIni
  Ini file name0
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  19/07/2021
  Purpose/Change: Create a launcher for Navision published applications
 .EXAMPLE
  None
#>

# Function to read config.ini
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

#Check if INI File exists
$IniFileExists = Test-Path $PublishedAppIni
If ($IniFileExists)
{
  #Read inifile
  $IniFile = Get-IniContent $PublishedAppIni

  $WaitForLogonScript = $IniFile["CONFIG"]["WaitForLogonScript"]
  if ($WaitForLogonScript -eq $null)
  {
    $WaitForLogonScript = 0
  }
  if ($WaitForLogonScript -eq 1)
  {
    $ProcessToCheck = $IniFile["CONFIG"]["WaitForProcess"]
    if ($ProcessToCheck -eq $null)
    {
      $ProcessToCheck = ""
    }
  }

  $AppCommandLine = $IniFile["LAUNCH"]["AppCommandLine"]
  if ($AppCommandLine -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("CommandLine not found in INI-File.","Error","OK","Error")
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
    $ExeFileExists = Test-Path $AppCommandLine
    if ($ExeFileExists -eq $false)
    {
      $msgBoxInput = [System.Windows.MessageBox]::Show("CommandLine EXE not found.","Error","OK","Error")
      switch  ($msgBoxInput)
      {
        "OK"
        {
          Exit 1
        }
      }
    }
  }

  $NAV_ServerName = $IniFile["LAUNCH"]["NAV_ServerName"]
  if ($NAV_ServerName -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("NAV Databaseserver not found in INI-File.","Error","OK","Error")
    switch  ($msgBoxInput)
    {
      "OK"
      {
        Exit 1
      }
    }
  }

  $NAV_Database = $IniFile["LAUNCH"]["NAV_Database"]
  if ($NAV_Database -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("NAV Database not found in INI-File.","Error","OK","Error")
    switch  ($msgBoxInput)
    {
      "OK"
      {
        Exit 1
      }
    }
  }

  $NAV_UseGenericZUP = $IniFile["LAUNCH"]["NAV_UseGenericZUP"]
  if ($NAV_UseGenericZUP -eq $null)
  {
    $NAV_UseGenericZUP = 0
  }
  Else
  {
    if ($NAV_UseGenericZUP -eq 1)
    {
      $NAV_GenericZUP = $IniFile["LAUNCH"]["NAV_GenericZUP"]
      if ($NAV_GenericZUP -eq $null)
      {
        $msgBoxInput = [System.Windows.MessageBox]::Show("Generic ZUP file not found in INI-File.","Error","OK","Error")
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
        $NAV_GenericZUPFile = $env:ZUPS+"\Generic\"+$NAV_GenericZUP
        $NAV_GenericZUPFileExists = test-path $NAV_GenericZUPFile
        if ($NAV_GenericZUPFileExists -eq $false)
        {
          $msgBoxInput = [System.Windows.MessageBox]::Show("Generic ZUP file not found.","Error","OK","Error")
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
  }

  $NAV_NTAUT = $IniFile["LAUNCH"]["NAV_NTAUT"]
  if ($NAV_NTAUT -eq $null)
  {
    $NAV_NTAUT = 0
  }

  $NAV_Company = $IniFile["LAUNCH"]["NAV_Company"]
  if ($NAV_Company -eq $null)
  {
    $NAV_Company = 0
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

# Initialize variables
if ($NAV_UseGenericZUP -eq 0)
{
  $NAV_ID = $env:ZUPS+"\"+$NAV_ServerName+"\"+$env:username+".zup"
}
else
{
  $NAV_ID = $NAV_GenericZUPFile
}

$currentDir = [System.AppDomain]::CurrentDomain.BaseDirectory.TrimEnd('\')
if ($currentDir -eq $PSHOME.TrimEnd('\'))
{
  $currentDir = $PSScriptRoot
}
# Currentdir is the actual running directory

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
$Pwshell = [PowerShell]::Create()

$Pwshell.AddScript({
$xml = [xml]@"
     <Window
	xmlns:Controls="clr-namespace:MahApps.Metro.Controls;assembly=MahApps.Metro"
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	x:Name="WindowSplash" Title="SplashScreen" WindowStyle="None" WindowStartupLocation="CenterScreen"
	Background="Red" ShowInTaskbar ="true"
	Width="600" Height="350" ResizeMode = "NoResize" >

	<Grid>
		<Grid.RowDefinitions>
            <RowDefinition Height="70"/>
            <RowDefinition/>
        </Grid.RowDefinitions>

		<Grid Grid.Row="0" x:Name="Header" >
			<StackPanel Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Stretch" Margin="20,10,0,0">
				<Label Content="KTN Launcher" Margin="0,0,0,0" Foreground="White" Height="50"  FontSize="30"/>
			</StackPanel>
		</Grid>
        <Grid Grid.Row="1" >
		 	<StackPanel Orientation="Vertical" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="5,5,5,5">
				<Label x:Name = "LoadingLabel"  Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="24" Margin = "0,0,0,0"/>
				<Controls:MetroProgressBar IsIndeterminate="True" Foreground="White" HorizontalAlignment="Center" Width="350" Height="20"/>
			</StackPanel>
        </Grid>
	</Grid>

</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xml
$hash.window = [Windows.Markup.XamlReader]::Load($reader)
$hash.LoadingLabel = $hash.window.FindName("LoadingLabel")
$hash.LoadingLabel.Content= "Getting ready..."
$hash.window.ShowDialog()

}) | Out-Null

# Launching Splash-screen
$Pwshell.Runspace = $runspace
$script:handle = $Pwshell.BeginInvoke()
#Without 5 seconds of sleep, errors are thrown at closure
sleep 5

if ($WaitForLogonScript -eq 1)
  {
    while ($true)
    {
      $ProcessCheck = Get-Process | Where-Object { $_.Name -eq $ProcessToCheck }
      if ($ProcessCheck -eq $null)
      {
        break
      }
    }

  }

# Closing splash-screen
$hash.window.Dispatcher.Invoke("Normal",[action]{ $hash.window.close() })
$Pwshell.EndInvoke($handle) | Out-Null
$runspace.Close() | Out-Null



if ($NAV_Company -eq 0)
{
  $AppCommandLineArgs = " SERVERNAME="+$NAV_ServerName+",database="+$NAV_Database+",ID="+$NAV_ID+",ntauthentication="+$NAV_NTAUT+"
}
Else
{
  $AppCommandLineArgs = " SERVERNAME="+$NAV_ServerName+",database="+$NAV_Database+",ID="+$NAV_ID+",ntauthentication="+$NAV_NTAUT+",company="+$NAV_Company
}
#write-host $FullCommand
start-process $AppCommandLine $AppCommandLineArgs
exit 0