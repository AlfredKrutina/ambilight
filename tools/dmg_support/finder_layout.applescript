-- Finder rozvržení okna DMG (inspirace šablonou create-dmg, MIT licence).
-- Volání: osascript finder_layout.applescript "<basename mountu>" "název.app"

on run argv
	set volumeName to item 1 of argv
	set appName to item 2 of argv
	set theXOrigin to 120
	set theYOrigin to 90
	set theWidth to 1040
	set theHeight to 580
	set theBottomRightX to (theXOrigin + theWidth)
	set theBottomRightY to (theYOrigin + theHeight)
	set dsQuoted to quoted form of ("/Volumes/" & volumeName & "/.DS_Store")

	tell application "Finder"
		tell disk (volumeName as string)
			open
			tell container window
				set current view to icon view
				set toolbar visible to false
				set statusbar visible to false
				set the bounds to {theXOrigin, theYOrigin, theBottomRightX, theBottomRightY}
			end tell

			set opts to the icon view options of container window
			tell opts
				set icon size to 128
				set text size to 13
				set arrangement to not arranged
			end tell
			set background picture of opts to file ".background:dmg_background.png"

			set position of item appName to {220, 340}
			set position of item "Applications" to {740, 340}

			close
			open
			delay 1

			tell container window
				set statusbar visible to false
				set the bounds to {theXOrigin, theYOrigin, (theBottomRightX - 10), (theBottomRightY - 10)}
			end tell
		end tell

		delay 1

		tell disk (volumeName as string)
			tell container window
				set statusbar visible to false
				set the bounds to {theXOrigin, theYOrigin, theBottomRightX, theBottomRightY}
			end tell
		end tell

		delay 3

		set waitTime to 0
		set ejectMe to false
		repeat while ejectMe is false
			delay 1
			set waitTime to waitTime + 1
			try
				if (do shell script "test -f " & dsQuoted & "; echo $?") is "0" then set ejectMe to true
			on error
				if waitTime > 25 then set ejectMe to true
			end try
		end repeat
	end tell
end run
