/**
 * Card/Section Container Component
 * @param {Object} props
 * @param {string} props.title - Card title (optional)
 * @param {string} props.icon - Icon symbol/emoji (optional)
 * @param {string} props.content - Card content HTML
 * @param {string} props.className - Additional classes
 */
export function Card({ title, icon, content, className = '' }) {
    return `
        <div class="bg-alt-bg rounded-xl p-6 shadow-sm ${className}">
            ${title || icon ? `
                <div class="flex items-center gap-3 mb-4">
                    ${icon ? `<span class="text-2xl">${icon}</span>` : ''}
                    ${title ? `<h3 class="text-lg font-semibold text-black dark:text-dark-text">${title}</h3>` : ''}
                </div>
            ` : ''}
            <div class="text-black dark:text-dark-text">
                ${content}
            </div>
        </div>
    `;
}

