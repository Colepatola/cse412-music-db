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

    playlists.forEach(pl => {
      const card = `
        <article>
          <header>
            <strong>${pl.name}</strong>
            ${pl.is_public ? '<span data-tooltip="Public">🌍</span>' : '🔒'}
          </header>
          <div class="grid">
            <button class="outline secondary" onclick="app.deletePlaylist(${pl.playlist_id})">Delete</button>
            <button onclick="app.renamePlaylist(${pl.playlist_id}, '${pl.name}')">Rename</button>
          </div>
        </article>
      `;
      container.insertAdjacentHTML('beforeend', card);
    });
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
  }
};

document.addEventListener('DOMContentLoaded', app.init);