ActiveAdmin.register_page "Passkeys" do
  menu priority: 10, label: "Passkeys"

  content title: "Passkeys" do
    div class: "blank_slate_container" do
      span class: "blank_slate" do
        h2 "Register a new passkey"

        div id: "register-passkey", style: "margin: 20px 0;" do
          label "Label: ", for: "passkey-label"
          input id: "passkey-label", type: "text", placeholder: "e.g. MacBook Touch ID", style: "margin-right: 10px; padding: 5px;"
          button "Register Passkey", id: "register-btn", style: "padding: 5px 15px; cursor: pointer;"
          para id: "register-status", style: "margin-top: 10px;"
        end
      end
    end

    div class: "blank_slate_container" do
      span class: "blank_slate" do
        h2 "Registered Passkeys"

        if Passkey.any?
          table do
            thead do
              th "ID"
              th "Label"
              th "Created"
              th "Actions"
            end
            Passkey.order(created_at: :desc).each do |passkey|
              tr do
                td passkey.id
                td passkey.label
                td passkey.created_at.strftime("%Y-%m-%d %H:%M")
                td do
                  a "Delete", href: passkey_path(passkey), "data-method": "delete", "data-confirm": "Are you sure?", rel: "nofollow"
                end
              end
            end
          end
        else
          para "No passkeys registered yet."
        end
      end
    end

    script do
      raw <<~JS
        function bufferToBase64url(buffer) {
          var bytes = new Uint8Array(buffer);
          var str = '';
          for (var i = 0; i < bytes.length; i++) str += String.fromCharCode(bytes[i]);
          return btoa(str).replace(/\\+/g, '-').replace(/\\//g, '_').replace(/=+$/, '');
        }

        function base64urlToBuffer(base64url) {
          var base64 = base64url.replace(/-/g, '+').replace(/_/g, '/');
          var pad = base64.length % 4;
          var padded = pad ? base64 + '='.repeat(4 - pad) : base64;
          var binary = atob(padded);
          var bytes = new Uint8Array(binary.length);
          for (var i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
          return bytes.buffer;
        }

        document.getElementById('register-btn').addEventListener('click', async function() {
          var statusEl = document.getElementById('register-status');
          var label = document.getElementById('passkey-label').value || 'Passkey';
          statusEl.textContent = 'Starting registration...';
          statusEl.style.color = '';
          console.log('[Passkey] Starting registration with label:', label);

          try {
            console.log('[Passkey] Fetching create_options from server...');
            var optionsResp = await fetch('/passkeys/create_options', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' }
            });
            console.log('[Passkey] create_options response status:', optionsResp.status);

            if (!optionsResp.ok) {
              var errText = await optionsResp.text();
              console.error('[Passkey] create_options failed:', optionsResp.status, errText);
              throw new Error('Server returned ' + optionsResp.status + ': ' + errText);
            }

            var options = await optionsResp.json();
            console.log('[Passkey] Received create options:', JSON.stringify(options, null, 2));
            console.log('[Passkey] Challenge length:', options.challenge ? options.challenge.length : 'missing');
            console.log('[Passkey] User ID:', options.user ? options.user.id : 'missing');
            console.log('[Passkey] RP:', options.rp);
            console.log('[Passkey] excludeCredentials count:', options.excludeCredentials ? options.excludeCredentials.length : 0);

            options.challenge = base64urlToBuffer(options.challenge);
            options.user.id = base64urlToBuffer(options.user.id);
            if (options.excludeCredentials) {
              options.excludeCredentials = options.excludeCredentials.map(function(c) {
                return Object.assign({}, c, { id: base64urlToBuffer(c.id.id) });
              });
            }
            console.log('[Passkey] Decoded options, calling navigator.credentials.create()...');

            statusEl.textContent = 'Waiting for browser prompt...';
            var credential = await navigator.credentials.create({ publicKey: options });
            console.log('[Passkey] navigator.credentials.create() returned');
            console.log('[Passkey] Credential ID:', credential.id);
            console.log('[Passkey] Credential type:', credential.type);
            console.log('[Passkey] rawId byte length:', credential.rawId.byteLength);
            console.log('[Passkey] clientDataJSON byte length:', credential.response.clientDataJSON.byteLength);
            console.log('[Passkey] attestationObject byte length:', credential.response.attestationObject.byteLength);

            var payload = {
              label: label,
              credential: {
                id: credential.id,
                rawId: bufferToBase64url(credential.rawId),
                type: credential.type,
                response: {
                  clientDataJSON: bufferToBase64url(credential.response.clientDataJSON),
                  attestationObject: bufferToBase64url(credential.response.attestationObject)
                }
              }
            };
            console.log('[Passkey] Sending credential to /passkeys/create:', JSON.stringify(payload, null, 2));

            statusEl.textContent = 'Verifying with server...';
            var createResp = await fetch('/passkeys/create', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(payload)
            });
            console.log('[Passkey] create response status:', createResp.status);

            var result = await createResp.json();
            console.log('[Passkey] create response body:', JSON.stringify(result));

            if (result.status === 'ok') {
              console.log('[Passkey] Registration successful!');
              statusEl.textContent = 'Passkey registered successfully!';
              statusEl.style.color = 'green';
              setTimeout(function() { window.location.reload(); }, 1000);
            } else {
              console.error('[Passkey] Registration failed:', result.error);
              statusEl.textContent = 'Error: ' + (result.error || 'Registration failed');
              statusEl.style.color = 'red';
            }
          } catch (e) {
            console.error('[Passkey] Registration error:', e);
            console.error('[Passkey] Error name:', e.name);
            console.error('[Passkey] Error message:', e.message);
            if (e.stack) console.error('[Passkey] Stack:', e.stack);
            statusEl.textContent = 'Error: ' + (e.message || 'Registration failed');
            statusEl.style.color = 'red';
          }
        });
        console.log('[Passkey] Registration script loaded');
      JS
    end
  end
end
