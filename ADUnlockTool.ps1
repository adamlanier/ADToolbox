
#-------------------------------------------------------------#
#----Initial Declarations-------------------------------------#
#-------------------------------------------------------------#

Add-Type -AssemblyName PresentationCore, PresentationFramework

$Xaml = @"
<Window 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Active Directory Unlock Tool" Background="LightBlue" Height="215" MinHeight="215" MaxHeight="215" Width="600" MinWidth="600" MaxWidth="600">

    <Grid>

        <TextBlock Name="CurrentUserLbl" HorizontalAlignment="Left" Margin="30,23,0,0" TextWrapping="Wrap" Text="You are signed in as:" VerticalAlignment="Top" Height="16" Width="108"/>
        <TextBox Name="CurrentUserTxt" IsReadOnly="True" HorizontalAlignment="Left" Margin="143,21,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="85" IsEnabled="False" Height="18"/>

        <TextBlock Name="TargetUserLbl" Text="Target User:" Margin="76,46,0,0"  VerticalAlignment="Top" Height="16" HorizontalAlignment="Left" Width="62"/>
        <TextBox Name="TargetUserTxt" HorizontalAlignment="Left" Margin="143,44,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="85" MaxLength="8" Height="18" />

        <Button Name="GoBtn" FontFamily="Segoe MDL2 Assets" Content="&#xE72A;" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" HorizontalAlignment="Left" Margin="233,43,0,0" VerticalAlignment="Top" RenderTransformOrigin="1.246,0.498" Height="20" Width="20"/>
        <Button Name="UnlockBtn" Content="Unlock" HorizontalAlignment="Left" Margin="143,67,0,0" VerticalAlignment="Top" Width="85" IsEnabled="False" Height="20"/>
        <Button Name="ResetPasswordBtn" Visibility="Hidden" Content="Reset Password" HorizontalAlignment="Left" Margin="143,92,0,0" VerticalAlignment="Top" IsEnabled="False" Height="20" Width="85" RenderTransformOrigin="0.504,0.472"/>
        <Button Name="ClearBtn" Content="Clear" HorizontalAlignment="Left" Margin="503,136,0,0" VerticalAlignment="Top" Width="65" Height="20"/>

        <RichTextBox Name="OutputTextbox" Margin="268,21,0,0" IsReadOnly="True" HorizontalAlignment="Left" Width="300" Height="110" VerticalAlignment="Top">
            <FlowDocument>
                <Paragraph>
                    <Run Text="Please enter a target user."/>
                </Paragraph>
            </FlowDocument>
        </RichTextBox>
    </Grid>
</Window>


"@

#-------------------------------------------------------------#
#----Functions------------------------------------------------#
#-------------------------------------------------------------#

#region Functions
function Clear-Output-Textbox {
    $OutputTextbox.Document.Blocks.Clear()
    $TargetUserTxt.Clear()
    $OutputTextbox.AppendText("Please enter a target user.")
    $UnlockBtn.IsEnabled = $false
}
function Set-Output-Textbox ([system.management.automation.pscredential] $Cred){
    $OutputTextbox.Document.Blocks.Clear()
    if ( [String]::IsNullOrEmpty($TargetUserTxt.Text))
    {
        Clear-Output-Textbox
        Return
    }
    $TargetUser = Get-Target-User($Cred)
    if ($TargetUser -ne $false){
        $OutputTextbox.AppendText("Name: " + $TargetUser.gecos + "`r") 
        $OutputTextbox.AppendText("User ID: " + $TargetUser.SamAccountName + "`r") 
        $OutputTextbox.AppendText("Email: " + $TargetUser.UserPrincipalName + "`r")
        $OutputTextbox.AppendText("Location: " + $TargetUser.Division + "`r")
        $OutputTextbox.AppendText("Locked: " + $TargetUser.LockedOut + "`r")
        $OutputTextbox.AppendText("Enabled: " + $TargetUser.Enabled + "`r")
        $UnlockBtn.IsEnabled = $true
    }
}
function Get-Target-User([system.management.automation.pscredential] $Cred){
    $TargetID = $TargetUserTxt.Text
    try {
        $TargetUser = Get-ADUser -Identity $TargetID -Credential $Cred -Server $ADServer -Properties $TargetUserProperties -ErrorAction Stop
        return $TargetUser
    }
    # old authentication that was a temp fix
    <# catch [System.Security.Authentication.AuthenticationException] {
        Write-Host "Unable to authenticate your credentials."
        Write-Host $_
        Exit
    } #>
    catch {
        $OutputTextbox.Document.Blocks.Clear()
        $OutputTextbox.AppendText("Unable to find user $TargetID. Please try again.`r`r")
        $OutputTextbox.AppendText($Error[0])
        return $false
    }

}
function Unlock-Target-User([system.management.automation.pscredential] $Cred){
    $TargetID = $TargetUserTxt.Text
    try{
        Unlock-ADAccount -Identity $TargetID -Credential $Cred -Server $ADServer -ErrorAction Stop
        Set-Output-Textbox($Cred)
        Write-Host "$TargetID was unlocked."
    }
    catch{
        $OutputTextbox.Document.Blocks.Clear()
        $OutputTextbox.AppendText("Unable to unlock $TargetID. Error code below.`r`r")
        $OutputTextbox.AppendText($Error[0])
    }
}
function Test-Credentials([system.management.automation.pscredential] $Cred){
    try {
        $Test = Get-ADDomain -Credential $Cred -Server $ADServer -ErrorAction Stop
    }
    catch {
        Write-Host "Unable to authenticate your credentials."
        Write-Host $_
        return $false
    }
    return $true
}
function Import-AD{
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
    }
    catch {
        Write-Host "There was an error while importing the Active Directory Module."
        Write-Host $_
        Exit
    }
}
#endregion 

#-------------------------------------------------------------#
#----Execution------------------------------------------------#
#-------------------------------------------------------------#
 
# xml setup
$Window = [Windows.Markup.XamlReader]::Parse($Xaml)
[xml]$Xml = $Xaml
$Xml.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name $_.Name -Value $Window.FindName($_.Name) }

#region Setup

# Declaring variables. Note: ADServer has been omitted and must be updated prior to running. 
$Env:ADPS_LoadDefaultDrive = 0
$script:ADServer = "EXAMPLE.COM"
$script:Authenticated = $false
$script:AuthenticationAttempts = 0
$script:AuthenticationAttemptsLimit = 5
$script:TargetUserProperties = @(
    'gecos'
    'SamAccountName'
    'UserPrincipalName'
    'Division'
    'LockedOut'
    'Enabled')

# Import AD module. Gather creds and authenticate
Import-AD
do {
    $AuthenticationAttempts += 1
    $Cred = Get-Credential -Message "Please log in with your elevated ~ account."

    # Allow user to cancel or exit out of the credentials prompt.
    if (!$Cred){Exit}

    $Authenticated = Test-Credentials($Cred)
    if ($Authenticated){break}
} until ($AuthenticationAttempts -ge $AuthenticationAttemptsLimit)
if (!$Authenticated){
    Write-Host "Unable to authenticate your credentials."
    Exit
}
$CurrentUserTxt.Text = $cred.UserName
#endregion

#region Clicks/Keys
$GoBtn.Add_Click({
    $GoBtn.IsEnabled = $false
    Set-Output-Textbox($cred)
    $GoBtn.IsEnabled = $true
})
$UnlockBtn.Add_Click({
    $UnlockBtn.IsEnabled = $false
    $msgTitle = "Confirm Unlock"
    $msgButton = 'YesNoCancel'
    $msgImage = 'Question'
    $msgBody = "Are you sure you want to unlock " + $TargetUserTxt.Text + "?"
    $Result = [System.Windows.MessageBox]::Show($msgBody,$msgTitle,$msgButton,$msgImage)
    if ($Result.value__ -eq "6") {
        Unlock-Target-User($cred)
    }
    else {
        Write-Host "No changes were made."
    }
    $UnlockBtn.IsEnabled = $true
})
$ClearBtn.Add_Click({
    $ClearBtn.IsEnabled = $false
    Clear-Output-Textbox
    $ClearBtn.IsEnabled = $true
})
$TargetUserTxt.Add_KeyDown({
    if ($_.Key -eq "Enter"){
        $GoBtn.IsEnabled = $false
        Set-Output-Textbox($cred)
        $GoBtn.IsEnabled = $true
    }
})
#endregion 

# Show our window
[void]$Window.ShowDialog()