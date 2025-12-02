import { Card } from '../components/Card.js';
import { InputHTML } from '../components/Input.js';
import { ButtonHTML } from '../components/Button.js';

/**
 * Log Symptom View
 */
export class LogView {
    constructor() {
        this.formData = {
            symptomType: '',
            severity: 5,
            notes: ''
        };
    }

    handleSubmit(event) {
        event.preventDefault();
        const formData = new FormData(event.target);
        const data = {
            symptomType: formData.get('symptomType'),
            severity: parseInt(formData.get('severity')),
            notes: formData.get('notes'),
            timestamp: new Date().toISOString()
        };
        
        console.log('Submitting symptom:', data);
        // TODO: Submit to backend API
        alert('Symptom logged successfully!');
        window.location.hash = '#home';
    }

    render() {
        return `
            <div class="max-w-screen-md mx-auto px-4 py-6">
                ${Card({
                    title: 'Log Symptom',
                    icon: '📝',
                    content: `
                        <form id="symptom-form" class="space-y-6" onsubmit="event.preventDefault(); window.logView.handleSubmit(event);">
                            ${InputHTML({
                                label: 'Symptom Type',
                                name: 'symptomType',
                                placeholder: 'e.g., Headache, Joint Pain',
                                required: true
                            })}
                            
                            <div class="flex flex-col gap-2">
                                <label for="severity" class="text-sm font-medium text-black dark:text-dark-text">
                                    Severity: <span id="severity-value">5</span>/10
                                </label>
                                <input
                                    type="range"
                                    id="severity"
                                    name="severity"
                                    min="1"
                                    max="10"
                                    value="5"
                                    oninput="document.getElementById('severity-value').textContent = this.value"
                                    class="w-full h-2 bg-muted/30 rounded-lg appearance-none cursor-pointer accent-alt-bg"
                                    required
                                />
                                <div class="flex justify-between text-xs text-muted">
                                    <span>Mild</span>
                                    <span>Moderate</span>
                                    <span>Severe</span>
                                </div>
                            </div>

                            <div class="flex flex-col gap-2">
                                <label for="notes" class="text-sm font-medium text-black dark:text-dark-text">Notes (Optional)</label>
                                <textarea
                                    id="notes"
                                    name="notes"
                                    placeholder="Add any additional context..."
                                    class="px-4 py-3 rounded-xl border border-muted/30 bg-white dark:bg-dark-bg dark:border-muted/50 text-black dark:text-dark-text placeholder:text-muted focus:outline-none focus:ring-2 focus:ring-alt-bg/50 focus:border-alt-bg shadow-sm transition-all duration-200 resize-none"
                                    rows="4"
                                ></textarea>
                            </div>

                            <div class="flex gap-3 pt-4">
                                ${ButtonHTML({
                                    text: 'Log Symptom',
                                    type: 'submit',
                                    variant: 'primary',
                                    className: 'flex-1'
                                })}
                                ${ButtonHTML({
                                    text: 'Cancel',
                                    onClick: () => { window.location.hash = '#home'; },
                                    variant: 'secondary',
                                    className: 'flex-1'
                                })}
                            </div>
                        </form>
                    `
                })}
            </div>
        `;
    }

    mount(container) {
        container.innerHTML = this.render();
        // Store reference for form handler
        window.logView = this;
    }
}
