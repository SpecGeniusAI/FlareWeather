/**
 * Navigation Component
 * @param {Object} props
 * @param {Array} props.items - Navigation items [{ label, href, active }]
 */
export function Nav({ items = [] }) {
    return `
        <nav class="bg-alt-bg border-b border-muted/20 shadow-sm">
            <div class="max-w-screen-md mx-auto px-4 py-4">
                <div class="flex items-center justify-between">
                    <div class="flex items-center gap-2">
                        <span class="text-2xl">🌤️</span>
                        <h1 class="text-xl font-bold text-black dark:text-dark-text">FlareWeather</h1>
                    </div>
                    <div class="flex items-center gap-4">
                        ${items.map(item => `
                            <a 
                                href="${item.href || '#'}" 
                                class="px-4 py-2 rounded-lg font-medium transition-colors duration-200 ${
                                    item.active 
                                        ? 'bg-primary-bg dark:bg-dark-bg text-black dark:text-dark-text' 
                                        : 'text-muted hover:text-black dark:hover:text-dark-text hover:bg-primary-bg/50'
                                }"
                            >
                                ${item.label}
                            </a>
                        `).join('')}
                        <div id="theme-toggle-container"></div>
                    </div>
                </div>
            </div>
        </nav>
    `;
}

