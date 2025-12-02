/**
 * Toggle Switch Component
 * @param {Object} props
 * @param {string} props.label - Toggle label
 * @param {boolean} props.checked - Checked state
 * @param {Function} props.onChange - Change handler
 * @param {string} props.className - Additional classes
 */
export function Toggle({ label, checked = false, onChange, className = '' }) {
    const toggleId = `toggle-${Math.random().toString(36).substr(2, 9)}`;
    
    return `
        <div class="flex items-center gap-3 ${className}">
            <label for="${toggleId}" class="text-sm font-medium text-black dark:text-dark-text cursor-pointer">
                ${label}
            </label>
            <button
                id="${toggleId}"
                role="switch"
                aria-checked="${checked}"
                onclick="${onChange ? `(${onChange.toString()})(event)` : ''}"
                class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-alt-bg/50 focus:ring-offset-2 ${
                    checked 
                        ? 'bg-alt-bg' 
                        : 'bg-muted/30 dark:bg-muted/20'
                }"
            >
                <span class="inline-block h-4 w-4 transform rounded-full bg-white dark:bg-dark-bg transition-transform duration-200 ${
                    checked ? 'translate-x-6' : 'translate-x-1'
                }"></span>
            </button>
        </div>
    `;
}

