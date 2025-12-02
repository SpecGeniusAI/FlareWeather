/**
 * Dark Mode Toggle Component
 */
export function ThemeToggle() {
    const toggleDarkMode = () => {
        const html = document.documentElement;
        const isDark = html.classList.contains('dark');
        
        if (isDark) {
            html.classList.remove('dark');
            localStorage.setItem('theme', 'light');
        } else {
            html.classList.add('dark');
            localStorage.setItem('theme', 'dark');
        }
    };
    
    // Check localStorage on load
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme === 'dark' || (!savedTheme && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
        document.documentElement.classList.add('dark');
    }
    
    return `
        <button
            onclick="(${toggleDarkMode.toString()})()"
            class="p-2 rounded-lg hover:bg-alt-bg/20 transition-colors duration-200"
            aria-label="Toggle dark mode"
        >
            <span class="text-2xl dark:hidden">🌙</span>
            <span class="text-2xl hidden dark:inline">☀️</span>
        </button>
    `;
}

