#!/usr/bin/env bash


# Rotates SSH keys on 
# Idea and core functions inspired by https://github.com/jakebenn however this version is straight ssh (not ec2 specific) and works for passphrase encrypted keys. 

# THIS SCRIPT ASSUMES THE SSH KEY HAS A PASSPHRASE!
# Requires 'expect' and 'ssh-add' 'ssh-keygen' in your bash $PATH
# Script will automatically test the new keys before removing old authorized key from the host. 


function PrintHelp() {
    echo "usage: $__base.sh [options...] "
    echo "Example: $__base.sh -p /home/user/mypassfile.txt -n /home/user/mynewkey.pem -o /home/user/oldkey.pem -h myhost.example.com"
    echo "The pass-file is a single line csv with two values oldpass,newpass"
    echo "options:"
    echo " -o --old-key-file  Path to the private key file (required)"
    echo " -n --new-key-file  Path to the NEW private key file (required)"
    echo " -p --pass-file     Path to the passphrase file csv (required)"
    echo " -h --host          IP or hostname of target (required)"
    echo " -u --user          Root/admin user for the EC2 instance. Optional. The default value is 'ubuntu'"
    echo "    --help          Prints this help message"
}

function GetKeys() {
  while IFS=',' read -r f1 f2
    do
      eval oldpass=$f1
      eval newpass=$f2
    done < "$PASS_FILE"
}

function DelSSH() {
  ssh-add -D
}

function AddSSH() {
  expect << EOF
   spawn ssh-add $OLD_KEY_FILE
   expect "Enter passphrase"
   send "$oldpass\r"
   expect eof
EOF
}

function AddNewSSH() {
  expect << EOF
   spawn ssh-add $NEW_KEY
   expect "Enter passphrase"
   send "$newpass\r"
   expect eof
EOF
}

#./ssh-key.sh -p ~/mypassfile.txt -n nmaadmin2017b -s ~/oldkey.key -h 10.10.10.10

function VerifySSHKey() {
    echo "Testing the existing key..."
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -q -i "$NEW_PRIVATE_KEY_FILE" "$TARGET_USER@$TARGET_HOST" hostname && RETURN_CODE=$? || RETURN_CODE=$?
    if [ "$RETURN_CODE" -ne 0 ] ; then
        DelSSH
        echo "Failed SSH Test - No Changes Made. Abort."
        exit 5
    else
        echo "Passed SSH connection test"
    fi
}

### EXECUTE ###
# Set defaults
KEY_FILE=
NEW_KEY_NAME=
TARGET_HOST=
TARGET_USER=ubuntu

# Check args
if [ $# -lt 4 ]; then
    echo "error: too few arguments"
    PrintHelp
    exit 2
fi

# Bring in command line args
while [ "$1" != "" ]; do

    case "$1" in
        -o | --old-key-file) shift
                      OLD_KEY_FILE="$1"
                      ;;
        -n | --new-key-file) shift
                      NEW_KEY="$1"
                      ;;
        -p | --pass-file) shift
                      PASS_FILE="$1"
                      ;;
        -h | --host)  shift
                      TARGET_HOST="$1"
                      ;;
        -u | --user)  shift
                      TARGET_USER="$1"
                      ;;
        --help)       PrintHelp
                      exit 0
                      ;;
        *)            >&2 echo "error: invalid option: '$1'"
                      PrintHelp
                      exit 3
    esac
    # Shift all the parameters down by one
    shift
done

# Parse passfile for new/old passphrases
GetKeys

echo "Rotating using the following --- "
echo "New Key : ${OLD_NEW_KEY}"
echo "Key Name: ${NEW_KEY_NAME}"
echo "Target  : ${TARGET_HOST}"
echo "Old Key : ${KEY_FILE}"
echo "User    : ${TARGET_USER}"

## Add Identity
AddSSH
AddNewSSH

# TEST CURRENT KEY
VerifySSHKey

# GET PUBLIC KEY FROM NEW PRIVATE KEY
NEW_PUB_KEY=$(ssh-keygen -yf ${NEW_KEY} -P ${newpass})

# TEST NEW KEY
echo "Testing new key..."
echo $(cat "$NEW_PUB_KEY") | ssh -o StrictHostKeyChecking=no -q -i "$OLD_KEY_FILE" "$TARGET_USER@$TARGET_HOST" \
  "cat >> ~/.ssh/authorized_keys"
TEST_CASE="Testing New Key"
echo $TEST_CASE | ssh -o StrictHostKeyChecking=no -q -i "$NEW_KEY" "$TARGET_USER@$TARGET_HOST" "cat > ~/.rotation_test_file"
TEST_RESULT=$(ssh -o StrictHostKeyChecking=no -q -i "$OLD_KEY_FILE" "$TARGET_USER@$TARGET_HOST" "cat ~/.rotation_test_file")
if [ "$TEST_RESULT" != "$TEST_CASE" ] ; then
    >&2 echo "Test with the new key failed. ABORTING."
    DelSSH
    exit 4
else
  echo "Passed"
fi

## DELETE KEY FROM TARGET
OLD_PUBLIC_KEY=$(ssh-keygen -yf $OLD_KEY_FILE -P ${oldpass})
OLD_PUBLIC_KEY=$(echo "$OLD_PUBLIC_KEY" | sed 's/\//\\\//g')

# Remove the old key from ~/.ssh/authorized_keys
ssh -o StrictHostKeyChecking=no -q -i "$NEW_KEY" "$TARGET_USER@$TARGET_HOST" \
       "sed -i \"/$OLD_PUBLIC_KEY/d\" ~/.ssh/authorized_keys"

echo ""
echo "Keys are rotated!"
echo ""
echo " ! BE SURE TO DELETE $PASS_FILE ONCE YOU'RE DONE ROTATING ALL HOSTS ! "
echo " Ex: rm -f $PASS_FILE"

DelSSH
