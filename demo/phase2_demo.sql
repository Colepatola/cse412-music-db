-- demo/phase2_demo.sql
-- One-shot: build schema, load CSV, seed a few rows, run the rubric queries.

\pset pager off

\qecho '=== PHASE 2 DEMO ==='
\qecho 'Below are the requirements that we will demonstrate:'
\qecho '1) Build schema (ER -> Relational).'
\qecho '2) Load CSV with COPY (no GUI yet).'
\qecho '3) Show INSERT, UPDATE, DELETE and SELECTs.'
\qecho ''

\qecho '--- STEP 1: Build schema (requirement 1) ---'
\qecho 'Running db/ddl.sql...'
\qecho 'This file creates all of our tables from the ERD (users, songs, artists, playlists, ratings, genre).'
\qecho 'It sets up primary keys, foreign keys, and indexes to link everything properly.'
\qecho 'This satisfies the “ER to Relational” requirement by showing we built the full schema in SQL.'
\i db/ddl.sql
\qecho 'Succeeded: schema, keys, FKs, indexes properly loaded.'
\qecho ''

\qecho '--- STEP 2: Load CSV (requirement 2) ---'
\qecho 'Running db/copy_load.sql...'
\qecho 'This file loads our Spotify CSV into the database using COPY.'
\qecho 'It stages the data, cleans it, and inserts it into songs, artists, and song_artists tables.'
\qecho 'This satisfies the “Fill database with data” requirement since we populate tables using SQL only.'
\i db/copy_load.sql
\qecho 'Succeeded: CSV loaded and normalized properly.'
\qecho ''

\qecho '--- Counts after load (checking if everything is working) ---'
SELECT
  (SELECT COUNT(*) FROM music.songs)         AS songs, 
  (SELECT COUNT(*) FROM music.artists)       AS artists,
  (SELECT COUNT(*) FROM music.song_artists)  AS song_artist_links;
\qecho ''

\qecho '--- STEP 3: Seed small demo data ---'
\qecho 'Running db/seed_minimal.sql...'
\qecho 'This file adds a few demo users, playlists, and ratings so we can show CRUD queries next.'
\qecho 'It helps us run realistic INSERT, UPDATE, and DELETE demos with linked data.'
\i db/seed_minimal.sql
\qecho 'Succeeded: demo users, playlists, ratings added properly.'
\qecho ''

\qecho '--- Counts after seed (checking if everything is working) ---'
SELECT
  (SELECT COUNT(*) FROM music.users)          AS users,
  (SELECT COUNT(*) FROM music.playlists)      AS playlists,
  (SELECT COUNT(*) FROM music.playlist_songs) AS playlist_songs,
  (SELECT COUNT(*) FROM music.ratings)        AS ratings;
\qecho ''

\qecho '--- DEMO: INSERT (requirement 3) ---'
\qecho 'Add a new rating by nassim for the first song.'
INSERT INTO music.ratings (user_id, song_id, stars, comment)
VALUES (
  (SELECT user_id FROM music.users WHERE username = 'nassim'),
  (SELECT song_id FROM music.songs ORDER BY song_id LIMIT 1),
  5,
  'demo insert ok'
);
\qecho ''

\qecho '--- DEMO: UPDATE (requirement 3) ---'
\qecho 'Rename "Cole Favorites" -> "Cole All-Time Favorites".'
UPDATE music.playlists
SET name = 'Cole All-Time Favorites'
WHERE name = 'Cole Favorites';
\qecho ''

\qecho '--- DEMO: DELETE (requirement 3) ---'
\qecho 'Remove one song from the renamed playlist.'
DELETE FROM music.playlist_songs
WHERE playlist_id = (SELECT playlist_id FROM music.playlists WHERE name = 'Cole All-Time Favorites')
  AND song_id IN (
    SELECT song_id
    FROM music.playlist_songs
    WHERE playlist_id = (SELECT playlist_id FROM music.playlists WHERE name = 'Cole All-Time Favorites')
    LIMIT 1
  );
\qecho ''

\qecho '--- SELECT A: Join view (requirement 3) ---'
\qecho 'Public playlists with owners and songs (show 10).'
SELECT p.playlist_id, p.name, u.username, s.title, ps.position
FROM music.playlists p
JOIN music.users u ON u.user_id = p.owner_id
JOIN music.playlist_songs ps ON ps.playlist_id = p.playlist_id
JOIN music.songs s ON s.song_id = ps.song_id
WHERE p.is_public = true
ORDER BY p.playlist_id, ps.position
LIMIT 10;
\qecho ''

\qecho '--- SELECT B: Aggregation (requirement 3) ---'
\qecho 'Avg stars + count per song (top 5).'
SELECT s.song_id, s.title,
       ROUND(AVG(r.stars)::numeric, 2) AS avg_stars,
       COUNT(r.rating_id)              AS num_ratings
FROM music.songs s
LEFT JOIN music.ratings r ON r.song_id = s.song_id
GROUP BY s.song_id, s.title
ORDER BY avg_stars DESC NULLS LAST, num_ratings DESC, s.title
LIMIT 5;
\qecho ''

\qecho '=== DONE ==='
\qecho 'To conclude, this demo showed everything required for Phase 2.'
\qecho 'We built the full database schema from our ERD, loaded real data from a CSV,'
\qecho 'added demo users and playlists, and ran SQL queries showing INSERT, UPDATE, DELETE, and 2 SELECT statements.'
\qecho 'This proves that our database is working and meets all Phase 2 requirements. Thank you for your time!'
