
# Imports
Import-Module -Name ".\lib\compress.psm1" -Verbose -ErrorAction Stop

### FFmpeg compressor w/ GUI ###
# Ref: https://www.rlvision.com/blog/a-drag-and-drop-gui-made-with-powershell/
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

### Constants ###
$AllowedExtensions = @('.mp4', '.mkv')

### Create form ###

$form = New-Object System.Windows.Forms.Form
$form.Text = "FFmpeg Compress"
$form.Size = New-Object System.Drawing.Size(420, 360)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = $form.Size
$form.MaximizeBox = $False
$form.Topmost = $True


### Define controls ###

$button = New-Object System.Windows.Forms.Button
$button.Location = New-Object System.Drawing.Point(5, 5)
$button.Size = New-Object System.Drawing.Size(75, 23)
$button.Width = 125
$button.Text = "Compress all"

$clearSelectedButton = New-Object System.Windows.Forms.Button
$clearSelectedButton.Location = New-Object System.Drawing.Point(5, 35)
$clearSelectedButton.Size = New-Object System.Drawing.Size(75, 23)
$clearSelectedButton.Width = 125
$clearSelectedButton.Text = "Clear selected items"

$checkbox = New-Object Windows.Forms.Checkbox
$checkbox.Location = New-Object System.Drawing.Point(140, 8)
$checkbox.AutoSize = $True
$checkbox.Text = "Clear afterwards"

$label = New-Object Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(5, 60)

$label.AutoSize = $True
$label.Text = "Drop video files here (Supports $($AllowedExtensions -join ",")):"

$listBox = New-Object Windows.Forms.ListBox
$listBox.Location = New-Object System.Drawing.Point(5, 85)
$listBox.Height = 200
$listBox.Width = 395
$listBox.Anchor = ([System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Top)
$listBox.IntegralHeight = $False
$listBox.AllowDrop = $True
$listbox.SelectionMode = 'MultiExtended'

$statusBar = New-Object System.Windows.Forms.StatusBar
$statusBar.Text = "Ready"


### Add controls to form ###

$form.SuspendLayout()
$form.Controls.Add($button)
$form.Controls.Add($clearSelectedButton)
$form.Controls.Add($checkbox)
$form.Controls.Add($label)
$form.Controls.Add($listBox)
$form.Controls.Add($statusBar)
$form.ResumeLayout()


### Write event handlers ###

$button_Click = {
    # Disable all buttons from being clicked during the job.
    $button.Enabled = $False
    $clearSelectedButton.Enabled = $False
    foreach ($item in $listBox.Items) {
        $statusBar.Text = ("Compressing ${item}...")
        Write-Host "Starting compression job for ${item}" -ForegroundColor Yellow
        Compress-VideoClip $item
    }
    
    if ($checkbox.Checked -eq $True) {
        $listBox.Items.Clear()
    }

    $button.Enabled = $True
    $clearSelectedButton.Enabled = $True
    $statusBar.Text = ("List contains $($listBox.Items.Count) items. Ready")
}

$clearSelectedButton_Click = {
    while ($ListBox.SelectedItems) {
        $CurrItem = $listBox.SelectedItems[0]
        Write-Host "Removing $CurrItem"
        $Listbox.Items.Remove($CurrItem)
    }
}

$listBox_DragOver = [System.Windows.Forms.DragEventHandler] {
    if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
        # $_ = [System.Windows.Forms.DragEventArgs]
        $_.Effect = 'Copy'
    }
    else {
        $_.Effect = 'None'
    }
}
	
$listBox_DragDrop = [System.Windows.Forms.DragEventHandler] {
    $deniedItems = New-Object -TypeName "System.Collections.ArrayList"
    foreach ($filename in $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)) {
        # $_ = [System.Windows.Forms.DragEventArgs]
        # Write-Host (Split-Path $filename -Extension) # DEBUG
        # Check that the file extension is supported
        if ($AllowedExtensions -contains (Split-Path $filename -Extension)) {
            $listBox.Items.Add($filename)
        } 
        else {
            Write-Host $basename
            $deniedItems.Add($filename)
        }
    }
    if ($deniedItems.Count -eq 0) {
        $statusBar.Text = ("List contains $($listBox.Items.Count) items. Ready")
    }
    else {
        # Write denied items to the console
        $deniedString = $deniedItems -join ", "
        $statusBar.Text = ("The following items were denied: $($deniedString)")
    }
}

$form_FormClosed = {
    try {
        $listBox.remove_Click($button_Click)
        $listBox.remove_DragOver($listBox_DragOver)
        $listBox.remove_DragDrop($listBox_DragDrop)
        $listBox.remove_DragDrop($listBox_DragDrop)
        $form.remove_FormClosed($Form_Cleanup_FormClosed)
    }
    catch [Exception]
    { }
}


### Wire up events ###

$button.Add_Click($button_Click)
$clearSelectedButton.Add_Click($clearSelectedButton_Click)
$listBox.Add_DragOver($listBox_DragOver)
$listBox.Add_DragDrop($listBox_DragDrop)
$form.Add_FormClosed($form_FormClosed)


#### Show form ###

[void] $form.ShowDialog()