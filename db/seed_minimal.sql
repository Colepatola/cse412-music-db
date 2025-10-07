-- ======================================================================================
-- Description: This file seeds a tiny, readable demo dataset.
-- It adds a few users and playlists, picks the first 3 songs already loaded,
-- puts them into a playlist in order, and adds a few ratings.
-- This helps us demo INSERT/SELECT/UPDATE/DELETE in Phase 2 with real linked rows.
-- ======================================================================================

SET search_path TO music; -- ensure we are in the right schema that we created in ddl.sql

-- here we insert a few users with emails and password hashes (not real hashes) for demo
INSERT INTO users (username, email, password_hash) VALUES
('cole','colepatola@gmail.com','testhash1'), -- this user will own a public playlist
('svar','sajwani@asu.edu','testhash2'),      -- this user will own a private playlist
('mohsin','mzaidi4@asu.edu','testhash3'),    -- this user will just rate a song
('nassim','nzitouni@asu.edu','testhash4')    -- this user will add a rating via INSERT in our phase2_demo.sql script
ON CONFLICT DO NOTHING;

-- now we create two test playlists owned by two different users
INSERT INTO playlists (owner_id, name, is_public) VALUES
((SELECT user_id FROM users WHERE username = 'cole'), 'Cole Favorites', true), -- this one is public
((SELECT user_id FROM users WHERE username = 'svar'), 'Svar Study Mix', false) -- this one is private
ON CONFLICT DO NOTHING; -- in case we run this seed file multiple times

-- now we pick the first 3 songs (by song_id order) from the existing songs table to add to Cole's playlist
WITH picks AS
(
  SELECT song_id, title, row_number() OVER (ORDER BY song_id) AS rn -- rn is position in playlist
  FROM songs -- from the existing songs table
  LIMIT 3    -- pick the first 3 only
)

INSERT INTO playlist_songs (playlist_id, song_id, position) -- add to playlist_songs table
SELECT 
  (SELECT playlist_id FROM playlists WHERE name = 'Cole Favorites'), -- get Cole's playlist_id
  p.song_id, -- song_id from our picks CTE
  p.rn       -- position from our picks CTE
FROM picks p -- use the picks CTE
ON CONFLICT DO NOTHING;

-- below we add a few ratings from different users for the first 3 songs
INSERT INTO ratings (user_id, song_id, stars, comment)      -- cole rates the first song
SELECT (SELECT user_id FROM users WHERE username = 'cole'), -- cole's user_id
       p1.song_id, -- first song_id from songs table
       5,          -- 5 stars
       'banger'    -- comment for the song
FROM (SELECT song_id FROM songs ORDER BY song_id LIMIT 1) AS p1 -- subquery to get first song
ON CONFLICT DO NOTHING;

INSERT INTO ratings (user_id, song_id, stars, comment)      -- svar rates the second song
SELECT (SELECT user_id FROM users WHERE username = 'svar'), -- svar's user_id
       p2.song_id, -- second song_id from songs table
       4,          -- 4 stars
       'solid'     -- comment for the song
FROM (SELECT song_id FROM songs ORDER BY song_id OFFSET 1 LIMIT 1) AS p2 -- subquery to get second song
ON CONFLICT DO NOTHING;

INSERT INTO ratings (user_id, song_id, stars, comment)        -- lastly mohsin rates the third song
SELECT (SELECT user_id FROM users WHERE username = 'mohsin'), -- mohsin's user_id
       p3.song_id, -- third song_id from songs table
       5,          -- 5 stars
       'iconic'    -- comment for the song
FROM (SELECT song_id FROM songs ORDER BY song_id OFFSET 2 LIMIT 1) AS p3
ON CONFLICT DO NOTHING;
