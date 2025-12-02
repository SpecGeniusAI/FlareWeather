/**
 * Simple rendering utility for components
 */
export function renderComponent(component, container) {
    if (typeof component === 'string') {
        container.innerHTML = component;
    } else if (component instanceof HTMLElement) {
        container.innerHTML = '';
        container.appendChild(component);
    } else if (component && component.render) {
        container.innerHTML = component.render();
        if (component.mount) {
            component.mount(container);
        }
    }
}

export function createElement(tag, props = {}, children = []) {
    const element = document.createElement(tag);
    
    Object.keys(props).forEach(key => {
        if (key === 'className') {
            element.className = props[key];
        } else if (key === 'onClick') {
            element.addEventListener('click', props[key]);
        } else if (key === 'onChange') {
            element.addEventListener('change', props[key]);
        } else if (key.startsWith('on')) {
            const eventName = key.slice(2).toLowerCase();
            element.addEventListener(eventName, props[key]);
        } else {
            element.setAttribute(key, props[key]);
        }
    });
    
    children.forEach(child => {
        if (typeof child === 'string') {
            element.appendChild(document.createTextNode(child));
        } else if (child instanceof HTMLElement) {
            element.appendChild(child);
        }
    });
    
    return element;
}

