var client_id;
var ws;

const hostname_uri = window.location.hostname;

const tokenUrl = `https://mpszkudlarek.auth.us-east-1.amazoncognito.com/oauth2/token`;
const clientId = `4atad40os2e7ld1h6dmscm2n3u`;
const redirectUri = `https://${hostname_uri}/app/game.html`;
const logoutUri = `https://${hostname_uri}/app`;
const logoutUrl = `https://mpszkudlarek.auth.us-east-1.amazoncognito.com/logout?client_id=${clientId}&logout_uri=${logoutUri}`;
const urlParams = new URLSearchParams(window.location.search);
const code = urlParams.get('code')


const getToken = async (authorizationCode) => {
    const params = new URLSearchParams();
    params.append('grant_type', 'authorization_code');
    params.append('client_id', clientId);
    params.append('code', authorizationCode);
    params.append('redirect_uri', redirectUri);

    try {
        const response = await fetch(tokenUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: params,
        });

        if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`);
        }

        const tokens = await response.json();
        console.log('Tokens:', tokens);

        localStorage.setItem("access_token", tokens["access_token"]);
        localStorage.setItem("refresh_token", tokens["refresh_token"]);
        localStorage.setItem("id_token", tokens["id_token"]);
        localStorage.setItem("expiretime", tokens["expires_in"]);

        scheduleTokenRefresh();

        return tokens;
    } catch (error) {
        console.error('Error exchanging code for tokens:', error);
        throw error;
    }
};


const fillGamePage = () => {
    if (!localStorage.getItem('access_token')) {
        document.getElementById('gamecontent').innerHTML = `
      You are not logged in 
      <form action="" onsubmit="loginUser(event)">
        <button>Log In</button>
      </form>`;
    } else {
        document.getElementById('gamecontent').innerHTML = `
    <div id="logout">
    <form action="" onsubmit="logoutUser(event)">
        <button>Log Out</button>
    </form>
    </div>
    <div id="findplayer">
        <form id="username" action="" onsubmit="sendMessage(event)">
            <button>Find player.</button>
        </form>
    </div>`;
    }
}


const refreshAccessToken = async () => {
    const refreshToken = localStorage.getItem('refresh_token');

    const params = new URLSearchParams();
    params.append('grant_type', 'refresh_token');
    params.append('client_id', clientId);
    params.append('refresh_token', refreshToken);

    try {
        const response = await fetch(tokenUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: params,
        });

        if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`);
        }

        const tokens = await response.json();
        console.log('Refreshed Tokens:', tokens);

        localStorage.setItem("access_token", tokens["access_token"]);
        localStorage.setItem("id_token", tokens["id_token"]);
        localStorage.setItem("expiretime", tokens["expires_in"]);


        return tokens;
    } catch (error) {
        console.error('Error refreshing token:', error);
        window.location.href = logoutUrl;
        throw error;
    }
};


const scheduleTokenRefresh = () => {
    const accessToken = localStorage.getItem('access_token');
    if (!accessToken) return;

    // Refresh the token 5 minutes before it expires
    const refreshTime = (localStorage.getItem('expiretime') - 300) * 1000;
    console.log(localStorage.getItem('expiretime'));
    // const refreshTime = 3000;
    setTimeout(async () => {
        try {
            await refreshAccessToken();
            // Schedule the next refresh
            scheduleTokenRefresh();
        } catch (error) {
            console.error('Error scheduling token refresh:', error);
            window.location.href = logoutUrl;
        }
    }, refreshTime);
};


getToken(code)
    .then((tokens) => {
        fillGamePage();
    })
    .catch((error) => {
        fillGamePage();
        refreshAccessToken().then((tokens) => {
            scheduleTokenRefresh();
        });
    });


const decodeBase64 = (str) => {
    try {
        return atob(str);
    } catch (error) {
        console.error('Error decoding base64:', error);
        return null;
    }
};


const decodeToken = (token) => {
    const [header, payload, signature] = token.split('.');

    const decodedPayload = decodeBase64(payload);
    if (!decodedPayload) return null;
    try {
        return JSON.parse(decodedPayload);
    } catch (error) {
        console.error('Error parsing JSON:', error);
        return null;
    }
};


const getUsernameFromToken = (idToken) => {
    const decodedToken = decodeToken(idToken);
    return decodedToken ? decodedToken['cognito:username'] : null;
};


const sendMessage = (event) => {
    event.preventDefault();

    if (!localStorage.getItem("id_token")) {
        return;
    }
    const username = getUsernameFromToken(localStorage.getItem("id_token"));
    // Generate a new client ID
    client_id = Date.now();
    // Create a WebSocket connection
    ws = new WebSocket(`wss://${window.location.hostname}:8080/game/ws/${client_id}/${username}`);

    document.getElementById("username").innerHTML = `User: <b>${username}</b>`;

    ws.onopen = function (event) {
        console.log("WebSocket connection established.");
        ws.send(localStorage.getItem('access_token'));
    };

    ws.onmessage = function (event) {
        console.log(event.data);
        const data = JSON.parse(event.data);
        console.log(data);
        if (data.board) {
            updateBoard(data.board);
            document.getElementById("opponent").innerHTML = `User: <b>${data.opponent}</b>`;
            document.getElementById("message").innerText = data.message;
        } else {
            document.getElementById("message").innerText = data.message;
        }
    };

    ws.onerror = function (error) {
        console.error("WebSocket error:", error);
    };
}

const updateBoard = (board) => {
    const table = document.getElementById("board");
    table.innerHTML = "";
    for (let i = 0; i < 3; i++) {
        const row = document.createElement("tr");
        for (let j = 0; j < 3; j++) {
            const cell = document.createElement("td");
            cell.innerText = board[i][j];
            cell.onclick = function () {
                ws.send(`${i} ${j}`);
            };
            row.appendChild(cell);
        }
        table.appendChild(row);
    }
}

const logoutUser = (event) => {
    event.preventDefault();
    localStorage.removeItem("access_token");
    localStorage.removeItem("refresh_token");
    localStorage.removeItem("id_token");
    localStorage.removeItem("expiretime");
    window.location.href = logoutUrl;
}