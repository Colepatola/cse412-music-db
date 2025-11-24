const app = {
  state: {
    currentUser: null,
    currentUserId: null
  },

  init: () => {
    document.getElementById('login-form').addEventListener('submit', app.handleLogin);
    document.getElementById('search-form').addEventListener('submit', app.handleSearch);
    document.getElementById('rate-form').addEventListener('submit', app.handleRateSubmit);
    document.getElementById('create-playlist-form').addEventListener('submit', app.handleCreatePlaylist);
    document.getElementById('add-to-playlist-form').addEventListener('submit', app.handleAddToPlaylist);
  },

  router: (viewName) => {
    // hides other views
    ['view-login', 'view-search', 'view-playlists'].forEach(id => {
      document.getElementById(id).classList.add('hidden');
    });
    document.getElementById(`view-${viewName}`).classList.remove('hidden');
    
    // Refresh playlist data from db
    if (viewName === 'playlists') app.loadPlaylists();
  },

  toggleModal: (modalId) => {
    const modal = document.getElementById(modalId);
    modal.hasAttribute('open') ? modal.removeAttribute('open') : modal.setAttribute('open', true);
  },

  logout: () => {
    app.state.currentUser = null;
    document.getElementById('nav-bar').classList.add('hidden');
    app.router('login');
  },

  handleLogin: async (e) => {
    e.preventDefault();
    const username = document.getElementById('username').value;
    
// Only checks username for now for simplicity
    try {
      const response = await fetch('/api/login', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ username: username })
      });
      const data = await response.json(); 
      
    //   checks if username entered exists in db
      if (data.user_id) {
        app.state.currentUserId = data.user_id;
        app.state.currentUser = data.username;
        document.getElementById('nav-bar').classList.remove('hidden');
        app.router('search');
      } else {
        alert('User not found');
      }
    } catch (err) {
      console.error(err);
      alert("API Connection Error. Ensure backend is running.");
    }
  },

//   checks for songs that match search query
  handleSearch: async (e) => {
    e.preventDefault();
    const query = document.getElementById('search-query').value;
    const tbody = document.getElementById('search-results-body');
    tbody.textContent = '<tr><td colspan="4" aria-busy="true">Searching...</td></tr>';

    try {
      const res = await fetch(`/api/songs?q=${encodeURIComponent(query)}`);
      const songs = await res.json();

      tbody.textContent = '';
      songs.forEach(song => {
        const row = `
          <tr>
            <td>${song.title}</td>
            <td>${song.artist_name || 'Unknown'}</td>
            <td>${song.release_year}</td>
            <td>
              <button class="outline contrast" onclick="app.openRateModal(${song.song_id})">Rate</button>
              <button class="outline" onclick="app.openAddToPlaylistModal(${song.song_id}, '${song.title.replace(/'/g, "\\'")}')">Add to Playlist</button>
            </td>
          </tr>
        `;
        tbody.insertAdjacentHTML('beforeend', row);
      });
      
      if (songs.length === 0) tbody.textContent = '<tr><td colspan="4">No results found.</td></tr>';
    } catch (err) {
      tbody.textContent = '<tr><td colspan="4">Error loading songs.</td></tr>';
    }
  },

  openRateModal: (songId) => {
    document.getElementById('rate-song-id').value = songId;
    document.getElementById('rate-form').reset();
    app.toggleModal('modal-rate');
  },

  handleRateSubmit: async (e) => {
    e.preventDefault();
    const songId = document.getElementById('rate-song-id').value;
    const stars = document.getElementById('stars').value;
    const comment = document.getElementById('comment').value;

    const payload = {
      user_id: app.state.currentUserId,
      song_id: songId,
      stars: parseInt(stars),
      comment: comment
    };

    const res = await fetch('/api/ratings', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(payload)
    });

    if (res.ok) {
      alert('Rating saved successfully');
      app.toggleModal('modal-rate');
    } else {
      alert('Failed to save rating');
    }
  },

  loadPlaylists: async () => {
    const container = document.getElementById('playlists-container');
    container.textContent = '<p aria-busy="true">Loading...</p>';

    const res = await fetch(`/api/playlists?user_id=${app.state.currentUserId}`);
    const playlists = await res.json();

    container.textContent = '';
    if (playlists.length === 0) {
      container.textContent = '<p>No playlists found. Create one!</p>';
      return;
    }

    for (const pl of playlists) {
      // Load songs for this playlist
      const songsRes = await fetch(`/api/playlists/${pl.playlist_id}/songs`);
      const songs = await songsRes.json();
      
      const songsList = songs.length > 0 
        ? `<ul style="list-style: none; padding: 0; margin: 0;">${songs.map(s => `
          <li style="margin-bottom: 1rem; padding-bottom: 0.75rem; border-bottom: 1px solid rgba(255,255,255,0.1); list-style: none;">
            <div><strong>${s.title}</strong> by ${s.artist_name || 'Unknown'} (${s.release_year || 'N/A'})</div>
            <button class="outline secondary" onclick="app.removeSongFromPlaylist(${pl.playlist_id}, ${s.song_id})" style="margin-top: 0.5rem; padding: 0.25rem 0.75rem; font-size: 0.875rem;">Remove</button>
          </li>
        `).join('')}</ul>`
        : '<p><em>No songs in this playlist yet.</em></p>';
      
      const card = `
        <article>
          <header>
            <strong>${pl.name}</strong>
            ${pl.is_public ? '<span data-tooltip="Public">🌍</span>' : '🔒'}
          </header>
          <div>
            <h4>Songs (${songs.length}):</h4>
            ${songsList}
          </div>
          <div class="grid">
            <button class="outline secondary" onclick="app.deletePlaylist(${pl.playlist_id})">Delete</button>
            <button onclick="app.renamePlaylist(${pl.playlist_id}, '${pl.name.replace(/'/g, "\\'")}')">Rename</button>
          </div>
        </article>
      `;
      container.insertAdjacentHTML('beforeend', card);
    }
  },

  handleCreatePlaylist: async (e) => {
    e.preventDefault();
    const name = document.getElementById('playlist-name').value;
    const isPublic = document.getElementById('is-public').checked;

    const payload = {
      owner_id: app.state.currentUserId,
      name: name,
      is_public: isPublic
    };

    const res = await fetch('/api/playlists', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(payload)
    });

    if (res.ok) {
      app.toggleModal('modal-create-playlist');
      app.loadPlaylists();
    }
  },

  deletePlaylist: async (id) => {
    if(!confirm("Are you sure you want to delete this playlist?")) return;
    
    await fetch(`/api/playlists/${id}`, { method: 'DELETE' });
    app.loadPlaylists();
  },
  
  renamePlaylist: async (id, oldName) => {
    const newName = prompt("Enter new name:", oldName);
    if (newName && newName !== oldName) {
      await fetch(`/api/playlists/${id}`, {
        method: 'PUT',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ name: newName })
      });
      app.loadPlaylists();
    }
  },

  openAddToPlaylistModal: async (songId, songTitle) => {
    document.getElementById('add-song-id').value = songId;
    document.getElementById('add-song-title').textContent = songTitle;
    
    // Load user's playlists
    const res = await fetch(`/api/playlists?user_id=${app.state.currentUserId}`);
    const playlists = await res.json();
    
    const select = document.getElementById('playlist-select');
    select.innerHTML = '<option value="">Select a playlist...</option>';
    playlists.forEach(pl => {
      const option = document.createElement('option');
      option.value = pl.playlist_id;
      option.textContent = pl.name;
      select.appendChild(option);
    });
    
    app.toggleModal('modal-add-to-playlist');
  },

  handleAddToPlaylist: async (e) => {
    e.preventDefault();
    const songId = document.getElementById('add-song-id').value;
    const playlistId = document.getElementById('playlist-select').value;
    
    if (!playlistId) {
      alert('Please select a playlist');
      return;
    }
    
    const res = await fetch(`/api/playlists/${playlistId}/songs`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ song_id: parseInt(songId) })
    });
    
    if (res.ok) {
      alert('Song added to playlist successfully');
      app.toggleModal('modal-add-to-playlist');
      app.loadPlaylists();
    } else {
      const data = await res.json();
      alert(data.error || 'Failed to add song to playlist');
    }
  },

  removeSongFromPlaylist: async (playlistId, songId) => {
    if (!confirm("Remove this song from the playlist?")) return;
    
    const res = await fetch(`/api/playlists/${playlistId}/songs/${songId}`, {
      method: 'DELETE'
    });
    
    if (res.ok) {
      app.loadPlaylists();
    } else {
      alert('Failed to remove song');
    }
  }
};

document.addEventListener('DOMContentLoaded', app.init);