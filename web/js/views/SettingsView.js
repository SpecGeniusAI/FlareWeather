import { Card } from '../components/Card.js';
import { Input } from '../components/Input.js';
import { Toggle } from '../components/Toggle.js';
import { Button } from '../components/Button.js';

/**
 * Settings View
 */
export class SettingsView {
    constructor() {
        this.settings = {
            notifications: true,
            weatherAlerts: true,
            locationAccess: true
        };
    }

    render() {
        return `
            <div class="max-w-screen-md mx-auto px-4 py-6 space-y-6">
                ${Card({
                    title: 'Profile',
                    icon: '👤',
                    content: `
                        <div class="space-y-4">
                            ${Input({
                                label: 'Name',
                                placeholder: 'Your name',
                                value: 'User'
                            })}
                            ${Input({
                                label: 'Location',
                                placeholder: 'City, State',
                                value: 'San Francisco, CA'
                            })}
                            ${Input({
                                label: 'Health Diagnosis (Optional)',
                                placeholder: 'e.g., Arthritis, Migraine',
                                value: ''
                            })}
                            ${Button({
                                text: 'Save Profile',
                                onClick: () => console.log('Save profile'),
                                variant: 'primary'
                            })}
                        </div>
                    `
                })}

                ${Card({
                    title: 'Preferences',
                    icon: '⚙️',
                    content: `
                        <div class="space-y-4">
                            ${Toggle({
                                label: 'Weather Notifications',
                                checked: this.settings.notifications,
                                onChange: (e) => { this.settings.notifications = !this.settings.notifications; }
                            })}
                            ${Toggle({
                                label: 'Weather Alerts',
                                checked: this.settings.weatherAlerts,
                                onChange: (e) => { this.settings.weatherAlerts = !this.settings.weatherAlerts; }
                            })}
                            ${Toggle({
                                label: 'Location Access',
                                checked: this.settings.locationAccess,
                                onChange: (e) => { this.settings.locationAccess = !this.settings.locationAccess; }
                            })}
                        </div>
                    `
                })}

                ${Card({
                    title: 'About',
                    icon: 'ℹ️',
                    content: `
                        <div class="space-y-2 text-sm">
                            <p><span class="font-medium">Version:</span> 1.0.0</p>
                            <p class="text-muted">FlareWeather helps you track how weather patterns affect your health and forecast your symptoms.</p>
                        </div>
                    `
                })}
            </div>
        `;
    }

    mount(container) {
        container.innerHTML = this.render();
    }
}

