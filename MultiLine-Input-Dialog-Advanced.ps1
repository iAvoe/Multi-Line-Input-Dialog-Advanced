Function Read-MultiLineInputDialog([string]$Message, [string]$WindowTitle, [string]$DefaultText) {#「@Daniel Schroeder」
    $DebugPreference = 'Continue'
    if (($host.name -match 'consolehost')) {
        Write-Debug "√ Running inside PowerShell Console, using resolution data from GWMI"
        $oWidth  = gwmi win32_videocontroller | select-object CurrentHorizontalResolution -first 1
        $oHeight = gwmi win32_videocontroller | select-object CurrentVerticalResolution -first 1
        [int]$mWidth  = [Convert]::ToInt32($oWidth.CurrentHorizontalResolution)
        [int]$mHeight = [Convert]::ToInt32($oHeight.CurrentVerticalResolution)
        #Write-Debug "√ $mWidth x $mHeight"
    }
    else {
        Write-Debug "√ Running inside PowerShell ISE, using resolution data from SysInfo"
        [int]$mWidth  = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width
        [int]$mHeight = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height
    }
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms
    #Converting from monitor resolution: position of window label text
    [int]$LBStartX = [math]::Round($mWidth /192)
    [int]$LBStartY = [math]::Round($mHeight/108)
    [int]$LblSizeX = [math]::Round($mWidth /19)
    [int]$LblSizeY = [math]::Round($mHeight/54)
    #Label text under the GUI title, with content from $Message
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Size($LBStartX,$LBStartY) #非换算
    $label.Size = New-Object System.Drawing.Size($LblSizeX,$LblSizeY) #非换算，$Message太长则增加
    $label.AutoSize = $true
    $label.Text = $Message
    #Converting from monitor resolution: position & size of input textbox
    [int]$TBStartX = [math]::Round($mWidth /192)
    [int]$TBStartY = [math]::Round($mHeight/27)
    [int]$TblSizeX = [math]::Round($mWidth /3.73)
    [int]$TblSizeY = [math]::Round($mHeight/2.57)
    #Drawing textbox
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Size($TBStartX,$TBStartY) #Draw starting postiton
    $textBox.Size = New-Object System.Drawing.Size($TblSizeX,$TblSizeY) #Size of textbox
    $textBox.Font = New-Object System.Drawing.Font((New-Object System.Windows.Forms.Form).font.Name,10) #Fixing the small font size in high-dpi monitor, meanwhile not making it oversized for low-dpi monitor
    $textBox.AcceptsReturn = $true
    $textBox.AcceptsTab = $false
    $textBox.Multiline = $true
    $textBox.ScrollBars = 'Both'
    $textBox.Text = $DefaultText
    #Converting from monitor resolution: OK button's starting position & size
    [int]$OKStartX = [math]::Round($mWidth /4.7)
    [int]$OKStartY = [math]::Round($mHeight/108)
    [int]$OKbSizeX = [math]::Round($mWidth /34.92)
    [int]$OKbSizeY = [math]::Round($mHeight/47)
    #Drawing the OK button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Size($OKStartX,$OKStartY) #OK button position
    $okButton.Size = New-Object System.Drawing.Size($OKbSizeX,$OKbSizeY) #OK button size
    $okButton.Text = "√ OK"
    $okButton.DialogResult = "OK" #Or $okButton.DialogResult = $okButton.Text = "OK" for one line, but that's anti-lang-localization
    $okButton.Add_Click({$form.Tag = $textBox.Text; $form.Close()})
    #Converting from monitor resolution: Cancel button's starting position
    [int]$ClStartX = [math]::Round($mWidth /4.08)
    [int]$ClStartY = $OKStartY #Same Height as the OK button
    [int]$ClbSizeX = $OKbSizeX #Same size as the OK button
    [int]$ClbSizeY = $OKbSizeY #Same size as the OK button
    #Drawing the Cancel button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Size($ClStartX,$ClStartY)
    $cancelButton.Size = New-Object System.Drawing.Size($ClbSizeX,$ClbSizeY)
    $cancelButton.Text = "× Cancel"
    $cancelButton.DialogResult = "Cancel"
    $cancelButton.Add_Click({$form.Tag = $null; $form.Close()})
    #Converting from monitor resolution: size of the prompt/form window
    [int]$formSizeX = [math]::Round($mWidth /3.56)
    [int]$formSizeY = [math]::Round($mHeight/2.18)
    #Draw the form window
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $WindowTitle
    $form.Size = New-Object System.Drawing.Size($formSizeX,$formSizeY) #Form window size
    $form.FormBorderStyle = 'FixedSingle'
    $form.StartPosition = "CenterScreen"
    $form.AutoSizeMode = 'GrowAndShrink'
    $form.Topmost = $True
    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton
    $form.ShowInTaskbar = $true
    #Add control elements to the prompt/form window
    $form.Controls.Add($label); $form.Controls.Add($textBox); $form.Controls.Add($okButton); $form.Controls.Add($cancelButton)
    #Load and show the window
    $form.Add_Shown({$form.Activate()})
    #Do-While loop enforced UserErrorAction-Rewind prompting, user can still proceed by returning empty string by clicking OK
    Do {$dInput = $form.ShowDialog(); if ($dInput -eq "Cancel") {Write-Debug "× Unable to cancel, please stop PowerShell Window instead"}} While ($dInput -eq "Cancel")
    #Normal prompting, user can proceed with $null return by clicking Cancel or ×, or empty string by clicking OK
    #$form.ShowDialog()
    #Return input value
    return $form.Tag
}
#「@MrNetTek」Enable DPI-Aware Windows Forms
Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public class ProcessDPI {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetProcessDPIAware();      
}
'@
$null = [ProcessDPI]::SetProcessDPIAware()

clear

$mLineVarStr="" #Initialization, and if Read-MultiLineInputDialog outputs $null, this variable remains being ""

#Do-While loop enforced UserErrorAction-Rewind prompting, user cannot proceed by returing empty string
Do {($mLineVarStr = Read-MultiLineInputDialog -Message "★ Input all text items, separated by line breaks" -WindowTitle "★ Multi-line text input window" -DefaultText ""); if ($mLineVarStr -eq "") {Write-Error "× Received empty value, try again"}} While ($mLineVarStr -eq "")

#Normal Prompting
$mLineVarStr = Read-MultiLineInputDialog -Message "★ Input all text items, separated by line breaks" -WindowTitle "★ Multi-line text input window" -DefaultText ""

#Convert multi-line string to Array datatype and clear empty array items
#The Array item can be directly piped to a ForEach-Object loop and do "+=" styled variable assigns
$mLineVarAry = $mLineVarStr.Split("`r`n").Trim() | where {$_ -ne ""}