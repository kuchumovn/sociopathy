@echo off
title node.js
rem use utf-8 encoding in console output:
chcp 65001
rem call coffee.cmd "code/web/main.coffee"
rem make this directory current
rem cd /d "%~dp0"
rem  --project_directory ".."
node "d:/work/node-js-development-mode/node-js-development-mode.js" --main-file d:/work/sociopathy/code/web/main.coffee --coffee-script "node_modules/coffee-script/bin/coffee" --watch "['code/**/*.js', 'code/**/*.coffee', 'plugins/**/*.coffee']" --options "{ \"server\": \"home_windows\" }"
pause