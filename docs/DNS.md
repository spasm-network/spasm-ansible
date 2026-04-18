### DNS

Configure DNS at your DNS provider's dashboard.

#### Steps:

1. **Type**: Choose `A` for IPv4 or `AAAA` for IPv6
2. **Name**: Enter your domain (e.g., `example.com` or `forum.example.com`)
3. **Value**: Enter your server's IP address
4. **TTL**: Set to `3h` or leave as default

```
# Examples:
# Type:A, Name:degenrocket.space, IPv4:20.21.03.01, TTL:3h
# Type:A, Name:forum.spasm.network, IPv4:20.21.03.01, TTL:3h
```

#### Notes:

- If you cannot set your domain name as "example", try using `@` for the root domain.
- For IPv6 (`AAAA` records), ensure your firewall allows IPv6 traffic:
  ```bash
  # Check UFW IPv6 setting
  grep IPV6 /etc/default/ufw
  # Should show: IPV6=yes
  ```
