@echo off
cd /d "%~dp0.."
py -3 tools\export_ingredients.py
if errorlevel 1 pause