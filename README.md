This repo contains the SQL schema (DDL), data loading scripts, demo queries, and a web application for our midterm report.

## Quick Start

### Option 1: Run SQL Demo Only (PHASE 2)

Clone the repository and run the following command to reproduce the Phase 2 demo:

```bash
psql -d "$USER" -v ON_ERROR_STOP=1 \
  -f demo/phase2_demo.sql \
  -o report/phase2_output.txt
```

### Option 2: Run Full Web Application (PHASE 3)

#### Prerequisites

- PostgreSQL installed and running
- Python 3.8+ installed
- `pip` package manager

#### Step 1: Set up the Database

First, ensure PostgreSQL is running. Then create the database schema and load the data:

```bash
# Navigate to the project directory
cd /path/to/cse412-music-db

# Create the database schema (tables, indexes, etc.)
psql -d "$USER" -f db/ddl.sql

# Load the CSV data into the database (this may take a minute)
psql -d "$USER" -f db/copy_load.sql

# Add demo users and sample data
psql -d "$USER" -f db/seed_minimal.sql
```

**Note:** If your database name is different from your username, replace `"$USER"` with your actual database name (e.g., `psql -d mydb -f db/ddl.sql`).

#### Step 2: Install Python Dependencies

```bash
pip install -r requirements.txt
```

Or if you're using a virtual environment (recommended):

```bash
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

#### Step 3: Configure Database Connection (Optional)

The server uses these defaults:
- Host: `localhost`
- Port: `5432`
- Database: Your username (from `$USER` environment variable)
- User: Your username

To override these defaults, set environment variables (for example, if you need to switch to port 8888):

```bash
export DB_HOST=localhost
export DB_PORT=8888
export DB_NAME=mydb
export DB_USER=myuser
```

#### Step 4: Start the Backend Server

```bash
python3 server.py
```

The server will start on `http://localhost:5001` (port 5001 to avoid conflicts with macOS AirPlay).

**Note:** If port 5001 is also in use, you can specify a different port:
```bash
PORT=8000 python3 server.py
```

#### Step 5: Open in Browser

Navigate to **http://localhost:5001** (or the port you specified) and log in with one of the demo users:
- `cole`
- `svar`
- `mohsin`
- `nassim`

## Features

- **Search Songs**: Search by song title or artist name with relevance-based sorting
- **Rate Songs**: Rate songs from 1-5 stars with optional comments
- **Manage Playlists**: Create, rename, and delete playlists
- **Add Songs to Playlists**: Add songs from search results to your playlists
- **View Playlist Songs**: See all songs in your playlists and remove them

## Project Structure

- `db/` - Database schema and data loading scripts
  - `ddl.sql` - Creates all tables and indexes
  - `copy_load.sql` - Loads data from CSV (loads ~237k songs)
  - `seed_minimal.sql` - Adds demo users and sample playlists/ratings
- `static/` - Frontend web application
  - `index.html` - Main UI
  - `app.js` - Frontend JavaScript
- `demo/` - SQL demo scripts
  - `phase2_demo.sql` - Demonstrates all Phase 2 requirements
- `server.py` - Flask backend server (handles all API endpoints)
- `requirements.txt` - Python dependencies
- `light_spotify_dataset.csv` - Source data file

## Troubleshooting

### Database Connection Issues

If you get connection errors, check:
1. PostgreSQL is running: `pg_isready` or `psql -l`
2. Database exists: `psql -l` should show your database
3. Connection settings match your PostgreSQL setup

### Port Already in Use

If port 5001 is in use, either:
- Stop the other service using that port
- Use a different port: `PORT=8000 python3 server.py`

### Import Errors

If you get import errors for Flask or psycopg:
- Make sure you're in a virtual environment (if using one)
- Reinstall dependencies: `pip install -r requirements.txt --force-reinstall`
