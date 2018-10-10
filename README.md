# Auto Rotate SSH Keys

Rotates passphrase encrypted SSH keys on remote host. 

This script will auto-rollback and won't delete your old `authorized_keys` entry unless the new key works. 

## Requirements: 

* It's assumed that the SSH key uses a passphrase, if it doesn't you'll need to modify this script a bit. Be sure your server is locked down properly too if you're using open keys... my two cents. 
* Requires `expect` and `ssh-add` `ssh-keygen` in your bash $PATH
* Script will automatically test the new keys before removing old authorized key from the host. 
* You'll need the old key, the new key, and a text file with the passphrase for both the old and new keys (example below)

## Usage: 
```
ssh_key_autorotate.sh [options...]
```

## Options: 
```
-o  Path to the private key file (required)"
-n  Path to the NEW private key file (required)"
-p  Path to the passphrase file csv (required)"
-h  IP or hostname of target (required)"
-u  Root/admin user for the affected host. Optional. The default value is 'ubuntu'"
```

## Example: 
```
./sh_key_autorotate.sh -p /home/user/mypassfile.txt -n /home/user/mynewkey.pem -o /home/user/oldkey.pem -h myhost.example.com
```

## Example passphrase file csv contents: 
The passphrase file is a single line csv with the old password and new password provided, in that order. No quotes. 

The contents should look like this:
`myoldpass,mynewpass`



---

>  Credit: Idea and core functions inspired by https://github.com/jakebenn however this version is straight ssh (not ec2 specific) and works for passphrase encrypted keys. 
