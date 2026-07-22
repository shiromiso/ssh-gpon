# Nokia G-010S-A GPON Diagnostic Scripts

Scripts to connect to a Nokia G-010S-A GPON module through a UniFi gateway.

## GPON password

By default the GPON SSH password is entered interactively. To avoid the prompt,
place the password in a dotfile:

```
echo 'SUGAR2A041' > ~/.ssh-gpon
chmod 600 ~/.ssh-gpon
```

For more info, refer to this excellent repo: https://github.com/hwti/G-010S-A
