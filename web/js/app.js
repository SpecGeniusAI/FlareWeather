import { Nav } from './components/Nav.js';
import { ThemeToggle } from './components/ThemeToggle.js';
import { HomeView } from './views/HomeView.js';
import { LogView } from './views/LogView.js';
import { SettingsView } from './views/SettingsView.js';

/**
 * Main App Router and Shell
 */
class App {
    constructor() {
        this.currentView = 'home';
        this.views = {
            home: new HomeView(),
            log: new LogView(),
            settings: new SettingsView()
        };
    }

    init() {
        this.setupNavigation();
        this.setupTheme();
        this.render();
        this.handleRoute();
    }

    setupNavigation() {
        const navItems = [
            { label: 'Home', href: '#home', active: this.currentView === 'home' },
            { label: 'Log', href: '#log', active: this.currentView === 'log' },
            { label: 'Settings', href: '#settings', active: this.currentView === 'settings' }
        ];

        const navContainer = document.createElement('div');
        navContainer.innerHTML = Nav({ items: navItems });
        document.body.insertBefore(navContainer.firstElementChild, document.getElementById('app'));

        // Add theme toggle
        const themeToggleContainer = document.getElementById('theme-toggle-container');
        if (themeToggleContainer) {
            themeToggleContainer.innerHTML = ThemeToggle();
        }
    }

    setupTheme() {
        const savedTheme = localStorage.getItem('theme');
        if (savedTheme === 'dark' || (!savedTheme && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
            document.documentElement.classList.add('dark');
        }
    }

    handleRoute() {
        window.addEventListener('hashchange', () => {
            const hash = window.location.hash.slice(1) || 'home';
            this.currentView = hash;
            this.render();
        });

        // Initial route
        const hash = window.location.hash.slice(1) || 'home';
        this.currentView = hash;
    }

    async render() {
        const appContainer = document.getElementById('app');
        const view = this.views[this.currentView] || this.views.home;

        if (view.mount) {
            await view.mount(appContainer);
        } else {
            appContainer.innerHTML = '<p>View not found</p>';
        }

        // Update navigation active state
        const navLinks = document.querySelectorAll('nav a');
        navLinks.forEach(link => {
            const href = link.getAttribute('href');
            if (href === `#${this.currentView}`) {
                link.classList.add('bg-primary-bg', 'dark:bg-dark-bg', 'text-black', 'dark:text-dark-text');
                link.classList.remove('text-muted');
            } else {
                link.classList.remove('bg-primary-bg', 'dark:bg-dark-bg', 'text-black', 'dark:text-dark-text');
                link.classList.add('text-muted');
            }
        });
    }
}

// Initialize app when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        new App().init();
    });
} else {
    new App().init();
}

