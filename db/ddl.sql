-- =================================================================================================
-- Description: This file builds the entire database structure for our music app.
-- It creates all tables or entities from our ERD (users, songs, artists, playlists, ratings, genre) 
-- and links them with appropriate primary keys, foreign keys, constriaints, etc.

--  This satisfies the Phase 2 requirement for "ER to relational (DDL)" by showing our fully
--  normalized schema in SQL DDL form, which was built directly from our ERD.
-- =================================================================================================


-- Here we define the schema for a music database
DROP SCHEMA IF EXISTS music CASCADE; -- for easy re-runs 
CREATE SCHEMA music;                 -- create a new schema called music to hold all our tables
SET search_path TO music;            -- set the search path to the music schema which we just created

-- USERS TABLE
CREATE TABLE users 
(
  user_id BIGSERIAL PRIMARY KEY, -- BIGSERIAL makes an auto-incrementing primary key
  username TEXT NOT NULL UNIQUE, -- unique username, cant be NULL
  email TEXT NOT NULL UNIQUE,    -- unique email
  password_hash TEXT NOT NULL,   -- hashed password
  created_at TIMESTAMPTZ NOT NULL DEFAULT now() -- TIMESTAMPZ means timestamp with timezone
);

-- ARTISTS TABLE
CREATE TABLE artists 
(
  artist_id BIGSERIAL PRIMARY KEY, -- auto-incrementing artist ID, same as above
  artist_name TEXT NOT NULL        -- artist name
);

-- SONGS TABLE
CREATE TABLE songs 
(
  song_id BIGSERIAL PRIMARY KEY, -- auto-incrementing song ID once again
  title TEXT NOT NULL,  -- song title, wont be null
  release_year INT,     -- year of release
  duration_ms INT,      -- duration in milliseconds
  danceability NUMERIC, -- danceability score
  energy NUMERIC,       -- energy score
  tempo NUMERIC,        -- tempo in BPM
  valence NUMERIC       -- valence score (essentially musical positiveness)
);

-- SONGS <--> ARTISTS (many-to-many relationship shown in our erd)
CREATE TABLE song_artists 
(
  song_id BIGINT NOT NULL REFERENCES songs(song_id) ON DELETE CASCADE,       -- fk to songs, BIGINT means same type as referenced pk
  artist_id BIGINT NOT NULL REFERENCES artists(artist_id) ON DELETE CASCADE, -- fk to artists
  PRIMARY KEY (song_id, artist_id) -- composite primary key
);

-- PLAYLISTS TABLE 
CREATE TABLE playlists 
(
  playlist_id BIGSERIAL PRIMARY KEY,                                    -- auto-incrementing playlist ID
  owner_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE, -- fk to users
  name TEXT NOT NULL,                           -- playlist name
  is_public BOOLEAN NOT NULL DEFAULT true,      -- public or private
  created_at TIMESTAMPTZ NOT NULL DEFAULT now() -- created timestamp using TIMESTAMPTZ which includes timezone, same as before
);

-- PLAYLIST <--> SONGS (many-to-many relationship shown in our erd)
CREATE TABLE playlist_songs 
(
  playlist_id BIGINT NOT NULL REFERENCES playlists(playlist_id) ON DELETE CASCADE, -- fk to playlists, once again using BIGINT
  song_id BIGINT NOT NULL REFERENCES songs(song_id) ON DELETE CASCADE,             -- fk to songs
  position INT,                      -- display order inside a playlist
  PRIMARY KEY (playlist_id, song_id) -- each song appears at most once in a playlist 
);

-- RATINGS TABLE
CREATE TABLE ratings 
(
  rating_id BIGSERIAL PRIMARY KEY, -- auto-incrementing rating ID
  user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE, -- fk to users
  song_id BIGINT NOT NULL REFERENCES songs(song_id) ON DELETE CASCADE, -- fk to songs
  stars INT NOT NULL CHECK (stars BETWEEN 1 AND 5), -- rating 1 thru 5
  comment TEXT, -- optional comment
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- created timestamp
  UNIQUE (user_id, song_id) -- one rating per user per song
);

-- GENRES TABLE
CREATE TABLE genres
(
  genre_id BIGSERIAL PRIMARY KEY, -- auto-incrementing genre ID
  genre_name TEXT NOT NULL UNIQUE  -- genre name
);

-- SONG <--> GENRE (many-to-many relationship shown in our erd)
CREATE TABLE song_genres
(
  song_id  BIGINT NOT NULL REFERENCES songs(song_id)   ON DELETE CASCADE, -- fk to songs
  genre_id BIGINT NOT NULL REFERENCES genres(genre_id) ON DELETE CASCADE, -- fk to genres
  PRIMARY KEY (song_id, genre_id) -- each song-genre pair appears once
);

-- The point of the indexes below is to speed up common queries for running our phase2_demo.sql script
-- this works by creating a data structure that makes lookups faster, its a interesting tactic that works
-- because we know what queries we will be running in advance, so we can optimize for them.
CREATE INDEX idx_artists_name ON artists (artist_name); -- this index speeds up artist name searches
CREATE INDEX idx_playlist_owner ON playlists (owner_id); -- this index speeds up lookups of a user's playlists
CREATE INDEX idx_ratings_song ON ratings (song_id); -- this index speeds up lookups of ratings for a song
CREATE INDEX idx_song_features ON songs (danceability, energy, tempo); -- index on song features for feature-based searches
-- Optional full text index on title (speeds up title search)
CREATE INDEX idx_songs_title_tsv ON songs USING gin (to_tsvector('simple', title)); -- full text search index on song titles
CREATE INDEX idx_genres_name ON genres (genre_name); -- speeds up genre name searches
