# Database Information

## User Storage Location

Users are stored in a **SQLite database** file that will be created when the backend server starts.

### Database File Location
- **File**: `flareweather.db`
- **Path**: `/Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001/flareweather.db`
- **Created**: Automatically created when the backend server starts for the first time

### Database Schema
The database contains a `users` table with the following fields:
- `id` (String, Primary Key) - UUID
- `email` (String, Unique) - User's email address
- `hashed_password` (String) - Bcrypt hashed password
- `name` (String, Optional) - User's name
- `created_at` (DateTime) - Account creation timestamp
- `updated_at` (DateTime) - Last update timestamp

### Changing Database Location
To use a different database (e.g., PostgreSQL for production):

1. Set the `DATABASE_URL` environment variable in your `.env` file:
   ```
   DATABASE_URL=postgresql://user:password@localhost/flareweather
   ```

2. Or modify `database.py` to use a different path:
   ```python
   DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./data/flareweather.db")
   ```

### Viewing the Database
You can view the SQLite database using:
- **SQLite CLI**: `sqlite3 flareweather.db`
- **DB Browser for SQLite**: https://sqlitebrowser.org/
- **VS Code Extension**: SQLite Viewer

### Important Notes
- The database file is created automatically when you start the backend server
- Passwords are hashed using bcrypt - never stored in plain text
- The database file is not included in git (should be in `.gitignore`)

