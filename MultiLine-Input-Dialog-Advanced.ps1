Function Read-MultiLineInputDialog([string]$WindowTitle, [string]$Message, [string]$InboxType, [int]$FontSize=12, [string]$ReturnType="str", [bool]$ShowDebug=$false) {#「@Daniel Schroeder」
    #-WindowTitle "Str Value"  == Title of the prompt window
    #-Message     "Str Value"  == Prompt text shown above textbox and below title box
    #-InboxType   "1" / "txt"  == Default MultiLine Input Dialog
    #-InboxType   "2" / "dnd"  == Drag & Drop MultiLine Path Input Dialog
    #-FontSize    (Default 12) == Default textbox font size
    #-ReturnType  "1" / "str"  == Return a multi-line string of items, empty lines are scrubbed
    #-ReturnType  "2" / "ary"  == Return an array of items, empty array items are scrubbed
    $DebugPreference = 'Continue'
    if (($host.name -match 'consolehost')) {
        if ($ShowDebug -eq $true) {Write-Debug "√ Running inside PowerShell Console, using resolution data from GWMI"}
        $oWidth  = gwmi win32_videocontroller | select-object CurrentHorizontalResolution -first 1
        $oHeight = gwmi win32_videocontroller | select-object CurrentVerticalResolution -first 1
        [int]$mWidth  = [Convert]::ToInt32($oWidth.CurrentHorizontalResolution)
        [int]$mHeight = [Convert]::ToInt32($oHeight.CurrentVerticalResolution)
        #Write-Debug "√ $mWidth x $mHeight"
    }
    else {
        if ($ShowDebug -eq $true) {Write-Debug "√ Running inside PowerShell ISE, using resolution data from SysInfo"}
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
    $label.Location = New-Object System.Drawing.Size($LBStartX,$LBStartY) #Label text starting position
    $label.Size = New-Object System.Drawing.Size($LblSizeX,$LblSizeY) #Label text box size
    $label.AutoSize = $true
    $label.Text = $Message

    #Converting from monitor resolution: position & size of input textbox & listbox
    [int]$LBStartX = [int]$TBStartX = [math]::Round($mWidth /192)
    [int]$LBStartY = [int]$TBStartY = [math]::Round($mHeight/27)
    [int]$TblSizeX = [math]::Round($mWidth /3.728)
    [int]$LblSizeX = [math]::Round($mWidth /3.792)
    [int]$LblSizeY = [int]$TblSizeY = [math]::Round($mHeight/2.6)
    if (($host.name -match 'consolehost')) {$TblSizeX-=3; $LblSizeX-=3} #Compensate width rendering difference in PowerShell Console
    
    #Drawing textbox 1 / listbox 2
    if     (($InboxType -eq "txt") -or ($InboxType -eq "1")) {
        $textBox               = New-Object System.Windows.Forms.TextBox 
        $textBox.Location      = New-Object System.Drawing.Size($TBStartX,$TBStartY) #Draw starting postiton
        $textBox.Size          = New-Object System.Drawing.Size($TblSizeX,$TblSizeY) #Size of textbox
        $textBox.Font          = New-Object System.Drawing.Font((New-Object System.Windows.Forms.Form).font.Name,$FontSize)
        $textBox.AcceptsReturn = $true
        $textBox.AcceptsTab    = $false
        $textBox.Multiline     = $true
        $textBox.ScrollBars    = 'Both'
        $textBox.Text          = "" #Leave default text blank in order to check if user has typed / pasted nothing and (accidentally) clicks OK, which can mitigated userby Do-While loop checking and prevents a script startover of frustration
    }
    elseif (($InboxType -eq "dnd") -or ($InboxType -eq "2")) {
        $listBox = New-Object Windows.Forms.ListBox
        $listBox.Location = New-Object System.Drawing.Size($LBStartX,$LBStartY) #Draw starting postiton
        $listBox.Size = New-Object System.Drawing.Size($LblSizeX,$LblSizeY) #Size of textbox
        $listBox.Font = New-Object System.Drawing.Font((New-Object System.Windows.Forms.Form).font.Name,$FontSize)
        $listBox.Anchor = ([System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Top)
        $listBox.AutoSize = $true
        $listBox.IntegralHeight = $false
        $listBox.AllowDrop = $true
        $listBox.ScrollAlwaysVisible = $false
        #Create Drag-&-Drop events with effects to actually get the GUI working, not the copy-to-CLI side
        $listBox_DragOver = [System.Windows.Forms.DragEventHandler]{
	        if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {$_.Effect = 'Copy'}                       #$_=[System.Windows.Forms.DragEventArgs]
	        else                                                               {$_.Effect = 'None'}
        }
        $listBox_DragDrop = [System.Windows.Forms.DragEventHandler]{
	        foreach ($filename in $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)) {$listBox.Items.Add($filename)} #$_=[System.Windows.Forms.DragEventArgs]
        }
        #Create "Delete" keydown event to delete selected items in listBox mode
        $listBox.Add_KeyDown({
            if (($PSItem.KeyCode -eq "Delete") -and ($listBox.Items.Count -gt 0)) {$listBox.Items.Remove($listBox.SelectedItems[0])}
        })
    }

    #Converting from monitor resolution: OK button's starting position & size
    [int]$OKStartX = [math]::Round($mWidth /4.7)
    [int]$OKStartY = [math]::Round($mHeight/108)
    [int]$OKbSizeX = [math]::Round($mWidth /34.92)
    [int]$OKbSizeY = [math]::Round($mHeight/47)
    if (($host.name -match 'consolehost')) {$OKStartX-=3} #Compensate width rendering difference in PowerShell Console
    #Drawing the OK button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Size($OKStartX,$OKStartY) #OK button position
    $okButton.Size = New-Object System.Drawing.Size($OKbSizeX,$OKbSizeY) #OK button size
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    if     (($InboxType -eq "txt") -or ($InboxType -eq "1")) {$okButton.Add_Click({$form.Tag = $textBox.Text; $form.Close()})}
    elseif (($InboxType -eq "dnd") -or ($InboxType -eq "2")) {$okButton.Add_Click({$form.Tag = $listBox.Text; $form.Close()})}
    #Converting from monitor resolution: Cancel button's starting position
    [int]$ClStartX = [math]::Round($mWidth /4.08)
    [int]$ClStartY = $OKStartY #Same Height as the OK button
    [int]$ClbSizeX = $OKbSizeX #Same size as the OK button
    [int]$ClbSizeY = $OKbSizeY #Same size as the OK button
    if (($host.name -match 'consolehost')) {$ClStartX-=3} #Compensate width rendering difference in PowerShell Console
    #Drawing the Cancel / Clear button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Size($ClStartX,$ClStartY)
    $cancelButton.Size = New-Object System.Drawing.Size($ClbSizeX,$ClbSizeY)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancelButton.Add_Click({$form.Tag = $null; Try{$listBox.Items.Clear()}Catch [Exception]{}; $form.Close()})
    #Converting from monitor resolution: size of the prompt/form window
    [int]$formSizeX = [math]::Round($mWidth /3.56)
    [int]$formSizeY = [math]::Round($mHeight/2.18)
    if (($host.name -match 'consolehost')) {$formSizeX+=2} #Compensate width rendering difference in PowerShell Console
    #Draw the form window
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $WindowTitle
    $form.Size = New-Object System.Drawing.Size($formSizeX,$formSizeY) #Form window size
    $form.FormBorderStyle = 'FixedSingle'
    $form.StartPosition = "CenterScreen"
    $form.AutoSizeMode = 'GrowAndShrink'
    $form.Topmost = $false
    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton
    $form.ShowInTaskbar = $true
    #Add control elements to the prompt/form window
    $form.Controls.Add($label); $form.Controls.Add($okButton); $form.Controls.Add($cancelButton)
    if     (($InboxType -eq "txt") -or ($InboxType -eq "1")) {
        if ($ShowDebug -eq $true) {Write-Debug "! Mode == MultiLine textBox Form"}
        $form.Controls.Add($textBox)
    }
    elseif (($InboxType -eq "dnd") -or ($InboxType -eq "2")) {
        if ($ShowDebug -eq $true) {Write-Debug "! Mode == Drag&Drop listBox From"}
        $form.Controls.Add($listBox)
        #Add form Closing events for drag-&-drop events only, basically to remove data from listBox
        $form_FormClosed = {
	        try {
                $listBox.remove_Click($button_Click)
		        $listBox.remove_DragOver($listBox_DragOver)
		        $listBox.remove_DragDrop($listBox_DragDrop)
                $listBox.remove_DragDrop($listBox_DragDrop)
		        $form.remove_FormClosed($Form_Cleanup_FormClosed)
	        }
	        catch [Exception] {}
        }
        #Load Drag-&-Drop events into the form
        $listBox.Add_DragOver($listBox_DragOver)
        $listBox.Add_DragDrop($listBox_DragDrop)
        $form.Add_FormClosed($form_FormClosed)
    }
    #Load Add_Shown event used by both textbox & drag-&-drop events into form
    $form.Add_Shown({$form.Activate()})
    #Load Key_Down event for closing with ESC button
    $form.Add_KeyDown({
        if ($PSItem.KeyCode -eq "Escape") {$cancelButton.PerformClick()}
    })
    #Normal prompting, user can proceed with $null return by clicking Cancel or ×, or empty string by clicking OK
    $form.ShowDialog()
    #Scrub empty lines away and return in multi-line string / array based on user definition
    if     ((($InboxType -eq "txt")-or($InboxType -eq "1")) -and ($form.Tag -eq ""))                                {return ""}    #No content in textbox, return string
    elseif ((($InboxType -eq "dnd")-or($InboxType -eq "2")) -and ($listBox.Items.count -eq 0))                      {return $null} #No content in listbox, return $null
    elseif ((($InboxType -eq "txt")-or($InboxType -eq "1")) -and (($ReturnType -eq "str")-or($ReturnType -eq "1"))) {return (($form.Tag.Split("`r`n").Trim()      | where {$_ -ne ""}) | Out-String)} #Multiline textBox string out
    elseif ((($InboxType -eq "dnd")-or($InboxType -eq "2")) -and (($ReturnType -eq "str")-or($ReturnType -eq "1"))) {return (($listBox.Items.Split("`r`n").Trim() | where {$_ -ne ""}) | Out-String)} #Drag&Drop listBox string out
    elseif ((($InboxType -eq "txt")-or($InboxType -eq "1")) -and (($ReturnType -eq "ary")-or($ReturnType -eq "2"))) {return  ($form.Tag.Split("`r`n").Trim()      | where {$_ -ne ""})              } #Multiline textBox, array out
    elseif ((($InboxType -eq "dnd")-or($InboxType -eq "2")) -and (($ReturnType -eq "ary")-or($ReturnType -eq "2"))) {return  ($listBox.Items.Split("`r`n").Trim() | where {$_ -ne ""})              } #Drag&Drop listBox, array out
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

$mLineVarStr="" #Initialization, and if Read-MultiLineInputDialog outputs $null, this variable remains being ""

#Do-While loop-on-error prompting - Textbox mode - Array output
#User cannot proceed by returning empty string, or false values defined by your cusmization
#Do {($mLineVarAry = Read-MultiLineInputDialog -Message "Put your text items here, separated by line breaks
#This box allows up to 2 lines of text for extra notes." -WindowTitle "🖅 MLI-Dialog Advanced - Textbox mode - No Empty" -InboxType "1" -ReturnType "ary")
#    if  ($mLineVarAry -eq "") {Write-Error "× Received empty value, try again"}
#} While ($mLineVarAry -eq "")

#Normal Prompting (allows empty output) - Textbox mode - String output
$mLineVarStr = Read-MultiLineInputDialog -Message "Put your text items here, separated by line breaks
This box allows up to 2 lines of text for extra notes" -WindowTitle "🖅 MLI-Dialog Advanced - Textbox mode" -InboxType "txt" -ReturnType "str"
$mLineVarStr

#Normal Prompting (allows empty output) - Drag & drop mode - String output
$dDropVarStr = Read-MultiLineInputDialog -Message "Drag each of your file items here
This box allows up to 2 lines of text for extra notes" -WindowTitle "🖅 MLI-Dialog Advanced - Drag&drop mode" -InboxType "dnd" -ReturnType "str"
$dDropVarStr
#$mLineVarStr.GetType()

#Normal Prompting (allows empty output) - Drag & drop mode - Array output
$dDropVarAry = Read-MultiLineInputDialog -Message "Drag each of your file items here
This box allows up to 2 lines of text for extra notes" -WindowTitle "🖅 MLI-Dialog Advanced - Drag&drop mode" -InboxType "dnd" -ReturnType "2"
$dDropVarAry 
#$mLineVarAry.GetType()
