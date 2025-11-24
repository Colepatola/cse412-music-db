#!/usr/bin/env python3
"""
Backend server for Music DB App
Handles API endpoints and serves static files
"""

from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import psycopg
from psycopg import rows, errors
import os
from urllib.parse import unquote

app = Flask(__name__, static_folder='static')
CORS(app)  # Enable CORS for all routes

# Database connection configuration
# Can be overridden with environment variables
# Default: use standard PostgreSQL connection (localhost, default port)
# Note: psycopg v3 uses 'dbname' instead of 'database'
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', '5432'),
    'dbname': os.getenv('DB_NAME', os.getenv('USER', 'postgres')),
    'user': os.getenv('DB_USER', os.getenv('USER', 'postgres'))
}

def get_db_connection():
    """Create and return a database connection"""
    try:
        conn = psycopg.connect(**DB_CONFIG)
        # Set search path to music schema
        with conn.cursor() as cur:
            cur.execute("SET search_path TO music")
        conn.commit()
        return conn
    except psycopg.Error as e:
        print(f"Database connection error: {e}")
        raise

@app.route('/')
def index():
    """Serve the main HTML file"""
    return send_from_directory('static', 'index.html')

@app.route('/<path:path>')
def serve_static(path):
    """Serve static files (CSS, JS, etc.)"""
    return send_from_directory('static', path)

@app.route('/api/login', methods=['POST'])
def login():
    """Handle user login - checks if username exists"""
    try:
        data = request.get_json()
        username = data.get('username', '').strip()  # Strip whitespace
        
        if not username:
            return jsonify({'error': 'Username required'}), 400
        
        conn = get_db_connection()
        cur = conn.cursor(row_factory=rows.dict_row)
        
        cur.execute(
            "SELECT user_id, username FROM music.users WHERE username = %s",
            (username,)
        )
        user = cur.fetchone()
        
        cur.close()
        conn.close()
        
        if user:
            return jsonify({
                'user_id': user['user_id'],
                'username': user['username']
            })
        else:
            # Debug: log the query attempt
            print(f"Login attempt failed for username: '{username}'")
            return jsonify({'error': 'User not found'}), 404
            
    except Exception as e:
        print(f"Login error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/songs', methods=['GET'])
def search_songs():
    """Search for songs by title or artist name"""
    try:
        query = request.args.get('q', '').strip()
        
        if not query:
            return jsonify([])
        
        conn = get_db_connection()
        cur = conn.cursor(row_factory=rows.dict_row)
        
        # Search in song titles and artist names with relevance scoring
        search_pattern = f'%{query}%'
        exact_pattern = query.lower()
        cur.execute("""
            SELECT DISTINCT 
                s.song_id,
                s.title,
                s.release_year,
                COALESCE(
                    STRING_AGG(DISTINCT a.artist_name, ', ' ORDER BY a.artist_name),
                    'Unknown'
                ) AS artist_name,
                -- Relevance scoring: exact matches first, then title matches, then artist matches
                CASE 
                    WHEN LOWER(s.title) = %s THEN 1
                    WHEN LOWER(s.title) LIKE %s THEN 2
                    WHEN EXISTS (
                        SELECT 1 FROM music.song_artists sa2 
                        JOIN music.artists a2 ON sa2.artist_id = a2.artist_id 
                        WHERE sa2.song_id = s.song_id AND LOWER(a2.artist_name) = %s
                    ) THEN 3
                    WHEN EXISTS (
                        SELECT 1 FROM music.song_artists sa2 
                        JOIN music.artists a2 ON sa2.artist_id = a2.artist_id 
                        WHERE sa2.song_id = s.song_id AND LOWER(a2.artist_name) LIKE %s
                    ) THEN 4
                    ELSE 5
                END AS relevance
            FROM music.songs s
            LEFT JOIN music.song_artists sa ON s.song_id = sa.song_id
            LEFT JOIN music.artists a ON sa.artist_id = a.artist_id
            WHERE s.title ILIKE %s OR a.artist_name ILIKE %s
            GROUP BY s.song_id, s.title, s.release_year
            ORDER BY relevance, s.title
            LIMIT 100
        """, (exact_pattern, f'{exact_pattern}%', exact_pattern, search_pattern, search_pattern, search_pattern))
        
        songs = cur.fetchall()
        cur.close()
        conn.close()
        
        # Convert to list of dicts
        result = [dict(song) for song in songs]
        return jsonify(result)
        
    except Exception as e:
        print(f"Search error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/ratings', methods=['POST'])
def create_rating():
    """Create a new rating for a song"""
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        song_id = data.get('song_id')
        stars = data.get('stars')
        comment = data.get('comment', '')
        
        if not all([user_id, song_id, stars]):
            return jsonify({'error': 'Missing required fields'}), 400
        
        if not (1 <= stars <= 5):
            return jsonify({'error': 'Stars must be between 1 and 5'}), 400
        
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Use INSERT ... ON CONFLICT to update if rating already exists
        cur.execute("""
            INSERT INTO music.ratings (user_id, song_id, stars, comment)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (user_id, song_id)
            DO UPDATE SET stars = %s, comment = %s, created_at = now()
        """, (user_id, song_id, stars, comment, stars, comment))
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'success': True}), 201
        
    except errors.IntegrityError as e:
        return jsonify({'error': 'Invalid user_id or song_id'}), 400
    except Exception as e:
        print(f"Rating error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/playlists', methods=['GET'])
def get_playlists():
    """Get all playlists for a user"""
    try:
        user_id = request.args.get('user_id')
        
        if not user_id:
            return jsonify({'error': 'user_id required'}), 400
        
        conn = get_db_connection()
        cur = conn.cursor(row_factory=rows.dict_row)
        
        cur.execute("""
            SELECT playlist_id, owner_id, name, is_public, created_at
            FROM music.playlists
            WHERE owner_id = %s
            ORDER BY created_at DESC
        """, (user_id,))
        
        playlists = cur.fetchall()
        cur.close()
        conn.close()
        
        result = [dict(pl) for pl in playlists]
        return jsonify(result)
        
    except Exception as e:
        print(f"Get playlists error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/playlists', methods=['POST'])
def create_playlist():
    """Create a new playlist"""
    try:
        data = request.get_json()
        owner_id = data.get('owner_id')
        name = data.get('name')
        is_public = data.get('is_public', True)
        
        if not all([owner_id, name]):
            return jsonify({'error': 'Missing required fields'}), 400
        
        conn = get_db_connection()
        cur = conn.cursor(row_factory=rows.dict_row)
        
        cur.execute("""
            INSERT INTO music.playlists (owner_id, name, is_public)
            VALUES (%s, %s, %s)
            RETURNING playlist_id, owner_id, name, is_public, created_at
        """, (owner_id, name, is_public))
        
        playlist = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify(dict(playlist)), 201
        
    except errors.IntegrityError as e:
        return jsonify({'error': 'Invalid owner_id'}), 400
    except Exception as e:
        print(f"Create playlist error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/playlists/<int:playlist_id>', methods=['PUT'])
def update_playlist(playlist_id):
    """Update a playlist (currently only name)"""
    try:
        data = request.get_json()
        name = data.get('name')
        
        if not name:
            return jsonify({'error': 'Name required'}), 400
        
        conn = get_db_connection()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE music.playlists
            SET name = %s
            WHERE playlist_id = %s
        """, (name, playlist_id))
        
        if cur.rowcount == 0:
            cur.close()
            conn.close()
            return jsonify({'error': 'Playlist not found'}), 404
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'success': True}), 200
        
    except Exception as e:
        print(f"Update playlist error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/playlists/<int:playlist_id>', methods=['DELETE'])
def delete_playlist(playlist_id):
    """Delete a playlist"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        cur.execute("""
            DELETE FROM music.playlists
            WHERE playlist_id = %s
        """, (playlist_id,))
        
        if cur.rowcount == 0:
            cur.close()
            conn.close()
            return jsonify({'error': 'Playlist not found'}), 404
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'success': True}), 200
        
    except Exception as e:
        print(f"Delete playlist error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/playlists/<int:playlist_id>/songs', methods=['GET'])
def get_playlist_songs(playlist_id):
    """Get all songs in a playlist"""
    try:
        conn = get_db_connection()
        cur = conn.cursor(row_factory=rows.dict_row)
        
        cur.execute("""
            SELECT 
                s.song_id,
                s.title,
                s.release_year,
                COALESCE(
                    STRING_AGG(DISTINCT a.artist_name, ', ' ORDER BY a.artist_name),
                    'Unknown'
                ) AS artist_name,
                ps.position
            FROM music.playlist_songs ps
            JOIN music.songs s ON ps.song_id = s.song_id
            LEFT JOIN music.song_artists sa ON s.song_id = sa.song_id
            LEFT JOIN music.artists a ON sa.artist_id = a.artist_id
            WHERE ps.playlist_id = %s
            GROUP BY s.song_id, s.title, s.release_year, ps.position
            ORDER BY ps.position, s.title
        """, (playlist_id,))
        
        songs = cur.fetchall()
        cur.close()
        conn.close()
        
        result = [dict(song) for song in songs]
        return jsonify(result)
        
    except Exception as e:
        print(f"Get playlist songs error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/playlists/<int:playlist_id>/songs', methods=['POST'])
def add_song_to_playlist(playlist_id):
    """Add a song to a playlist"""
    try:
        data = request.get_json()
        song_id = data.get('song_id')
        
        if not song_id:
            return jsonify({'error': 'song_id required'}), 400
        
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Get the next position in the playlist
        cur.execute("""
            SELECT COALESCE(MAX(position), 0) + 1 AS next_position
            FROM music.playlist_songs
            WHERE playlist_id = %s
        """, (playlist_id,))
        next_position = cur.fetchone()[0]
        
        # Insert the song
        cur.execute("""
            INSERT INTO music.playlist_songs (playlist_id, song_id, position)
            VALUES (%s, %s, %s)
            ON CONFLICT (playlist_id, song_id) DO NOTHING
        """, (playlist_id, song_id, next_position))
        
        if cur.rowcount == 0:
            cur.close()
            conn.close()
            return jsonify({'error': 'Song already in playlist or invalid playlist/song'}), 400
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'success': True}), 201
        
    except errors.IntegrityError as e:
        return jsonify({'error': 'Invalid playlist_id or song_id'}), 400
    except Exception as e:
        print(f"Add song to playlist error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/playlists/<int:playlist_id>/songs/<int:song_id>', methods=['DELETE'])
def remove_song_from_playlist(playlist_id, song_id):
    """Remove a song from a playlist"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        cur.execute("""
            DELETE FROM music.playlist_songs
            WHERE playlist_id = %s AND song_id = %s
        """, (playlist_id, song_id))
        
        if cur.rowcount == 0:
            cur.close()
            conn.close()
            return jsonify({'error': 'Song not found in playlist'}), 404
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'success': True}), 200
        
    except Exception as e:
        print(f"Remove song from playlist error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5001))
    print("Starting Music DB App server...")
    print(f"Database config: {DB_CONFIG}")
    print(f"Server running at http://localhost:{port}")
    app.run(debug=True, host='0.0.0.0', port=port)

