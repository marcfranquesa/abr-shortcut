on run
    try
        tell application "System Events"
            if not UI elements enabled then error "Enable Accessibility for Stop Admin in System Settings > Privacy & Security > Accessibility, then launch it again."
        end tell
        set expiresAt to (current date) + 20
        set clickedFinish to false
        repeat while (current date) < expiresAt
            tell application "System Events"
                if not (exists process "Admin By Request") then return
                tell process "Admin By Request"
                    if exists window "Instructions" then
                        tell window "Instructions"
                            if exists static text "Are you done with your administrator session?" then
                                if exists button "Yes" then click button "Yes"
                            else if exists static text "Do you want to start an administrator session?" then
                                return
                            else
                                error "An unexpected Admin By Request prompt is open. Check it to finish stopping the session."
                            end if
                        end tell
                    else if exists window "Administrator Access" then
                        if not clickedFinish then
                            tell window "Administrator Access"
                                if exists button "Finish" then
                                    set value of attribute "AXMinimized" to false
                                    click button "Finish"
                                    set clickedFinish to true
                                end if
                            end tell
                        end if
                    else
                        return
                    end if
                end tell
            end tell
            delay 0.25
        end repeat
        error "The session timer has not closed. Check Admin By Request to confirm the session ended."
    on error errorMessage number errorNumber
        if errorNumber is not -128 then display dialog errorMessage buttons {"OK"} default button "OK" with title "Stop Admin"
    end try
end run
