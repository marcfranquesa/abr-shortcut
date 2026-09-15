property requestReason : "Update/install applications"

on run
    try
        tell application "System Events"
            if not UI elements enabled then error "Enable Accessibility for Enable Admin in System Settings > Privacy & Security > Accessibility, then launch it again."
        end tell
        do shell script "/usr/bin/open -b com.fasttracksoftware.adminbyrequest 'adminbyrequest://request-admin'"
        set expiresAt to (current date) + 25
        set submittedReason to false
        repeat while (current date) < expiresAt
            tell application "System Events"
                if exists process "Admin By Request" then
                    tell process "Admin By Request"
                        if exists window "Administrator Access" then
                            if exists button "Finish" of window "Administrator Access" then
                                set value of attribute "AXMinimized" of window "Administrator Access" to true
                                return
                            end if
                        end if
                        if exists window "Instructions" then
                            tell window "Instructions"
                                -- Only acknowledge the exact prompts observed on this Mac.
                                if exists static text "Do you want to start an administrator session?" then
                                    if exists button "Yes" then click button "Yes"
                                else if exists static text "Your request for temporary administrator permission has been approved. After clicking OK, you will become administrator on your computer for a limited time, and a small countdown window will appear on the lower right side of your screen.

Please note that during the admin session, actions will be logged in the BITS system. Activity should be consistent with the Broad IT Acceptable Use policy (broad.io/AcceptableUse). If you have questions or concerns about this, please cancel this request and reach out to BITS (broad.io/help)." then
                                    if exists button "OK" then click button "OK"
                                end if
                            end tell
                        else if exists window "Request Administrator Access" then
                            if not submittedReason then
                                set frontmost to true
                                tell window "Request Administrator Access"
                                    if (count of text fields) is 1 then
                                        set focused of text field 1 to true
                                        keystroke "a" using command down
                                        keystroke requestReason
                                        if exists button "OK" then
                                            if enabled of button "OK" then
                                                click button "OK"
                                                set submittedReason to true
                                            end if
                                        end if
                                    end if
                                end tell
                            end if
                        end if
                    end tell
                end if
            end tell
            delay 0.25
        end repeat
        display dialog "The admin session has not started yet. Check Admin By Request for authentication, approval, or another prompt." buttons {"OK"} default button "OK" with title "Enable Admin"
    on error errorMessage number errorNumber
        if errorNumber is not -128 then
            display dialog "Enable Admin could not finish.\n\n" & errorMessage buttons {"OK"} default button "OK" with title "Enable Admin"
        end if
    end try
end run
