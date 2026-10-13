// iPhone Safari WebRTC Viewer Client
(() => {
  const statusDot = document.getElementById('status-dot');
  const statusText = document.getElementById('status-text');
  const statsBadge = document.getElementById('stats-badge');
  const connectCard = document.getElementById('connect-card');
  const connectBtn = document.getElementById('connect-btn');
  const connectSpinner = document.getElementById('connect-spinner');
  const btnText = connectBtn.querySelector('.btn-text');
  const errorMessage = document.getElementById('error-message');
  const remoteVideo = document.getElementById('remote-video');
  const controlsBar = document.getElementById('controls-bar');
  const disconnectBtn = document.getElementById('disconnect-btn');
  const fullscreenBtn = document.getElementById('fullscreen-btn');
  const toggleHudBtn = document.getElementById('toggle-hud-btn');
  const statusBar = document.getElementById('status-bar');

  let peerConnection = null;
  let hudVisible = true;
  let pendingCandidates = [];

  function setStatus(text, state = 'idle') {
    statusText.textContent = text;
    statusDot.className = 'pulse-dot ' + (state === 'connected' ? 'connected' : state === 'error' ? 'error' : '');
  }

  function showError(msg) {
    errorMessage.textContent = msg;
    errorMessage.classList.remove('hidden');
    setStatus('Connection Failed', 'error');
    btnText.textContent = 'Retry Connection';
    connectSpinner.classList.add('hidden');
    connectBtn.disabled = false;
  }

  async function startConnection() {
    errorMessage.classList.add('hidden');
    connectBtn.disabled = true;
    connectSpinner.classList.remove('hidden');
    btnText.textContent = 'Signaling Mac...';
    setStatus('Connecting...');

    // 1. Verify Secure Context for iOS Safari
    if (!window.isSecureContext) {
      showError('Insecure context detected! WebRTC in Safari requires HTTPS.');
      return;
    }

    if (!window.RTCPeerConnection) {
      showError('RTCPeerConnection not supported in this browser.');
      return;
    }

    try {
      // 2. Initialize RTCPeerConnection (Local LAN only, zero STUN needed)
      peerConnection = new RTCPeerConnection({
        iceServers: [] // Host candidates only over local subnet
      });

      // Prepare to receive video
      peerConnection.addTransceiver('video', { direction: 'recvonly' });

      // Handle incoming stream tracks
      peerConnection.ontrack = (event) => {
        console.log('[WebRTC] Received remote track:', event.track.kind);
        if (event.streams && event.streams[0]) {
          remoteVideo.srcObject = event.streams[0];
        } else {
          let inboundStream = new MediaStream();
          inboundStream.addTrack(event.track);
          remoteVideo.srcObject = inboundStream;
        }
        remoteVideo.play().catch(e => console.warn('Autoplay error:', e));
      };

      // Connection state listener
      peerConnection.onconnectionstatechange = () => {
        console.log('[WebRTC] Connection state:', peerConnection.connectionState);
        if (peerConnection.connectionState === 'connected') {
          setStatus('Streaming Live', 'connected');
          connectCard.classList.add('hidden');
          controlsBar.classList.remove('hidden');
          statsBadge.classList.remove('hidden');
        } else if (peerConnection.connectionState === 'disconnected' || peerConnection.connectionState === 'failed') {
          handleDisconnect('Connection lost');
        }
      };

      // Handle ICE Candidate generation
      peerConnection.onicecandidate = async (event) => {
        if (event.candidate) {
          console.log('[WebRTC] Discovered local candidate:', event.candidate.candidate);
          // Send candidate to Mac signaling endpoint
          try {
            await fetch('/api/candidate', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(event.candidate)
            });
          } catch (err) {
            console.error('Failed to post ICE candidate:', err);
          }
        }
      };

      // 3. Create browser Offer
      const offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);

      console.log('[Signaling] Sending offer to Mac...');
      const response = await fetch('/api/offer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sdp: offer.sdp,
          type: offer.type
        })
      });

      if (!response.ok) {
        throw new Error(`Server returned HTTP ${response.status}`);
      }

      const answer = await response.json();
      console.log('[Signaling] Received answer from Mac');
      await peerConnection.setRemoteDescription(new RTCSessionDescription(answer));

      // Fetch any server-side ICE candidates
      pollServerCandidates();

    } catch (err) {
      console.error('[Signaling Error]', err);
      showError(err.message || 'Failed to connect to Mac signaling server');
      if (peerConnection) {
        peerConnection.close();
        peerConnection = null;
      }
    }
  }

  async function pollServerCandidates() {
    if (!peerConnection || peerConnection.connectionState === 'closed') return;
    try {
      const res = await fetch('/api/candidates');
      if (res.ok) {
        const candidates = await res.json();
        for (const cand of candidates) {
          try {
            await peerConnection.addIceCandidate(new RTCIceCandidate(cand));
          } catch (e) {
            console.warn('Error adding ice candidate:', e);
          }
        }
      }
    } catch (e) {
      // Ignore polling errors
    }
    if (peerConnection && peerConnection.connectionState !== 'connected' && peerConnection.connectionState !== 'failed') {
      setTimeout(pollServerCandidates, 500);
    }
  }

  function handleDisconnect(reason = 'Disconnected') {
    if (peerConnection) {
      peerConnection.close();
      peerConnection = null;
    }
    if (remoteVideo.srcObject) {
      remoteVideo.srcObject.getTracks().forEach(t => t.stop());
      remoteVideo.srcObject = null;
    }
    setStatus(reason);
    connectCard.classList.remove('hidden');
    controlsBar.classList.add('hidden');
    statsBadge.classList.add('hidden');
    connectBtn.disabled = false;
    connectSpinner.classList.add('hidden');
    btnText.textContent = 'Connect to Mac';
  }

  // Event Listeners
  connectBtn.addEventListener('click', startConnection);
  disconnectBtn.addEventListener('click', () => handleDisconnect('Disconnected by user'));

  fullscreenBtn.addEventListener('click', () => {
    if (remoteVideo.webkitEnterFullscreen) {
      remoteVideo.webkitEnterFullscreen(); // Standard iOS Safari video fullscreen API
    } else if (remoteVideo.requestFullscreen) {
      remoteVideo.requestFullscreen();
    }
  });

  toggleHudBtn.addEventListener('click', () => {
    hudVisible = !hudVisible;
    statusBar.style.opacity = hudVisible ? '1' : '0';
    if (!connectCard.classList.contains('hidden')) {
      controlsBar.style.opacity = hudVisible ? '1' : '0';
    }
  });

  // Tap video to toggle HUD
  remoteVideo.addEventListener('click', () => {
    hudVisible = !hudVisible;
    statusBar.style.opacity = hudVisible ? '1' : '0';
    controlsBar.style.opacity = hudVisible ? '1' : '0';
  });

})();
