Option Explicit
Dim shell, fileSystem, appFolder, starter
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")
appFolder = fileSystem.GetParentFolderName(WScript.ScriptFullName)
starter = fileSystem.BuildPath(appFolder, "CyberPW Assistant.exe")
shell.CurrentDirectory = appFolder
shell.Run """" & starter & """", 1, False