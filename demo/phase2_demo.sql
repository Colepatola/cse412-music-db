-- demo/phase2_demo.sql
-- One-shot: build schema, load CSV, seed a few rows, run the rubric queries.

\pset pager off

\qecho '=== PHASE 2 DEMO ==='
\qecho 'Below are the requirements that we will demonstrate:'
\qecho '1) Build schema (ER -> Relational).'
\qecho '2) Load CSV with COPY (no GUI yet).'
\qecho '3) Show INSERT, UPDATE, DELETE and SELECTs.'
\qecho ''

-- =========================================================================================
\qecho '--- STEP 1: Build schema (requirement 1) ---'
\qecho 'Running db/ddl.sql...'
\qecho 'This file creates all of our tables from the ERD (users, songs, artists, playlists, ratings, genre).'
\qecho 'It sets up primary keys, foreign keys, and indexes to link everything properly.'
\qecho 'This satisfies the “ER to Relational” requirement by showing we built the full schema in SQL.'
\i db/ddl.sql
\qecho 'Succeeded: schema, keys, FKs, indexes properly loaded.'
\qecho ''
-- =========================================================================================

-- =========================================================================================
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
  (SELECT COUNT(*) FROM music.users)          AS users,     -- should be 4 for all of our group members
  (SELECT COUNT(*) FROM music.playlists)      AS playlists, -- should be 2 for cole and svar
  (SELECT COUNT(*) FROM music.playlist_songs) AS playlist_songs, -- should be 3 for cole's playlist
  (SELECT COUNT(*) FROM music.ratings)        AS ratings;        -- should be 3 for cole, svar, mohsin, nassim will add one more later through the insert requirement
\qecho ''
-- =========================================================================================

-- =========================================================================================
\qecho '--- DEMO: INSERT (requirement 3) ---'
\qecho 'We will first show the ratings table BEFORE the new rating is added.'
SELECT * FROM music.ratings 
ORDER BY rating_id; -- should show 3 ratings currently
\qecho ''

\qecho 'Add a new rating by nassim for the first song.'
INSERT INTO music.ratings (user_id, song_id, stars, comment)
VALUES (
  (SELECT user_id FROM music.users WHERE username = 'nassim'), -- nassim's user_id
  (SELECT song_id FROM music.songs ORDER BY song_id LIMIT 1),  -- first song_id from songs table
  5,                    -- 5 star rating for the song
  'demo insert worked!' -- comment for the song to show our insert worked 
);
\qecho ''

\qecho 'Now showing the ratings table AFTER the new rating is added.'
SELECT * FROM music.ratings 
ORDER BY rating_id; -- should show the new rating at the end
\qecho ''

-- =========================================================================================
\qecho '--- DEMO: UPDATE (requirement 3) ---'
\qecho 'We will show playlists BEFORE the name update.'
SELECT playlist_id, name, owner_id  -- select relevant columns
FROM music.playlists  -- from playlists table
ORDER BY playlist_id; -- should show cole's playlist named "Cole Favorites"
\qecho ''

\qecho 'Rename "Cole Favorites" to "Cole All-Time Favorite Tunes".'
UPDATE music.playlists -- update playlists table
SET name = 'Cole All-Time Favorite Tunes' -- new name
WHERE name = 'Cole Favorites'; -- condition to find cole's original playlist
\qecho '' 

\qecho 'Now showing playlists AFTER the name update.'
SELECT playlist_id, name, owner_id -- select relevant columns
FROM music.playlists  -- from playlists table
ORDER BY playlist_id; -- should show cole's playlist with the new name
\qecho ''
-- =========================================================================================

-- =========================================================================================
\qecho '--- DEMO: DELETE (requirement 3) ---'
\qecho 'We will show the playlist_songs table BEFORE removing a song.'
SELECT * FROM music.playlist_songs -- all songs in cole's playlist
WHERE playlist_id = (SELECT playlist_id FROM music.playlists WHERE name = 'Cole All-Time Favorite Tunes') -- get cole's renamed playlist id
ORDER BY position; -- should show 3 songs in cole's renamed playlist
\qecho ''

\qecho 'Remove one song from the renamed playlist.'
DELETE FROM music.playlist_songs -- delete from cole's renamed playlist
WHERE playlist_id = (SELECT playlist_id FROM music.playlists WHERE name = 'Cole All-Time Favorite Tunes') -- get cole's renamed playlist id
  AND song_id IN 
  (
    SELECT song_id -- get one song_id to delete
    FROM music.playlist_songs -- from cole's renamed playlist
    WHERE playlist_id = (SELECT playlist_id FROM music.playlists WHERE name = 'Cole All-Time Favorite Tunes') -- get cole's renamed playlist id
    LIMIT 1 
  );
\qecho ''

\qecho 'Now showing the playlist_songs table AFTER one song was deleted.'
SELECT * FROM music.playlist_songs -- all songs in cole's renamed playlist
WHERE playlist_id = (SELECT playlist_id FROM music.playlists WHERE name = 'Cole All-Time Favorite Tunes')
ORDER BY position; -- should show 2 songs now in cole's renamed playlist
\qecho ''
-- =========================================================================================

-- =========================================================================================
\qecho '--- SELECT #1: Join view (requirement 3) ---'
\qecho 'Public playlists with owners and songs (show 10).'
SELECT p.playlist_id, p.name, u.username, s.title, ps.position -- select columns to show
FROM music.playlists p                                         -- alias p for playlists
JOIN music.users u ON u.user_id = p.owner_id                   -- join to users to get owner username
JOIN music.playlist_songs ps ON ps.playlist_id = p.playlist_id -- join to playlist_songs to get linked songs
JOIN music.songs s ON s.song_id = ps.song_id                   -- join to songs to get song titles
WHERE p.is_public = true                                       -- only show public playlists
ORDER BY p.playlist_id, ps.position                            -- order by playlist and position
LIMIT 10;                                                      -- limit to 10 rows so that output is not too long
\qecho ''
-- =========================================================================================

\qecho '--- SELECT #2: Aggregation (requirement 3) ---'
\qecho 'Avg stars and count per song (top 3).'
SELECT s.song_id, s.title,                            -- song id and title 
       ROUND(AVG(r.stars)::numeric, 2) AS avg_stars,  -- average stars rounded to 2 decimal places
       COUNT(r.rating_id)              AS num_ratings -- count of ratings
FROM music.songs s                                    -- from songs table
LEFT JOIN music.ratings r ON r.song_id = s.song_id    -- left join to ratings to include songs with no ratings
GROUP BY s.song_id, s.title                           -- group by song id and title
ORDER BY avg_stars DESC NULLS LAST, num_ratings DESC, s.title -- order by avg stars desc, then num ratings desc, then title asc
LIMIT 3;                                                      -- limit to top 3 rows to shorten output
\qecho ''

\qecho '=== DONE ==='
\qecho 'To conclude, this demo showed everything required for Phase 2.'
\qecho 'We built the full database schema from our ERD, loaded real data from a CSV,'
\qecho 'added demo users and playlists, and ran SQL queries showing INSERT, UPDATE, DELETE, and 2 SELECT statements.'
\qecho 'For each change, we displayed the database before and after, so you can visually confirm everything is working.'
\qecho 'This proves that our database is fully functional and meets all Phase 2 requirements. Thank you for your time!'
