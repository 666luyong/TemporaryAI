(function() {
    const loginDomains = ["accounts.google.com"];
    if (loginDomains.some(d => window.location.hostname.includes(d))) return;

    window.__geminiConfirmedTemp = window.__geminiConfirmedTemp || false;
    
    // --- DEBUG HUD ---
    const debugEnabled = window.__ENABLE_DEBUG_HUD === true;
    let hud = document.getElementById('gemini-debug-hud');
    
    if (debugEnabled && !hud) {
        hud = document.createElement('div');
        hud.id = 'gemini-debug-hud';
        hud.style.cssText = 'position: fixed; top: 10px; right: 10px; z-index: 999999; background: rgba(200,200,200,0.9); color: white; font-family: monospace; font-size: 12px; padding: 10px; border-radius: 5px; pointer-events: none; white-space: pre;';
        document.body.appendChild(hud);
    } else if (!debugEnabled && hud) {
        hud.remove();
        hud = null;
    }
    
    function updateHUD(status) {
        if (hud) hud.textContent = status;
    }
    // ----------------

    // --- CSS Injection to Hide Elements (No Flash) ---
    // We remove 'infinite-scroller' from the global hide list to be safe.
    // We target specific items inside it instead.
    const css = `
        /* Hide History Items */
        [data-test-id="conversation"], 
        [data-test-id="actions-menu-button"],
        
        /* Specific Sidebar Elements */
        side-navigation-content .chat-history,
        [aria-label="Chat history"],
        [aria-label="历史记录"],
        
        /* Extra Buttons */
        button[aria-label="搜索"],
        [aria-label="我的内容"],
        .library-item-card,
        [aria-label="Gem"],
        button[aria-label="Settings & help"],
        button[aria-label="设置与帮助"],
        [data-test-id="gemini-advanced-button"],
        a[href*="myactivity.google.com"],
        .my-stuff-recents-preview 
        {
            display: none !important;
        }
    `;
    const style = document.createElement('style');
    style.textContent = css;
    document.head.appendChild(style);


    function mainLoop() {
        // No need to call cleanUpSidebar() loop anymore, CSS handles it.

        const tempBtn = document.querySelector('[data-test-id="temp-chat-button"]');
        const menuBtn = document.querySelector('button[data-test-id="side-nav-menu-button"]');
        
        // Determine if the sidebar is open by checking if the Temp Chat button is visible
        const isSidebarOpen = tempBtn && tempBtn.offsetParent !== null;

        let action = "Idle";
        let isTempOn = false;
        
        if (tempBtn) {
             isTempOn = tempBtn.classList.contains('temp-chat-on');
        }

        if (isSidebarOpen) {
            // --- Case A: Sidebar is Open ---
            if (!isTempOn) {
                action = "Clicking Temp Chat (Enable)";
                console.log("GeminiScript: Sidebar Open -> Activating Temporary Chat.");
                tempBtn.click();
            } else {
                action = "Temp Chat ON. Collapsing Menu.";
                window.__geminiConfirmedTemp = true; // Mark as confirmed
                
                if (menuBtn) {
                    // Ensure the button is clickable before we try to close the menu
                    menuBtn.style.setProperty('pointer-events', 'auto', 'important');
                    menuBtn.click();
                }
            }
        } else {
            // --- Case B: Sidebar is Closed ---
            if (!window.__geminiConfirmedTemp) {
                // If we haven't confirmed Temp Mode yet, we MUST open the menu to check/set it.
                action = "Status Unknown. Opening Menu.";
                console.log("GeminiScript: Sidebar Closed & Status Unknown -> Opening menu.");
                if (menuBtn) {
                    menuBtn.style.setProperty('pointer-events', 'auto', 'important');
                    menuBtn.click();
                }
            } else {
                // We have confirmed Temp Mode is ON, and the sidebar is now closed.
                action = "Temp Mode ON. Menu Closed. Idle.";
            }
        }

        // 4. Update HUD
        const debugText = `
--- Gemini Script Debug ---
Temp Btn Found:   ${!!tempBtn}
Temp Btn Visible: ${!!(tempBtn && tempBtn.offsetParent !== null)}
Temp Is On:       ${isTempOn}
Sidebar Open:     ${isSidebarOpen}
Confirmed Flag:   ${window.__geminiConfirmedTemp}
ACTION:           ${action}
---------------------------
        `;
        updateHUD(debugText);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', mainLoop);
    } else {
        mainLoop();
    }
    
    // Run periodically
    setInterval(mainLoop, 1000);
})();