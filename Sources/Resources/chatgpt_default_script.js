(function() {
    const loginDomains = ["auth.openai.com", "accounts.google.com", "login.microsoftonline.com"];
    if (loginDomains.some(d => window.location.hostname.includes(d))) return;

    function manageSidebar() {
        const closeSelectors = [
            'button[aria-label*="关闭"]',
            'button[aria-label*="Close"]',
            'button[data-testid*="close"]',
            '[data-testid="zoom-out-button"]'
        ];
        
        let clicked = false;
        closeSelectors.forEach(sel => {
            document.querySelectorAll(sel).forEach(btn => {
                if (btn.offsetParent !== null && !clicked) { 
                    btn.click();
                    clicked = true;
                }
            });
        });

        const hideSelectors = [
            'button[aria-label*="打开"]',
            'button[aria-label*="Open"]',
            'button[data-testid*="open"]',
            '[data-testid="zoom-in-button"]',
            '[data-state="closed"] > button',
            '[data-testid="sidebar-item-library"]',
            'a[href*="/library"]',
            '#stage-sidebar-tiny-bar',
            '.group\\/tiny-bar'
        ];

        hideSelectors.forEach(sel => {
            document.querySelectorAll(sel).forEach(el => {
                if (el.style.display !== 'none') {
                    el.style.setProperty('display', 'none', 'important');
                    el.style.setProperty('width', '0', 'important');
                    el.style.setProperty('visibility', 'hidden', 'important');
                    el.style.setProperty('opacity', '0', 'important');
                    el.style.setProperty('pointer-events', 'none', 'important');
                }
            });
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', manageSidebar);
    } else {
        manageSidebar();
    }

    setInterval(manageSidebar, 500);
    
    const observer = new MutationObserver(() => manageSidebar());
    if (document.body) observer.observe(document.body, { childList: true, subtree: true });
})();
