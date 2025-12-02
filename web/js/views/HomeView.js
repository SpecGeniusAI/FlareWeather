import { Card } from '../components/Card.js';
import { ButtonHTML } from '../components/Button.js';

const API_BASE_URL = 'http://localhost:8000';

/**
 * Home View - Main dashboard
 */
export class HomeView {
    constructor() {
        this.weatherData = null;
        this.aiInsights = null;
        this.isLoading = false;
    }

    async fetchWeatherData() {
        // Mock weather data for now - replace with actual API call
        this.weatherData = {
            temperature: 22,
            humidity: 65,
            pressure: 1013,
            windSpeed: 5,
            condition: 'Partly Cloudy'
        };
    }

    async fetchAIInsights() {
        try {
            this.isLoading = true;
            // This would call your /analyze endpoint
            // For now, using mock data
            this.aiInsights = {
                message: "Based on recent patterns, you may experience increased joint pain when barometric pressure drops. Watch for weather changes this week.",
                citations: ["PMC123456", "Weather and Health Study 2024"]
            };
        } catch (error) {
            console.error('Error fetching insights:', error);
        } finally {
            this.isLoading = false;
        }
    }

    render() {
        return `
            <div class="max-w-screen-md mx-auto px-4 py-6 space-y-6">
                <!-- Weather Card -->
                ${Card({
                    title: 'Current Weather',
                    icon: '☀️',
                    content: `
                        ${this.weatherData ? `
                            <div class="space-y-4">
                                <div class="flex items-baseline gap-2">
                                    <span class="text-5xl font-light">${this.weatherData.temperature}°</span>
                                    <span class="text-xl text-muted">C</span>
                                </div>
                                <p class="text-xl font-semibold">${this.weatherData.condition}</p>
                                <div class="grid grid-cols-3 gap-4 pt-4 border-t border-muted/20">
                                    <div>
                                        <p class="text-sm text-muted">Humidity</p>
                                        <p class="text-lg font-medium">${this.weatherData.humidity}%</p>
                                    </div>
                                    <div>
                                        <p class="text-sm text-muted">Pressure</p>
                                        <p class="text-lg font-medium">${this.weatherData.pressure}hPa</p>
                                    </div>
                                    <div>
                                        <p class="text-sm text-muted">Wind</p>
                                        <p class="text-lg font-medium">${this.weatherData.windSpeed}km/h</p>
                                    </div>
                                </div>
                            </div>
                        ` : `
                            <div class="text-center py-8 text-muted">
                                <p>Loading weather data...</p>
                            </div>
                        `}
                    `
                })}

                <!-- Weekly Forecast Card -->
                ${Card({
                    title: 'Weekly Forecast',
                    icon: '📅',
                    content: `
                        <div class="space-y-4">
                            ${this.isLoading ? `
                                <div class="text-center py-8">
                                    <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-black dark:border-dark-text"></div>
                                    <p class="mt-4 text-muted">Analyzing your week...</p>
                                </div>
                            ` : this.aiInsights ? `
                                <div class="space-y-4">
                                    <p class="leading-relaxed">${this.aiInsights.message}</p>
                                    ${this.aiInsights.citations && this.aiInsights.citations.length > 0 ? `
                                        <div class="pt-4 border-t border-muted/20">
                                            <p class="text-sm font-semibold mb-2 text-muted">Research Sources</p>
                                            <ul class="space-y-1 text-sm text-muted">
                                                ${this.aiInsights.citations.map(citation => `
                                                    <li class="flex items-start gap-2">
                                                        <span>•</span>
                                                        <span>${citation}</span>
                                                    </li>
                                                `).join('')}
                                            </ul>
                                        </div>
                                    ` : ''}
                                </div>
                            ` : `
                                <div class="text-center py-8 text-muted">
                                    <p>No insights available yet. Start tracking your symptoms to get personalized forecasts.</p>
                                </div>
                            `}
                        </div>
                    `
                })}

                <!-- Quick Actions -->
                ${Card({
                    title: 'Quick Actions',
                    icon: '⚡',
                    content: `
                        <div class="flex flex-col gap-3">
                            ${ButtonHTML({
                                text: 'Log New Symptom',
                                onClick: () => { window.location.hash = '#log'; },
                                variant: 'primary'
                            })}
                            ${ButtonHTML({
                                text: 'View Trends',
                                onClick: () => { alert('Trends view coming soon!'); },
                                variant: 'secondary'
                            })}
                        </div>
                    `
                })}
            </div>
        `;
    }

    async mount(container) {
        await this.fetchWeatherData();
        await this.fetchAIInsights();
        container.innerHTML = this.render();
    }
}
