# Quick Start Guide

## Running the Web Frontend

1. **Navigate to the web directory:**
   ```bash
   cd web
   ```

2. **Start a local server:**
   
   Using Python (recommended):
   ```bash
   python3 -m http.server 3000
   ```
   
   Or using Node.js:
   ```bash
   npx http-server -p 3000
   ```

3. **Open in browser:**
   ```
   http://localhost:3000
   ```

## Features

- ✅ Dark mode toggle (top right in nav)
- ✅ Responsive design
- ✅ Client-side routing (#home, #log, #settings)
- ✅ Component-based architecture
- ✅ Tailwind CSS styling matching design system

## Design System

- **Primary Background**: `#F1F1EF`
- **Alt Background (Cards)**: `#E7D6CA`
- **Dark Mode Background**: `#000000`
- **Dark Mode Text**: `#F1F1EF`
- **Muted Text/Icons**: `#888576`

## Next Steps

1. Connect to backend API (update `API_BASE_URL` in `js/views/HomeView.js`)
2. Implement actual API calls for weather and symptoms
3. Add form validation
4. Add error handling

