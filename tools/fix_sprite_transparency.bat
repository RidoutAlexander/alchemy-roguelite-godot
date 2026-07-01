@echo off
cd /d "%~dp0.."
py -3 tools\fix_sprite_transparency.py
if errorlevel 1 pause