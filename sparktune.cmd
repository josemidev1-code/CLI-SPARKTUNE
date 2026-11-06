@echo off
rem SparkTune wrapper para CMD - by @josemidev1
chcp 65001 >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sparktune.ps1" %*
