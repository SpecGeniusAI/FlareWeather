import { createElement } from '../utils/render.js';

/**
 * Primary Button Component
 */
export function Button({ text, onClick, variant = 'primary', disabled = false, className = '' }) {
    const baseClasses = 'px-6 py-3 rounded-xl font-medium transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed';
    
    const variantClasses = {
        primary: 'bg-alt-bg text-black hover:opacity-90 active:opacity-75 shadow-sm',
        secondary: 'border-2 border-muted text-black dark:text-dark-text hover:bg-alt-bg/20 active:opacity-75'
    };
    
    const classes = `${baseClasses} ${variantClasses[variant]} ${className}`;
    
    const button = createElement('button', {
        className: classes,
        onClick: onClick,
        disabled: disabled
    }, [text]);
    
    return button;
}

/**
 * Render button as HTML string (for template usage)
 */
export function ButtonHTML({ text, onClick, variant = 'primary', disabled = false, type = 'button', className = '', id = '' }) {
    const baseClasses = 'px-6 py-3 rounded-xl font-medium transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed';
    
    const variantClasses = {
        primary: 'bg-alt-bg text-black hover:opacity-90 active:opacity-75 shadow-sm',
        secondary: 'border-2 border-muted text-black dark:text-dark-text hover:bg-alt-bg/20 active:opacity-75'
    };
    
    const classes = `${baseClasses} ${variantClasses[variant]} ${className}`;
    const buttonId = id || `btn-${Math.random().toString(36).substr(2, 9)}`;
    
    // Store onClick handler globally for HTML string approach
    if (onClick && typeof window !== 'undefined') {
        window[`btnHandler_${buttonId}`] = onClick;
    }
    
    return `
        <button 
            id="${buttonId}"
            type="${type}"
            class="${classes}"
            ${disabled ? 'disabled' : ''}
            ${onClick ? `onclick="window.btnHandler_${buttonId}(event)"` : ''}
        >
            ${text}
        </button>
    `;
}
