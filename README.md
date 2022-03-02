# ADToolbox
A Toolbox for performing Active Directory tasks with a user interface. 

<h2>How does it work?</h2>
The project relies on Microsoft's Active Directory module to perform AD tasks and XAML for the GUI. For user authentication, the native Powershell Credentials object is used to ensure security. The program prompts for user credentials, authenticates, then allows the user to input a target to perform tasks on. Currently, the program can only get user account information and unlock the user. 

<h2>Who could use this project?</h2>
The project was intended to be used by IT Support and other System Admins as an alternative to ADUC for simple AD tasks. 

<h2>How can I use this project?</h2>
First, update any variables such as the ADServer variable so that it matches your enviornment. Then, I would recommend compiling the script as an exe and utilizing a "no console" feature to avoid displaying any powershell windows to the end user. I personally use ps2exe with the "-noconsole" command. Note: other changes may need to be made depending on the way your organizaiton names AD users, stores their properties, etc.
