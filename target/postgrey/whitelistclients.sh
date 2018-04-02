#!/bin/bash

ESPs="google.com amazonses.com hotmail.com facebook.com twitter.com spamhero.com"

VERBOSE='n'

function parsespf(){
    SPF=$(dig TXT $1 +short | grep 'v=spf1' | tr -d '"')
    [ "$VERBOSE" = "y" ] && echo "#### SPF: $SPF"
    
    for p in $SPF; do
        echo $p | grep -q '^v=spf1\|^~all\|^-all\|^?all' && continue
        if echo $p | grep -q '^ip4:'; then
             [ "$VERBOSE" = "y" ] &&  echo "$(echo $p | sed 's/^ip4://g')    #SPF:$1"
             [ "$VERBOSE" = "n" ] &&  echo "$(echo $p | sed 's/^ip4://g')"
        fi
        if echo $p | grep -q '^include:\|redirect='; then
            [ "$VERBOSE" = "y" ] && echo "#### recursing include or redirect: $p"
            parsespf $(echo $p | sed -e 's/^include://g' -e 's/^redirect=//g')
        fi
    done

}


# We parse the spfs and add them as uniq entries
for e in $ESPs; do
    parsespf $e
done | sort -n | uniq
