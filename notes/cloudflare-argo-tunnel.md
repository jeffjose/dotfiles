# Setup tunnel

https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/#set-up-a-tunnel-locally-cli-setup


```
# Login
$ cloudflared tunnel login

# Create a tunnel
$ cloudflared tunnel create mytunnel

# List
$ cloudflared tunnel list

# Create config
$ cd ~/.cloudflared
$ vim config.yml
```

```
url: http://localhost:8000
tunnel: mytunnel
credentials-file: /home/jeffjose/.cloudflared/tunnel-uuid-abc.json
```

```
# Route traffic
$ cloudflared tunnel route dns mytunnel example.com

# Run tunnel
$ cloudflared tunnel run mytunnel
```
