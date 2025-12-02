# FlareWeather Web Frontend

A Tailwind CSS-styled web frontend for FlareWeather, following the design system specifications.

## Design System

### Color Tokens
- `#F1F1EF` → Primary background color
- `#E7D6CA` → Alternate background (cards, panels)
- `#000000` → Dark mode background
- `#F1F1EF` → Dark mode text color
- `#888576` → Muted text, icons, borders

### Typography
- Inter font via Google Fonts
- Large headings, clean labels, good vertical rhythm
- Default text: `#000000` (light) / `#F1F1EF` (dark)

### Components
- **Button**: Primary (bg `#E7D6CA`) and Secondary (bordered)
- **Input**: Labeled fields with subtle shadows
- **Card**: Rounded containers with alt background
- **Toggle**: Switch component for settings
- **ThemeToggle**: Dark mode switcher
- **Nav**: Top navigation with routing

## Setup

1. Serve the files using a local web server:

```bash
# Using Python
cd web
python3 -m http.server 3000

# Using Node.js (if you have http-server)
npx http-server -p 3000

# Using PHP
php -S localhost:3000
```

2. Open `http://localhost:3000` in your browser

3. Update the API endpoint in `js/views/HomeView.js` if your backend is running on a different port

## File Structure

```
web/
├── index.html          # Main HTML file
├── js/
│   ├── app.js         # Main app router and shell
│   ├── components/    # Reusable UI components
│   │   ├── Button.js
│   │   ├── Card.js
│   │   ├── Input.js
│   │   ├── Nav.js
│   │   ├── ThemeToggle.js
│   │   └── Toggle.js
│   └── views/         # Page views
│       ├── HomeView.js
│       ├── LogView.js
│       └── SettingsView.js
└── README.md
```

## Features

- ✅ Dark mode toggle (persists in localStorage)
- ✅ Responsive design (mobile-first)
- ✅ Component-based architecture
- ✅ Client-side routing
- ✅ Tailwind CSS styling
- ✅ Inter font typography
- ✅ Matches design system colors

## Integration with Backend

To connect to your FastAPI backend:

1. Update `API_BASE_URL` in `js/views/HomeView.js`
2. Implement actual API calls in the view classes
3. Handle authentication if needed

## Next Steps

- Add API integration for weather data
- Add API integration for symptom logging
- Add API integration for AI insights
- Add form validation
- Add error handling
- Add loading states

