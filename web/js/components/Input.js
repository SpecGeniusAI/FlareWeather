import { createElement } from '../utils/render.js';

/**
 * Input Field Component (DOM Element)
 */
export function Input({ label, type = 'text', placeholder = '', value = '', onChange, className = '' }) {
    const container = createElement('div', { className: `flex flex-col gap-2 ${className}` });
    
    if (label) {
        const labelEl = createElement('label', { 
            className: 'text-sm font-medium text-black dark:text-dark-text',
            htmlFor: `input-${Math.random().toString(36).substr(2, 9)}`
        }, [label]);
        container.appendChild(labelEl);
    }
    
    const inputId = `input-${Math.random().toString(36).substr(2, 9)}`;
    const input = createElement('input', {
        id: inputId,
        type: type,
        placeholder: placeholder,
        value: value,
        className: 'px-4 py-3 rounded-xl border border-muted/30 bg-white dark:bg-dark-bg dark:border-muted/50 text-black dark:text-dark-text placeholder:text-muted focus:outline-none focus:ring-2 focus:ring-alt-bg/50 focus:border-alt-bg shadow-sm transition-all duration-200',
        onChange: onChange
    });
    
    if (label) {
        input.setAttribute('id', inputId);
        const labelEl = container.querySelector('label');
        if (labelEl) labelEl.setAttribute('for', inputId);
    }
    
    container.appendChild(input);
    return container;
}

/**
 * Input Field Component (HTML String)
 */
export function InputHTML({ label, type = 'text', placeholder = '', value = '', name = '', required = false, onChange, className = '', id = '' }) {
    const inputId = id || `input-${Math.random().toString(36).substr(2, 9)}`;
    
    // Store onChange handler globally for HTML string approach
    if (onChange && typeof window !== 'undefined') {
        window[`inputHandler_${inputId}`] = onChange;
    }
    
    return `
        <div class="flex flex-col gap-2 ${className}">
            ${label ? `<label for="${inputId}" class="text-sm font-medium text-black dark:text-dark-text">${label}</label>` : ''}
            <input
                id="${inputId}"
                type="${type}"
                name="${name || inputId}"
                placeholder="${placeholder}"
                value="${value}"
                ${required ? 'required' : ''}
                ${onChange ? `onchange="window.inputHandler_${inputId}(event)"` : ''}
                class="px-4 py-3 rounded-xl border border-muted/30 bg-white dark:bg-dark-bg dark:border-muted/50 text-black dark:text-dark-text placeholder:text-muted focus:outline-none focus:ring-2 focus:ring-alt-bg/50 focus:border-alt-bg shadow-sm transition-all duration-200"
            />
        </div>
    `;
}
