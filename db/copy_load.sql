-- ==========================================================================================
-- Description: This script loads our Spotify CSV into the database.
-- It first makes a temporary table that matches the CSV, then copies the data into it, 
-- and finally cleans and moves the data into our main tables (songs, artists, song_artists).
-- 
-- This step shows that we can import real data and normalize it into a proper relational 
-- structure, which meets the “fill the database with data” requirement for Phase 2.
-- ==========================================================================================

SET search_path TO music; -- set the default schema to music

-- Step 1) staging table (matches CSV header exactly)
DROP TABLE IF EXISTS stg_spotify; -- drop if it exists from a prior run
CREATE TEMP TABLE stg_spotify     -- temporary table, will be dropped at end of session to keep things clean
(
  artist            text, -- one artist per row in this dataset
  song              text, -- track title
  emotion           text, -- example: happy, sad, angry, relaxed
  variance          text, -- example: low, medium, high
  genre             text, -- example: pop, rock, jazz, classical, soul
  release_date      text, -- YYYY-MM-DD format, but we stage as text to avoid parse issues
  key               text, -- musical key, example: C, D, E, F#, etc.
  tempo             text, -- in BPM, but we stage as text to avoid parse issues
  loudness          text, -- in dB, but we stage as text to avoid parse issues
  explicit          text, -- boolean, but we stage as text to avoid parse issues
  popularity        text, -- integer 0-100, but we stage as text to avoid parse issues
  energy            text, -- maps to energy from dataset
  danceability      text, -- maps to danceability from dataset
  positiveness      text, -- maps to valence from dataset
  speechiness       text, -- this means the presence of spoken words in a track
  liveness          text, -- this essentially means the presence of an audience in the recording
  acousticness      text, -- the likelihood a track is acoustic
  instrumentalness  text  -- the likelihood a track contains no vocals 
);

-- Step 2) COPY from CSV (column order matches the file header)
\copy stg_spotify(artist,song,emotion,variance,genre,release_date,key,tempo,loudness,explicit,popularity,energy,danceability,positiveness,speechiness,liveness,acousticness,instrumentalness) FROM 'light_spotify_dataset.csv' CSV HEADER

-- Step 3) normalize staged text into our target columns
DROP VIEW IF EXISTS v_spotify_clean; -- drop if it exists from a prior run
CREATE TEMP VIEW v_spotify_clean AS  -- temporary view, again, will be dropped at end of session to keep things clean
SELECT
  NULLIF(song,'') AS norm_title,     -- ignore rows without a title
  NULLIF(artist,'') AS raw_artists,  -- keep original artist string for later splitting, ignore rows without an artist
  NULL::int AS norm_duration_ms,     -- not provided in this dataset, so set to NULL
  
  CASE -- here we try to parse the release date into a year
    WHEN release_date ~ '^[0-9]{4}$' THEN release_date::int -- YYYY format
    WHEN release_date ~ '^[0-9]{4}-' THEN split_part(release_date,'-',1)::int -- YYYY-MM-DD format
    ELSE NULL -- if we can't parse it, set to NULL
  END AS norm_year, -- this is now an integer year or NULL if we can't parse it

  NULLIF(danceability,'')::numeric  AS norm_danceability, -- parse to numeric, set to NULL if empty
  NULLIF(energy,'')::numeric AS norm_energy,              -- parse to numeric, set to NULL if empty
  NULLIF(tempo,'')::numeric  AS norm_tempo,               -- parse to numeric, set to NULL if empty
  NULLIF(positiveness,'')::numeric AS norm_valence        -- parse to numeric, set to NULL if empty
FROM stg_spotify; -- the source we use is the staging table we created in Step 1

-- Step 4) insert songs (ignore rows without a title)
INSERT INTO songs (title, release_year, duration_ms, danceability, energy, tempo, valence)               -- we ignore duration_ms since it's not provided in this dataset
SELECT norm_title, norm_year, norm_duration_ms, norm_danceability, norm_energy, norm_tempo, norm_valence -- select normalized columns
FROM v_spotify_clean          -- now the source we use is the cleaned view we created in Step 3
WHERE norm_title IS NOT NULL; -- ignore rows without a title

-- split artist strings once into a temp table we can reuse
DROP TABLE IF EXISTS tmp_artist_items; -- again, we drop if it exists from a prior run
CREATE TEMP TABLE tmp_artist_items AS  -- temporary table, will be dropped at end of session to keep things clean
SELECT s.song_id, 
       trim(item) AS artist_name_clean -- trim whitespace from artist names
FROM v_spotify_clean v                 -- use the cleaned view as source
JOIN songs s ON s.title = v.norm_title -- join to songs on title to get song_id
CROSS JOIN LATERAL regexp_split_to_table(replace(COALESCE(v.raw_artists,''), ';', ','), ',') AS item -- split on commas or semicolons
WHERE trim(item) <> ''; -- ignore empty artist names

-- optional index to speed up joins on big datasets
CREATE INDEX tmp_artist_items_song_idx ON tmp_artist_items(song_id);           -- index on song_id
CREATE INDEX tmp_artist_items_name_idx ON tmp_artist_items(artist_name_clean); -- index on artist_name_clean

-- upsert artists, meaning we insert new artists and ignore duplicates
INSERT INTO artists (artist_name) -- insert distinct artist names
SELECT DISTINCT artist_name_clean -- select distinct cleaned artist names
FROM tmp_artist_items             -- use the temp table we created in Step 5
ON CONFLICT DO NOTHING;           -- ignore duplicates

-- link songs to artists
INSERT INTO song_artists (song_id, artist_id) -- link songs to artists
SELECT t.song_id, a.artist_id  -- select song_id and artist_id
FROM tmp_artist_items t -- use the temp table we created in Step 5
JOIN artists a ON a.artist_name = t.artist_name_clean  -- joining on cleaned artist names to get artist_id
ON CONFLICT DO NOTHING;  -- ignore duplicates
