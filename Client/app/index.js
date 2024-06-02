const hostname_uri = window.location.hostname;

const loginUser = (event) => {
    event.preventDefault();
    window.location.href = `https://mpszkudlarek.auth.us-east-1.amazoncognito.com/oauth2/authorize?client_id=4atad40os2e7ld1h6dmscm2n3u&response_type=code&scope=email+openid+phone&redirect_uri=https%3A%2F%2F${hostname_uri}%2Fapp%2Fgame.html`

}                           